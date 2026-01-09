#!/bin/bash
# infra.sh - 基础设施服务管理脚本
# 功能：初始化并管理 Redis、MySQL、Nginx 等公共容器

# 自动添加执行权限
chmod +x "$0" 2>/dev/null || true

set -e  # 遇到错误立即退出

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_DIR="$PROJECT_ROOT/configs"
COMPOSE_FILE="$COMPOSE_DIR/docker-compose.yml"
ENV_FILE="$COMPOSE_DIR/.env"


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
    # 创建 Nginx 配置目录（用于挂载到容器）
    mkdir -p "$COMPOSE_DIR/nginx/conf.d"
    
    # 创建数据目录
    mkdir -p /root/volume/mysql/data
    mkdir -p /root/volume/mysql/conf
    mkdir -p /root/volume/redis/data
    mkdir -p /root/volume/nginx/html
    mkdir -p /root/volume/nginx/logs
    
    # 设置权限
    chmod -R 755 /root/volume
    
    success "目录结构创建完成"
}

# 生成环境变量文件
generate_env_file() {
    if [ -f "$ENV_FILE" ]; then
        warn "环境变量文件已存在: $ENV_FILE"
        read -p "是否覆盖现有配置？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "跳过环境变量文件生成"
            return 0
        fi
    fi
    
    info "生成环境变量配置文件..."
    
    # 生成随机密码
    MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)}"
    REDIS_PASSWORD="${REDIS_PASSWORD:-$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)}"
    
    cat > "$ENV_FILE" << EOF
# MySQL 配置
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}

# Redis 配置
REDIS_PASSWORD=${REDIS_PASSWORD}

# 网络配置
NETWORK_NAME=thread-me-network

# 数据卷路径
MYSQL_DATA_DIR=/root/volume/mysql/data
MYSQL_CONF_DIR=/root/volume/mysql/conf
REDIS_DATA_DIR=/root/volume/redis/data
NGINX_HTML_DIR=/root/volume/nginx/html
NGINX_LOGS_DIR=/root/volume/nginx/logs
EOF
    
    chmod 600 "$ENV_FILE"
    success "环境变量文件已生成: $ENV_FILE"
    warn "请妥善保管密码信息！"
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
    
    # 读取环境变量
    if [ -f "$ENV_FILE" ]; then
        source "$ENV_FILE"
    else
        error_exit "环境变量文件不存在，请先运行: $0 init"
    fi
    
    cat > "$COMPOSE_FILE" << 'EOF'
version: '3.8'

services:
  mysql:
    image: mysql:8.0
    container_name: thread-me-mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
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
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${MYSQL_ROOT_PASSWORD}"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: thread-me-redis
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD} --appendonly yes
    ports:
      - "6379:6379"
    volumes:
      - ${REDIS_DATA_DIR}:/data
    networks:
      - thread-me-network
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD}", "ping"]
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
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
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
    name: ${NETWORK_NAME}
    driver: bridge

EOF
    
    success "docker-compose.yml 已生成: $COMPOSE_FILE"
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
    generate_env_file
    generate_docker_compose
    check_ports
    
    echo ""
    success "初始化完成！"
    info "使用以下命令管理服务："
    echo "  启动服务:   $0 start"
    echo "  停止服务:   $0 stop"
    echo "  查看状态:   $0 status"
    echo "  查看日志:   $0 logs [service]"
    echo ""
    warn "环境变量文件: $ENV_FILE"
    warn "请妥善保管密码信息！"
}

# 启动服务
start() {
    if [ ! -f "$COMPOSE_FILE" ]; then
        error_exit "配置文件不存在，请先运行: $0 init"
    fi
    
    info "启动公共容器服务..."
    cd "$COMPOSE_DIR"
    docker_compose up -d
    
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
    cd "$COMPOSE_DIR"
    docker_compose down
    
    success "服务已停止"
}

# 重启服务
restart() {
    if [ ! -f "$COMPOSE_FILE" ]; then
        error_exit "配置文件不存在，请先运行: $0 init"
    fi
    
    info "重启公共容器服务..."
    cd "$COMPOSE_DIR"
    docker_compose restart
    
    success "服务已重启"
}

# 查看状态
status() {
    if [ ! -f "$COMPOSE_FILE" ]; then
        error_exit "配置文件不存在，请先运行: $0 init"
    fi
    
    cd "$COMPOSE_DIR"
    echo ""
    info "========== 服务状态 =========="
    docker_compose ps
    echo ""
    
    # 显示连接信息
    if [ -f "$ENV_FILE" ]; then
        source "$ENV_FILE"
        echo ""
        info "========== 连接信息 =========="
        echo "MySQL:"
        echo "  主机: localhost:3306"
        echo "  用户: root"
        echo ""
        echo "Redis:"
        echo "  主机: localhost:6379"
        echo "  密码: ${REDIS_PASSWORD}"
        echo ""
        echo "Nginx:"
        echo "  HTTP: http://localhost"
        echo "  HTTPS: https://localhost"
        echo ""
        warn "完整配置信息请查看: $ENV_FILE"
    fi
}

# 查看日志
logs() {
    if [ ! -f "$COMPOSE_FILE" ]; then
        error_exit "配置文件不存在，请先运行: $0 init"
    fi
    
    cd "$COMPOSE_DIR"
    if [ -n "$1" ]; then
        docker_compose logs -f "$1"
    else
        docker_compose logs -f
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
  $0 logs mysql              # 查看 MySQL 日志
  $0 logs                    # 查看所有服务日志

配置文件位置:
  docker-compose.yml: $COMPOSE_FILE
  环境变量文件:        $ENV_FILE

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
