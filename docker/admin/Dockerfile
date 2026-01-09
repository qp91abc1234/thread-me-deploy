# 多阶段构建 - 仅用于构建前端，不运行服务
FROM node:20-alpine AS builder

# 设置工作目录
WORKDIR /app

# 安装 pnpm
RUN npm install -g pnpm

# 复制依赖文件
COPY package.json pnpm-lock.yaml ./

# 安装依赖
RUN pnpm install --frozen-lockfile

# 复制源代码
COPY . .

# 构建前端项目
RUN pnpm build

# 最终阶段：只保留构建产物
FROM alpine:latest AS export
# 添加一个最小的 CMD，满足 docker create 的要求（虽然不会真正执行）
CMD ["/bin/sh"]
COPY --from=builder /app/dist /dist
