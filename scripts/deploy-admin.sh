#!/bin/bash
# deploy-admin.sh - Docker 构建并部署前端

# 自动添加执行权限
chmod +x "$0" 2>/dev/null || true

set -e  # 遇到错误立即退出

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 部署项目目录（脚本所在目录的父目录）
DEPLOY_PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# admin 目录（Dockerfile 和 .dockerignore 所在位置）
ADMIN_DIR="$DEPLOY_PROJECT_DIR/admin"
# 前端项目目录（与部署项目同级）
FRONTEND_PROJECT_DIR="$(cd "$DEPLOY_PROJECT_DIR/.." && pwd)/thread-me-admin"
# 配置文件目录
CONFIGS_DIR="$DEPLOY_PROJECT_DIR/configs"

# 配置（与 init-infra.sh 中的路径保持一致）
VOLUME_BASE_DIR="/root/volume"
NGINX_HTML_DIR="$VOLUME_BASE_DIR/nginx/html"
DEPLOY_DIR="$NGINX_HTML_DIR"

IMAGE_NAME="thread-me-admin"
CONTAINER_NAME="thread-me-admin-temp"

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

info "========== 开始 Docker 构建部署 =========="

# 1. 检查 Docker 是否可用
if ! command -v docker &> /dev/null; then
    error_exit "未找到 Docker，请先安装 Docker"
fi

# 2. 检测前端项目是否存在
info "检测前端项目..."
if [ ! -d "$FRONTEND_PROJECT_DIR" ]; then
    error_exit "前端项目不存在: $FRONTEND_PROJECT_DIR\n请确保 thread-me-admin 项目与 thread-me-deploy 项目同级"
fi

if [ ! -f "$FRONTEND_PROJECT_DIR/package.json" ]; then
    error_exit "前端项目目录无效，未找到 package.json: $FRONTEND_PROJECT_DIR"
fi

success "前端项目已找到: $FRONTEND_PROJECT_DIR"

# 3. 拷贝 .env.production.local、Dockerfile 和 .dockerignore 到前端项目目录
info "拷贝构建文件到前端项目..."

if [ ! -f "$CONFIGS_DIR/admin/.env.production.local" ]; then
    error_exit ".env.production.local 不存在: $CONFIGS_DIR/admin/.env.production.local"     
fi

if [ ! -f "$ADMIN_DIR/Dockerfile" ]; then
    error_exit "Dockerfile 不存在: $ADMIN_DIR/Dockerfile"
fi

if [ ! -f "$ADMIN_DIR/.dockerignore" ]; then
    error_exit ".dockerignore 不存在: $ADMIN_DIR/.dockerignore"
fi

cp "$CONFIGS_DIR/admin/.env.production.local" "$FRONTEND_PROJECT_DIR/.env.production.local"
cp "$ADMIN_DIR/Dockerfile" "$FRONTEND_PROJECT_DIR/Dockerfile"
cp "$ADMIN_DIR/.dockerignore" "$FRONTEND_PROJECT_DIR/.dockerignore"
success "构建文件已拷贝到前端项目目录"

# 4. 删除已存在的临时容器（如果存在）
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    info "删除已存在的临时容器: ${CONTAINER_NAME}"
    docker rm -f "${CONTAINER_NAME}" > /dev/null 2>&1 || true
fi

# 5. 构建 Docker 镜像（在前端项目目录）
info "构建 Docker 镜像: ${IMAGE_NAME}"
cd "$FRONTEND_PROJECT_DIR"
docker build -t "${IMAGE_NAME}" .

# 6. 创建临时容器（用于提取构建产物）
info "创建临时容器: ${CONTAINER_NAME}"
docker create --name "${CONTAINER_NAME}" "${IMAGE_NAME}"

# 7. 提取构建产物到本地
info "提取构建产物..."
rm -rf "$FRONTEND_PROJECT_DIR/dist"
docker cp "${CONTAINER_NAME}:/dist" "$FRONTEND_PROJECT_DIR/dist"

# 8. 删除临时容器
info "删除临时容器..."
docker rm "${CONTAINER_NAME}"

# 9. 检查构建产物
if [ ! -d "$FRONTEND_PROJECT_DIR/dist" ] || [ -z "$(ls -A "$FRONTEND_PROJECT_DIR/dist")" ]; then
    error_exit "构建失败，未找到构建产物"
fi

success "构建产物已生成"

# 10. 检查部署目录（与 init-infra.sh 中的路径一致）
info "检查部署目录..."
if [ ! -d "$NGINX_HTML_DIR" ]; then
    error_exit "部署目录的父目录不存在: $NGINX_HTML_DIR\n请先运行 init-infra.sh 初始化基础设施"
fi

# 11. 拷贝产物到部署目录
info "拷贝构建产物到部署目录..."
mkdir -p "${DEPLOY_DIR}"
cp -r "$FRONTEND_PROJECT_DIR/dist"/* "${DEPLOY_DIR}/"

# 12. 清理前端项目目录中的临时文件
info "清理临时文件..."
rm -f "$FRONTEND_PROJECT_DIR/Dockerfile"
rm -f "$FRONTEND_PROJECT_DIR/.dockerignore"
rm -rf "$FRONTEND_PROJECT_DIR/dist"

echo ""
success "========== 部署完成 =========="
info "构建产物已复制到: ${DEPLOY_DIR}"
