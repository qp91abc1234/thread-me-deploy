# 公共容器服务配置

此目录包含 Redis、MySQL、Nginx 等公共基础设施容器的配置。

## 快速开始

### 1. 初始化服务

```bash
cd /path/to/thread-me-deploy/scripts
sudo ./setup-common-services.sh init
```

初始化过程会：
- 创建必要的目录结构
- 生成环境变量配置文件（`.env`）
- 生成 `docker-compose.yml` 配置文件

注意：首次运行前请确保已运行 `init-env.sh` 安装 Docker 和 docker-compose

### 2. 启动服务

```bash
sudo ./setup-common-services.sh start
```

### 3. 查看服务状态

```bash
sudo ./setup-common-services.sh status
```

### 4. 查看日志

```bash
# 查看所有服务日志
sudo ./setup-common-services.sh logs

# 查看特定服务日志
sudo ./setup-common-services.sh logs mysql
sudo ./setup-common-services.sh logs redis
sudo ./setup-common-services.sh logs nginx
```

## 服务说明

### MySQL

- **端口**: 3306
- **数据目录**: `/root/volume/mysql/data`
- **配置目录**: `/root/volume/mysql/conf`
- **镜像**: `mysql:8.0`
- **字符集**: utf8mb4

### Redis

- **端口**: 6379
- **数据目录**: `/root/volume/redis/data`
- **镜像**: `redis:7-alpine`
- **持久化**: AOF 模式

### Nginx

- **HTTP 端口**: 80
- **HTTPS 端口**: 443
- **静态文件目录**: `/root/volume/nginx/html`
- **配置目录**: `/root/volume/nginx/conf`
- **日志目录**: `/root/volume/nginx/logs`
- **镜像**: `nginx:alpine`

## 配置文件

- `docker-compose.yml`: Docker Compose 服务定义
- `.env`: 环境变量配置（包含密码，请妥善保管）
- `.env.example`: 环境变量配置模板
- `nginx/conf.d/`: Nginx 配置文件目录

## 数据持久化

所有数据都存储在 `/root/volume/` 目录下，确保容器重启后数据不丢失。

## 网络

所有服务都连接到 `thread-me-network` 网络，业务容器可以通过此网络访问公共服务。

## 注意事项

1. 首次运行前请确保已运行 `init-env.sh` 安装 Docker
2. 环境变量文件 `.env` 包含敏感信息，请妥善保管
3. 修改配置后需要重启服务才能生效
4. 建议定期备份数据目录
