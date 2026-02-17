# 多阶段构建 - 构建 NestJS 应用
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

# 安装依赖（如果 lockfile 不同步，先更新 lockfile 再安装）
RUN pnpm install --frozen-lockfile 2>/dev/null || pnpm install

# 设置占位符 DATABASE_URL（prisma generate 只需要 schema，不需要真实数据库连接）
# 使用 MySQL 格式的占位符 URL
ENV DATABASE_URL="mysql://user:password@localhost:3306/database"

# 复制源代码
COPY . .

# 生成 Prisma Client
RUN pnpm prisma:generate

# 构建项目
RUN pnpm build

# 生产运行阶段
FROM node:20-alpine AS runner

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

# 创建非 root 用户
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nestjs -u 1001

# 复制依赖文件
COPY package.json pnpm-lock.yaml prisma.config.ts ./
COPY /prisma/schema.prisma ./prisma/
COPY /prisma/migrations ./prisma/migrations/

# 只安装生产依赖（如果 lockfile 不同步，先更新 lockfile 再安装）
RUN pnpm install --frozen-lockfile --prod 2>/dev/null || pnpm install --prod

# 再安装构建所需的开发依赖（根据实际需要调整）
RUN pnpm install --frozen-lockfile \
    prisma \
    tsconfig-paths \
    2>/dev/null || pnpm install prisma tsconfig-paths

# 复制构建产物（包含 dist/prisma/generated，运行时不需要 schema.prisma）
COPY --from=builder /app/dist ./dist

# 设置权限
RUN chown -R nestjs:nodejs /app

# 切换到非 root 用户
USER nestjs

# 暴露端口
EXPOSE 3300

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:3300/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)}).on('error', () => process.exit(1))"

# 启动应用（按顺序执行：迁移 → 种子数据（可选）→ 收集权限 → 启动应用）
# 调试时添加: || tail -f /dev/null
CMD sh -c "\
  npx prisma migrate deploy && \
  ([ \"$RUN_SEED\" = \"true\" ] && node dist/scripts/prisma-seed.js || true) && \
  node dist/scripts/collect-api-permissions.js && \
  node dist/src/main.js || tail -f /dev/null" 

