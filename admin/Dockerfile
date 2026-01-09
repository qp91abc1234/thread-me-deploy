# 多阶段构建 - 仅用于构建前端，不运行服务
FROM node:20-alpine AS builder

# 设置工作目录
WORKDIR /app

# 配置 Alpine 阿里云镜像源
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

# 配置 npm 阿里云镜像源
RUN npm config set registry https://registry.npmmirror.com

# 安装 pnpm
RUN npm install -g pnpm

# 配置 pnpm 阿里云镜像源
RUN pnpm config set registry https://registry.npmmirror.com

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

# 配置 Alpine 阿里云镜像源
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

# 添加一个最小的 CMD，满足 docker create 的要求（虽然不会真正执行）
CMD ["/bin/sh"]
COPY --from=builder /app/dist /dist
