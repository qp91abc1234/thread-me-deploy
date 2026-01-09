#!/bin/bash
# deploy.sh - Docker 构建并部署前端

set -e  # 遇到错误立即退出

# 配置
IMAGE_NAME="thread-me-admin"
CONTAINER_NAME="thread-me-admin-temp"
DEPLOY_DIR="/root/volume/nginx/html/admin"

echo "开始 Docker 构建部署..."

# 1. 检查 Docker 是否可用
if ! command -v docker &> /dev/null; then
    echo "❌ 错误：未找到 Docker，请先安装 Docker"
    exit 1
fi

# 2. 删除已存在的临时容器（如果存在）
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "删除已存在的临时容器: ${CONTAINER_NAME}"
    docker rm -f "${CONTAINER_NAME}" > /dev/null 2>&1 || true
fi

# 3. 构建 Docker 镜像
echo "构建 Docker 镜像: ${IMAGE_NAME}"
docker build -t "${IMAGE_NAME}" .

# 4. 创建临时容器（用于提取构建产物）
echo "创建临时容器: ${CONTAINER_NAME}"
docker create --name "${CONTAINER_NAME}" "${IMAGE_NAME}"

# 5. 提取构建产物到本地
echo "提取构建产物..."
rm -rf ./dist
docker cp "${CONTAINER_NAME}:/dist" ./dist

# 6. 删除临时容器
echo "删除临时容器..."
docker rm "${CONTAINER_NAME}"

# 7. 检查构建产物
if [ ! -d "dist" ] || [ -z "$(ls -A dist)" ]; then
    echo "❌ 错误：构建失败，未找到构建产物"
    exit 1
fi

# 8. 拷贝产物到部署目录
if [ ! -d "$(dirname "$DEPLOY_DIR")" ]; then
    echo "❌ 错误：部署目录的父目录不存在: $(dirname "$DEPLOY_DIR")"
    echo "请修改脚本中的 DEPLOY_DIR 变量为正确的路径"
    exit 1
fi

echo "拷贝构建产物到部署目录..."
mkdir -p "${DEPLOY_DIR}"
cp -r dist/* "${DEPLOY_DIR}/"

# 9. 清理本地临时文件（可选）
# rm -rf ./dist

echo "✅ 部署完成！"
echo "构建产物已复制到: ${DEPLOY_DIR}"
echo "访问路径: http://your-domain/admin/"
