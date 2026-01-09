#!/bin/bash
# deploy.sh - Docker 构建并部署后端 API

# 自动添加执行权限
chmod +x "$0" 2>/dev/null || true

set -e  # 遇到错误立即退出

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 部署项目目录（脚本所在目录的父目录）
DEPLOY_PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# 后端项目目录（与部署项目同级）
BACKEND_PROJECT_DIR="$(cd "$DEPLOY_PROJECT_DIR/.." && pwd)/thread-me-api"
# 配置文件目录
CONFIGS_DIR="$DEPLOY_PROJECT_DIR/configs"

# 配置
IMAGE_NAME="thread-me-api"
CONTAINER_NAME="thread-me-api"
NETWORK_NAME="thread-me-network"

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

# 2. 检测后端项目是否存在
info "检测后端项目..."
if [ ! -d "$BACKEND_PROJECT_DIR" ]; then
    error_exit "后端项目不存在: $BACKEND_PROJECT_DIR\n请确保 thread-me-api 项目与 thread-me-deploy 项目同级"
fi

if [ ! -f "$BACKEND_PROJECT_DIR/package.json" ]; then
    error_exit "后端项目目录无效，未找到 package.json: $BACKEND_PROJECT_DIR"
fi

if [ ! -f "$BACKEND_PROJECT_DIR/prisma/schema.prisma" ]; then
    error_exit "后端项目目录无效，未找到 prisma/schema.prisma: $BACKEND_PROJECT_DIR"
fi

success "后端项目已找到: $BACKEND_PROJECT_DIR"

# 3. 检查环境变量文件
info "检查环境变量文件..."
if [ ! -f "$CONFIGS_DIR/.env.production" ]; then
    error_exit "未找到 .env.production 文件: $CONFIGS_DIR/.env.production\n请确保已在 configs 目录下配置生产环境变量"
fi
success "环境变量文件已找到: $CONFIGS_DIR/.env.production"

# 4. 拷贝 Dockerfile 和 .dockerignore 到后端项目目录
info "拷贝构建文件到后端项目..."
if [ ! -f "$SCRIPT_DIR/Dockerfile" ]; then
    error_exit "Dockerfile 不存在: $SCRIPT_DIR/Dockerfile"
fi

if [ ! -f "$SCRIPT_DIR/.dockerignore" ]; then
    error_exit ".dockerignore 不存在: $SCRIPT_DIR/.dockerignore"
fi

cp "$SCRIPT_DIR/Dockerfile" "$BACKEND_PROJECT_DIR/Dockerfile"
cp "$SCRIPT_DIR/.dockerignore" "$BACKEND_PROJECT_DIR/.dockerignore"
success "构建文件已拷贝到后端项目目录"

# 5. 检查 Docker 网络（用于与其他服务通信）
info "检查 Docker 网络..."
if ! docker network ls --format '{{.Name}}' | grep -q "^${NETWORK_NAME}$"; then
    warn "Docker 网络 ${NETWORK_NAME} 不存在，正在创建..."
    docker network create "${NETWORK_NAME}" || error_exit "创建 Docker 网络失败"
    success "Docker 网络已创建: ${NETWORK_NAME}"
else
    info "Docker 网络已存在: ${NETWORK_NAME}"
fi

# 6. 停止并删除旧容器（如果存在）
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    info "停止并删除旧容器: ${CONTAINER_NAME}"
    docker stop "${CONTAINER_NAME}" > /dev/null 2>&1 || true
    docker rm "${CONTAINER_NAME}" > /dev/null 2>&1 || true
    success "旧容器已删除"
fi

# 7. 构建 Docker 镜像（在后端项目目录）
info "构建 Docker 镜像: ${IMAGE_NAME}"
cd "$BACKEND_PROJECT_DIR"
docker build -t "${IMAGE_NAME}" .

# 8. 运行新容器
info "启动新容器: ${CONTAINER_NAME}"
info "使用环境变量文件: $CONFIGS_DIR/.env.production"

# 运行容器
docker run -d \
    --name "${CONTAINER_NAME}" \
    --network "${NETWORK_NAME}" \
    --restart unless-stopped \
    -p 3000:3000 \
    --env-file "$CONFIGS_DIR/.env.production" \
    "${IMAGE_NAME}" || error_exit "启动容器失败"

success "容器已启动"

# 9. 清理后端项目目录中的临时文件
info "清理临时文件..."
rm -f "$BACKEND_PROJECT_DIR/Dockerfile"
rm -f "$BACKEND_PROJECT_DIR/.dockerignore"

# 10. 等待容器启动并检查状态
info "等待容器启动..."
sleep 3

if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    success "容器运行正常"
    info "容器日志（最后 20 行）："
    docker logs --tail 20 "${CONTAINER_NAME}"
else
    error_exit "容器启动失败，请检查日志: docker logs ${CONTAINER_NAME}"
fi

echo ""
success "========== 部署完成 =========="
info "API 服务已部署，容器名称: ${CONTAINER_NAME}"
info "API 访问地址: http://localhost:3000"
info "查看日志: docker logs -f ${CONTAINER_NAME}"
info "停止服务: docker stop ${CONTAINER_NAME}"
info "重启服务: docker restart ${CONTAINER_NAME}"
