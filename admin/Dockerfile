# 多阶段构建 - 仅用于构建前端，不运行服务
FROM node:20-alpine AS builder

# 设置工作目录
WORKDIR /app

# 启用 corepack 并安装 pnpm（比 npm install -g pnpm 快）
RUN corepack enable && corepack prepare pnpm@9.15.2 --activate

# 配置 pnpm 阿里云镜像源
RUN pnpm config set registry https://registry.npmmirror.com

# 复制依赖文件（利用 Docker 缓存）
COPY package.json pnpm-lock.yaml ./

# 安装依赖（这一层会被缓存，除非 package.json 或 pnpm-lock.yaml 变化）
RUN pnpm install --frozen-lockfile

# 复制源代码
COPY . .

# 构建前端项目
RUN pnpm build

# 最终阶段：只保留构建产物
FROM scratch AS export
COPY --from=builder /app/dist /dist