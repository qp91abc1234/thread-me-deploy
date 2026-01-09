#!/bin/bash
# infra.sh - 基础设施服务管理脚本
# 功能：初始化并管理 Redis、MySQL、Nginx 等公共容器

# 自动添加执行权限
chmod +x "$0" 2>/dev/null || true

set -e  # 遇到错误立即退出

# 获取脚本所在目录（作为独立脚本使用）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# docker-compose.yml 文件路径（放在脚本所在目录）
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"

# 数据卷目录配置（使用绝对路径）
VOLUME_BASE_DIR="/root/volume"
MYSQL_DATA_DIR="$VOLUME_BASE_DIR/mysql/data"
MYSQL_CONF_DIR="$VOLUME_BASE_DIR/mysql/conf"
REDIS_DATA_DIR="$VOLUME_BASE_DIR/redis/data"
NGINX_HTML_DIR="$VOLUME_BASE_DIR/nginx/html"
NGINX_LOGS_DIR="$VOLUME_BASE_DIR/nginx/logs"
NGINX_CONF_DIR="$VOLUME_BASE_DIR/nginx/conf.d"
NGINX_DEFAULT_CONF="$NGINX_CONF_DIR/default.conf"


# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 错误输出函数
error_exit() {
    echo -e "${RED}❌ 错误：$1${NC}" >&2
    exit 1
}

# 信息输出函数
info() {
    echo -e "${GREEN}ℹ️  $1${NC}"
}

# 警告输出函数
warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# 成功输出函数
success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Docker Compose 命令封装（兼容 V1 和 V2）
docker_compose() {
    if docker compose version &> /dev/null 2>&1; then
        docker compose "$@"
    elif command -v docker-compose &> /dev/null; then
        docker-compose "$@"
    else
        error_exit "未找到 docker-compose，请先运行初始化：$0 init"
    fi
}

# 检查 root 权限
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error_exit "此脚本需要 root 权限运行，请使用 sudo 或 root 用户执行"
    fi
}

# 检查 Docker 是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        error_exit "未找到 Docker，请先运行 init-env.sh 安装 Docker"
    fi
    
    if ! systemctl is-active --quiet docker; then
        warn "Docker 服务未运行，正在启动..."
        systemctl start docker || error_exit "启动 Docker 服务失败"
    fi
}

# 检查 docker-compose 是否安装
check_docker_compose() {
    if docker compose version &> /dev/null 2>&1; then
        return 0
    elif command -v docker-compose &> /dev/null; then
        return 0
    else
        error_exit "未找到 docker-compose，请先运行 init-env.sh 安装 docker-compose"
    fi
}

# 创建目录结构
create_directories() {
    info "创建目录结构..."
    
    # 创建数据目录
    mkdir -p "$MYSQL_DATA_DIR"
    mkdir -p "$MYSQL_CONF_DIR"
    mkdir -p "$REDIS_DATA_DIR"
    mkdir -p "$NGINX_HTML_DIR"
    mkdir -p "$NGINX_LOGS_DIR"
    mkdir -p "$NGINX_CONF_DIR"
    
    # 设置权限
    chmod -R 755 "$VOLUME_BASE_DIR"
    
    success "目录结构创建完成"
}

# 验证 MySQL 密码是否符合要求（MySQL 8.0 MEDIUM 策略）
validate_mysql_password() {
    local password=$1
    
    # 检查长度（至少8个字符）
    if [ ${#password} -lt 8 ]; then
        echo "密码长度至少需要 8 个字符"
        return 1
    fi
    
    # 检查是否包含数字
    if ! echo "$password" | grep -q '[0-9]'; then
        echo "密码必须包含至少 1 个数字"
        return 1
    fi
    
    # 检查是否包含小写字母
    if ! echo "$password" | grep -q '[a-z]'; then
        echo "密码必须包含至少 1 个小写字母"
        return 1
    fi
    
    # 检查是否包含大写字母
    if ! echo "$password" | grep -q '[A-Z]'; then
        echo "密码必须包含至少 1 个大写字母"
        return 1
    fi
    
    # 检查是否包含特殊字符
    if ! echo "$password" | grep -q '[^a-zA-Z0-9]'; then
        echo "密码必须包含至少 1 个特殊字符"
        return 1
    fi
    
    return 0
}

# 验证 Redis 密码
validate_redis_password() {
    local password=$1
    
    # 检查长度（建议至少8个字符）
    if [ ${#password} -lt 8 ]; then
        echo "Redis 密码建议至少 8 个字符"
        return 1
    fi
    
    return 0
}

# 从字符串中随机选取一个字符
get_random_char() {
    local chars=$1
    local len=${#chars}
    # 生成 0 到 len-1 之间的随机数
    local rand_hex=$(openssl rand -hex 2)
    local index=$((0x${rand_hex} % len))
    echo "${chars:$index:1}"
}

# 生成符合 MySQL 要求的随机密码
generate_mysql_password() {
    local password=""
    local lower="abcdefghijklmnopqrstuvwxyz"
    local upper="ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    local digits="0123456789"
    local special="!@#\$%^&*()_+-=[]{}|;:,.<>?"
    local all_chars="$lower$upper$digits$special"
    
    # 确保至少包含每种类型的字符
    password+=$(get_random_char "$lower")
    password+=$(get_random_char "$lower")
    password+=$(get_random_char "$upper")
    password+=$(get_random_char "$upper")
    password+=$(get_random_char "$digits")
    password+=$(get_random_char "$digits")
    password+=$(get_random_char "$special")
    password+=$(get_random_char "$special")
    
    # 添加随机字符到至少16位
    while [ ${#password} -lt 16 ]; do
        password+=$(get_random_char "$all_chars")
    done
    
    # 将密码转换为数组，然后随机打乱
    local password_array=()
    local i=0
    while [ $i -lt ${#password} ]; do
        password_array+=("${password:$i:1}")
        i=$((i+1))
    done
    
    # 使用 Fisher-Yates 洗牌算法打乱
    local n=${#password_array[@]}
    local j
    local rand_hex
    for ((i=$n-1; i>0; i--)); do
        rand_hex=$(openssl rand -hex 2)
        j=$((0x${rand_hex} % (i+1)))
        local temp="${password_array[$i]}"
        password_array[$i]="${password_array[$j]}"
        password_array[$j]="$temp"
    done
    
    # 重新组合密码
    password=""
    for char in "${password_array[@]}"; do
        password+="$char"
    done
    
    echo "$password"
}

# 生成 Redis 随机密码
generate_redis_password() {
    openssl rand -base64 16 | tr -d "=+/" | cut -c1-16
}

# 生成 Nginx 默认配置文件
generate_nginx_conf() {
    if [ -f "$NGINX_DEFAULT_CONF" ]; then
        warn "Nginx 配置文件已存在: $NGINX_DEFAULT_CONF"
        read -p "是否覆盖现有配置？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "跳过 Nginx 配置文件生成"
            return 0
        fi
    fi
    
    info "生成 Nginx 默认配置文件..."
    
    cat > "$NGINX_DEFAULT_CONF" << 'EOF'
# Nginx 默认配置文件
# 此文件会被挂载到容器内的 /etc/nginx/conf.d/

server {
    listen 80;
    server_name localhost;

    root /usr/share/nginx/html;
    index index.html index.htm;

    # 日志配置
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    # 安全头
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # 默认 location
    location / {
        try_files $uri $uri/ =404;
    }

    # 健康检查端点
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # 禁止访问隐藏文件
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
}
EOF
    
    success "Nginx 配置文件已生成: $NGINX_DEFAULT_CONF"
}

# 生成 docker-compose.yml
generate_docker_compose() {
    if [ -f "$COMPOSE_FILE" ]; then
        warn "docker-compose.yml 已存在: $COMPOSE_FILE"
        read -p "是否覆盖现有配置？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "跳过 docker-compose.yml 生成"
            return 0
        fi
    fi
    
    info "生成 docker-compose.yml 配置文件..."
    
    # 提示用户输入 MySQL root 密码
    echo ""
    info "MySQL 密码要求（MySQL 8.0 MEDIUM 策略）："
    echo "  - 至少 8 个字符"
    echo "  - 包含至少 1 个数字"
    echo "  - 包含至少 1 个小写字母"
    echo "  - 包含至少 1 个大写字母"
    echo "  - 包含至少 1 个特殊字符"
    echo ""
    
    MYSQL_ROOT_PASSWORD=""
    while true; do
        read -sp "请输入 MySQL root 密码（留空将自动生成随机密码）: " MYSQL_ROOT_PASSWORD_INPUT
        echo ""
        
        if [ -z "$MYSQL_ROOT_PASSWORD_INPUT" ]; then
            MYSQL_ROOT_PASSWORD=$(generate_mysql_password)
            info "已自动生成 MySQL root 密码: $MYSQL_ROOT_PASSWORD"
            break
        else
            local validation_error
            validation_error=$(validate_mysql_password "$MYSQL_ROOT_PASSWORD_INPUT" 2>&1)
            if [ $? -eq 0 ]; then
                MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD_INPUT"
                break
            else
                warn "密码不符合要求: $validation_error"
                read -p "是否重新输入？(Y/n): " -n 1 -r
                echo ""
                if [[ $REPLY =~ ^[Nn]$ ]]; then
                    error_exit "用户取消密码输入"
                fi
            fi
        fi
    done
    
    # 提示用户输入 Redis 密码
    echo ""
    info "Redis 密码要求："
    echo "  - 建议至少 8 个字符"
    echo ""
    
    REDIS_PASSWORD=""
    while true; do
        read -sp "请输入 Redis 密码（留空将自动生成随机密码）: " REDIS_PASSWORD_INPUT
        echo ""
        
        if [ -z "$REDIS_PASSWORD_INPUT" ]; then
            REDIS_PASSWORD=$(generate_redis_password)
            info "已自动生成 Redis 密码: $REDIS_PASSWORD"
            break
        else
            local validation_error
            validation_error=$(validate_redis_password "$REDIS_PASSWORD_INPUT" 2>&1)
            if [ $? -eq 0 ]; then
                REDIS_PASSWORD="$REDIS_PASSWORD_INPUT"
                break
            else
                warn "密码不符合要求: $validation_error"
                read -p "是否重新输入？(Y/n): " -n 1 -r
                echo ""
                if [[ $REPLY =~ ^[Nn]$ ]]; then
                    error_exit "用户取消密码输入"
                fi
            fi
        fi
    done
    
    # 转义密码中的特殊字符，用于在 YAML 中使用（转义单引号和反斜杠）
    MYSQL_ROOT_PASSWORD_ESCAPED=$(echo "$MYSQL_ROOT_PASSWORD" | sed "s/'/''/g" | sed 's/\\/\\\\/g')
    REDIS_PASSWORD_ESCAPED=$(echo "$REDIS_PASSWORD" | sed "s/'/''/g" | sed 's/\\/\\\\/g')
    
    cat > "$COMPOSE_FILE" << EOF
version: '3.8'

services:
  mysql:
    image: mysql:8.0
    container_name: thread-me-mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: '${MYSQL_ROOT_PASSWORD_ESCAPED}'
      TZ: Asia/Shanghai
    ports:
      - "3306:3306"
    volumes:
      - ${MYSQL_DATA_DIR}:/var/lib/mysql
      - ${MYSQL_CONF_DIR}:/etc/mysql/conf.d
    command: 
      - --character-set-server=utf8mb4
      - --collation-server=utf8mb4_unicode_ci
      - --default-authentication-plugin=mysql_native_password
    networks:
      - thread-me-network
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${MYSQL_ROOT_PASSWORD_ESCAPED}"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: thread-me-redis
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD_ESCAPED} --appendonly yes
    ports:
      - "6379:6379"
    volumes:
      - ${REDIS_DATA_DIR}:/data
    networks:
      - thread-me-network
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD_ESCAPED}", "ping"]
      interval: 10s
      timeout: 3s
      retries: 5

  nginx:
    image: nginx:alpine
    container_name: thread-me-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ${NGINX_HTML_DIR}:/usr/share/nginx/html
      - ${NGINX_LOGS_DIR}:/var/log/nginx
      - ${NGINX_CONF_DIR}:/etc/nginx/conf.d:ro
    networks:
      - thread-me-network
    depends_on:
      - mysql
      - redis
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost/"]
      interval: 10s
      timeout: 3s
      retries: 3

networks:
  thread-me-network:
    name: thread-me-network
    driver: bridge
EOF
    
    success "docker-compose.yml 已生成: $COMPOSE_FILE"
    warn "请妥善保管密码信息！MySQL: $MYSQL_ROOT_PASSWORD, Redis: $REDIS_PASSWORD"
}

# 检查端口占用
check_ports() {
    info "检查端口占用情况..."
    
    PORTS=(3306 6379 80 443)
    OCCUPIED=()
    
    for port in "${PORTS[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
            OCCUPIED+=($port)
        fi
    done
    
    if [ ${#OCCUPIED[@]} -gt 0 ]; then
        warn "以下端口已被占用: ${OCCUPIED[*]}"
        read -p "是否继续？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error_exit "用户取消操作"
        fi
    else
        success "端口检查通过"
    fi
}

# 初始化
init() {
    info "========== 初始化公共容器服务 =========="
    
    check_root
    check_docker
    check_docker_compose
    create_directories
    generate_nginx_conf
    generate_docker_compose
    check_ports
    
    echo ""
    success "初始化完成！"
    info "使用以下命令管理服务："
    echo "  启动服务:   $0 start"
    echo "  停止服务:   $0 stop"
    echo "  重启服务:   $0 restart"
    echo "  查看状态:   $0 status"
    echo "  查看日志:   $0 logs [service]"
    echo ""
    info "配置文件位置:"
    echo "  docker-compose.yml: $COMPOSE_FILE"
    echo "  Nginx 配置: $NGINX_DEFAULT_CONF"
}

# 启动服务
start() {
    if [ ! -f "$COMPOSE_FILE" ]; then
        error_exit "配置文件不存在，请先运行: $0 init"
    fi
    
    info "启动公共容器服务..."
    cd "$SCRIPT_DIR"
    docker_compose -f "$COMPOSE_FILE" up -d
    
    echo ""
    success "服务启动完成！"
    info "查看服务状态: $0 status"
}

# 停止服务
stop() {
    if [ ! -f "$COMPOSE_FILE" ]; then
        error_exit "配置文件不存在"
    fi
    
    info "停止公共容器服务..."
    cd "$SCRIPT_DIR"
    docker_compose -f "$COMPOSE_FILE" down
    
    success "服务已停止"
}

# 重启服务
restart() {
    if [ ! -f "$COMPOSE_FILE" ]; then
        error_exit "配置文件不存在，请先运行: $0 init"
    fi
    
    info "重启公共容器服务..."
    cd "$SCRIPT_DIR"
    docker_compose -f "$COMPOSE_FILE" restart
    
    success "服务已重启"
}

# 查看状态
status() {
    if [ ! -f "$COMPOSE_FILE" ]; then
        error_exit "配置文件不存在，请先运行: $0 init"
    fi
    
    cd "$SCRIPT_DIR"
    echo ""
    info "========== 服务状态 =========="
    docker_compose -f "$COMPOSE_FILE" ps
    echo ""
    
    # 显示连接信息
    echo ""
    info "========== 连接信息 =========="
    echo "MySQL:"
    echo "  主机: localhost:3306"
    echo "  用户: root"
    echo "  密码: 请查看 docker-compose.yml 文件"
    echo ""
    echo "Redis:"
    echo "  主机: localhost:6379"
    echo "  密码: 请查看 docker-compose.yml 文件"
    echo ""
    echo "Nginx:"
    echo "  HTTP: http://localhost"
    echo "  HTTPS: https://localhost"
    echo ""
    warn "完整配置信息请查看: $COMPOSE_FILE"
}

# 查看日志
logs() {
    if [ ! -f "$COMPOSE_FILE" ]; then
        error_exit "配置文件不存在，请先运行: $0 init"
    fi
    
    cd "$SCRIPT_DIR"
    if [ -n "$1" ]; then
        docker_compose -f "$COMPOSE_FILE" logs -f "$1"
    else
        docker_compose -f "$COMPOSE_FILE" logs -f
    fi
}


# 显示帮助信息
show_help() {
    cat << EOF
${BLUE}基础设施服务管理脚本${NC}

用法: $0 <command> [options]

命令:
  init             初始化服务（创建配置文件）
  start            启动所有服务
  stop             停止所有服务
  restart          重启所有服务
  status           查看服务状态
  logs [service]   查看服务日志（可指定服务名：mysql/redis/nginx）
  help             显示此帮助信息

示例:
  $0 init                    # 首次运行，初始化配置
  $0 start                   # 启动所有服务
  $0 status                  # 查看服务状态
  configs/reload-nginx.sh    # 重载 Nginx 配置（修改 configs/default.conf 后使用）
  $0 logs mysql              # 查看 MySQL 日志
  $0 logs                    # 查看所有服务日志

配置文件位置:
  docker-compose.yml: $COMPOSE_FILE
  Nginx 配置:         $NGINX_DEFAULT_CONF

EOF
}

# 主函数
main() {
    case "${1:-help}" in
        init)
            init
            ;;
        start)
            check_docker
            check_docker_compose
            start
            ;;
        stop)
            check_docker
            check_docker_compose
            stop
            ;;
        restart)
            check_docker
            check_docker_compose
            restart
            ;;
        status)
            check_docker
            check_docker_compose
            status
            ;;
        logs)
            check_docker
            check_docker_compose
            logs "$2"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            error_exit "未知命令: $1\n使用 '$0 help' 查看帮助信息"
            ;;
    esac
}

# 执行主函数
main "$@"
