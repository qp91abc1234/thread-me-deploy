#!/bin/bash
# reload-nginx.sh - 更换 Nginx 配置文件并重载

# 自动添加执行权限
chmod +x "$0" 2>/dev/null || true

set -e  # 遇到错误立即退出

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 部署项目目录（脚本所在目录的父目录）
DEPLOY_PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# 配置路径
NGINX_CONF_SOURCE="$SCRIPT_DIR/default.conf"
NGINX_CONF_DIR="/root/volume/nginx/conf.d"
NGINX_CONF_TARGET="$NGINX_CONF_DIR/default.conf"
NGINX_CONTAINER="thread-me-nginx"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

info "========== 更换 Nginx 配置并重载 =========="

# 1. 检查 Docker 是否可用
if ! command -v docker &> /dev/null; then
    error_exit "未找到 Docker，请先安装 Docker"
fi

# 2. 检查源配置文件是否存在
if [ ! -f "$NGINX_CONF_SOURCE" ]; then
    error_exit "Nginx 配置文件不存在: $NGINX_CONF_SOURCE"
fi

success "找到配置文件: $NGINX_CONF_SOURCE"

# 3. 检查 Nginx 容器是否运行
if ! docker ps --format '{{.Names}}' | grep -q "^${NGINX_CONTAINER}$"; then
    error_exit "Nginx 容器未运行: ${NGINX_CONTAINER}\n请先运行 init-infra.sh start 启动服务"
fi

success "Nginx 容器运行正常: ${NGINX_CONTAINER}"

# 4. 检查目标目录是否存在
if [ ! -d "$NGINX_CONF_DIR" ]; then
    warn "目标目录不存在，正在创建: $NGINX_CONF_DIR"
    sudo mkdir -p "$NGINX_CONF_DIR" || error_exit "创建目录失败，请检查权限"
fi

# 5. 备份现有配置（如果存在）
if [ -f "$NGINX_CONF_TARGET" ]; then
    BACKUP_FILE="${NGINX_CONF_TARGET}.backup.$(date +%Y%m%d_%H%M%S)"
    info "备份现有配置..."
    sudo cp "$NGINX_CONF_TARGET" "$BACKUP_FILE" || error_exit "备份配置失败"
    success "配置已备份到: $BACKUP_FILE"
fi

# 6. 复制新配置文件
info "复制新配置文件..."
sudo cp "$NGINX_CONF_SOURCE" "$NGINX_CONF_TARGET" || error_exit "复制配置文件失败"
success "配置文件已复制到: $NGINX_CONF_TARGET"

# 7. 验证配置文件语法
info "验证 Nginx 配置语法..."
if docker exec "${NGINX_CONTAINER}" nginx -t 2>&1 | grep -q "syntax is ok"; then
    success "配置文件语法正确"
else
    error_exit "配置文件语法错误，请检查配置\n错误信息：\n$(docker exec ${NGINX_CONTAINER} nginx -t 2>&1)"
fi

# 8. 重载 Nginx 配置（优雅重载，不中断服务）
info "重载 Nginx 配置..."
if docker exec "${NGINX_CONTAINER}" nginx -s reload 2>/dev/null; then
    success "Nginx 配置已重载（优雅重载，未中断服务）"
else
    error_exit "Nginx 重载失败，请检查配置和容器状态"
fi

echo ""
success "========== 完成 =========="
info "Nginx 配置已更新并重载"
info "配置文件位置: $NGINX_CONF_TARGET"
info "查看日志: docker logs -f ${NGINX_CONTAINER}"
info "测试配置: docker exec ${NGINX_CONTAINER} nginx -t"
