# Thread-Me 项目部署文档

本文档说明如何使用 Docker 部署 thread-me 项目的前后端服务。

## 目录结构

```
thread-me-deploy/
├── README.md                    # 本文档
├── .env.example                 # 环境变量模板
├── .gitignore                   # Git忽略文件
│
├── scripts/                     # 部署脚本目录
│   ├── deploy.sh               # 主部署脚本
│   ├── check-dependencies.sh   # 检查系统依赖
│   ├── clone-or-pull.sh        # Git仓库管理
│   └── utils.sh                # 工具函数
│
├── docker/                      # Docker相关配置
│   ├── docker-compose.yml      # 容器编排配置
│   └── .dockerignore           # Docker构建忽略文件
│
└── logs/                        # 部署日志目录
```

## 前置要求

### 系统要求
- Linux 操作系统（推荐 Ubuntu 20.04+ 或 CentOS 7+）
- Git（脚本会自动检查并安装）
- Docker 20.10+
- Docker Compose 2.0+

### 外部服务
- MySQL 数据库（已部署，不在容器中）
- Redis 服务（已部署，不在容器中）

## 快速开始

### 1. 配置环境变量

复制环境变量模板并填写实际值：

```bash
cd thread-me-deploy
cp .env.example .env
vim .env  # 编辑环境变量
```

### 2. 执行部署脚本

```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

部署脚本会：
1. 检查系统依赖（git, docker, docker-compose）
2. 检查/安装 git（如果缺失）
3. 检查前后端项目目录，执行 clone 或 pull
4. 提供交互式部署选项（前端/后端/全部）
5. 构建并启动 Docker 容器

## 环境变量配置

### Git 仓库配置

```bash
# Git 仓库地址
FRONTEND_REPO_URL=https://github.com/your-org/thread-me-admin.git
BACKEND_REPO_URL=https://github.com/your-org/thread-me-api.git

# Git 分支（可选，默认为 main）
FRONTEND_BRANCH=main
BACKEND_BRANCH=main
```

### 前端配置

```bash
# API 基础 URL
VITE_BASE_URL=/api
```

### 后端配置

```bash
# 应用配置
NODE_ENV=production
APP_URL=http://your-domain.com

# JWT 配置
JWT_SECRET=your-secret-key
JWT_ACCESS_TOKEN_EXPIRE_TIME=30m
JWT_REFRESH_TOKEN_EXPIRE_TIME=7d

# 数据库配置
DATABASE_URL=mysql://user:password@host:port/database

# Redis 配置
REDIS_HOST=your-redis-host
REDIS_PORT=6379
REDIS_PASSWORD=your-redis-password
REDIS_DB=0

# 其他配置...
```

详细配置请参考 `.env.example` 文件。

## 部署选项

执行部署脚本时，可以选择：

1. **部署前端** - 仅构建和启动前端容器
2. **部署后端** - 仅构建和启动后端容器
3. **同时部署** - 构建和启动前后端容器

## 容器管理

### 查看容器状态

```bash
cd thread-me-deploy/docker
docker-compose ps
```

### 查看日志

```bash
# 查看所有服务日志
docker-compose logs -f

# 查看特定服务日志
docker-compose logs -f thread-me-api
docker-compose logs -f thread-me-admin
```

### 停止服务

```bash
cd thread-me-deploy/docker
docker-compose down
```

### 重启服务

```bash
cd thread-me-deploy/docker
docker-compose restart
```

## 端口说明

- **前端服务**: 默认端口 `80`（可通过环境变量修改）
- **后端服务**: 默认端口 `3000`（可通过环境变量修改）

## 故障排查

### 1. Git 相关错误

如果遇到 Git 权限问题，请确保：
- 使用 HTTPS 时，配置了正确的用户名和密码
- 使用 SSH 时，配置了 SSH 密钥

### 2. Docker 构建失败

检查：
- Docker 服务是否正常运行
- 磁盘空间是否充足
- 网络连接是否正常

### 3. 容器启动失败

查看容器日志：
```bash
docker-compose logs [service-name]
```

检查环境变量配置是否正确。

### 4. 数据库连接失败

确保：
- MySQL 服务正常运行
- 数据库连接信息正确
- 防火墙规则允许连接

### 5. Redis 连接失败

确保：
- Redis 服务正常运行
- Redis 连接信息正确
- Redis 密码配置正确

## 更新部署

### 更新代码

部署脚本会自动检测项目目录：
- 如果目录不存在，会执行 `git clone`
- 如果目录存在，会执行 `git pull` 拉取最新代码

### 重新构建

```bash
cd thread-me-deploy/docker
docker-compose build --no-cache
docker-compose up -d
```

## 安全建议

1. **不要提交 `.env` 文件到 Git**
2. **使用强密码和密钥**
3. **定期更新依赖和镜像**
4. **限制容器网络访问**
5. **使用非 root 用户运行容器**

## 常见问题

### Q: 如何修改端口？

A: 在 `.env` 文件中修改 `FRONTEND_PORT` 和 `BACKEND_PORT` 变量，然后重新部署。

### Q: 如何查看部署日志？

A: 部署日志保存在 `thread-me-deploy/logs/` 目录中。

### Q: 如何回滚到之前的版本？

A: 使用 Git 切换到之前的版本，然后重新执行部署脚本。

## 技术支持

如有问题，请查看项目文档或提交 Issue。

