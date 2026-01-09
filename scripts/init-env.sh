#!/bin/bash
# init-env.sh - CentOS 7 环境初始化脚本
# 功能：检测并安装 git、docker-ce，配置 yum 和 docker 镜像源

# 自动添加执行权限
chmod +x "$0" 2>/dev/null || true

set -e  # 遇到错误立即退出

# 配置变量
GIT_EMAIL="350018736@qq.com"
GIT_NAME="zcc"

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

# 1. 检查 root 权限
if [ "$EUID" -ne 0 ]; then
    error_exit "此脚本需要 root 权限运行，请使用 sudo 或 root 用户执行"
fi

info "开始初始化环境..."

# 2. 配置 yum 阿里云镜像源
info "配置 yum 阿里云镜像源..."
cat > /etc/yum.repos.d/CentOS-Base.repo << 'EOF'
[base]
name=CentOS-$releasever - Base - mirrors.aliyun.com
failovermethod=priority
baseurl=http://mirrors.aliyun.com/centos/$releasever/os/$basearch/
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7

[updates]
name=CentOS-$releasever - Updates - mirrors.aliyun.com
failovermethod=priority
baseurl=http://mirrors.aliyun.com/centos/$releasever/updates/$basearch/
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7

[extras]
name=CentOS-$releasever - Extras - mirrors.aliyun.com
failovermethod=priority
baseurl=http://mirrors.aliyun.com/centos/$releasever/extras/$basearch/
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7
EOF

# 清理 yum 缓存
yum clean all > /dev/null 2>&1 || error_exit "清理 yum 缓存失败"
yum makecache > /dev/null 2>&1 || error_exit "重建 yum 缓存失败"

info "yum 镜像源配置完成"

# 3. 检测并安装 git
if command -v git &> /dev/null; then
    info "git 已安装，跳过安装步骤"
else
    info "检测到 git 未安装，开始安装..."
    yum install -y git || error_exit "git 安装失败，请检查网络连接和 yum 源配置"
    info "git 安装完成"
fi

# 3.1. 配置 git 用户信息
info "配置 git 用户信息..."
git config --global user.email "$GIT_EMAIL" || error_exit "配置 git user.email 失败"
git config --global user.name "$GIT_NAME" || error_exit "配置 git user.name 失败"
info "git 用户信息配置完成"

# 3.1. 检测并生成 Git SSH 密钥
info "检查 Git SSH 密钥..."
SSH_DIR="$HOME/.ssh"
SSH_KEY_ED25519="$SSH_DIR/id_ed25519"
SSH_KEY_RSA="$SSH_DIR/id_rsa"

# 创建 .ssh 目录（如果不存在）
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# 检查是否已存在 SSH 密钥
if [ -f "$SSH_KEY_ED25519" ] || [ -f "$SSH_KEY_RSA" ]; then
    info "检测到已存在 SSH 密钥，跳过生成步骤"
    if [ -f "$SSH_KEY_ED25519" ]; then
        info "现有密钥: $SSH_KEY_ED25519"
    elif [ -f "$SSH_KEY_RSA" ]; then
        info "现有密钥: $SSH_KEY_RSA"
    fi
else
    info "未检测到 SSH 密钥，开始生成..."
    
    # 生成 ED25519 密钥（更安全、更现代）
    info "生成 ED25519 SSH 密钥..."
    ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f "$SSH_KEY_ED25519" -N "" || error_exit "SSH 密钥生成失败"
    
    # 设置正确的权限
    chmod 600 "$SSH_KEY_ED25519"
    chmod 644 "$SSH_KEY_ED25519.pub"
    
    info "SSH 密钥生成完成"
    
    # 显示公钥内容
    echo ""
    info "========== SSH 公钥内容 =========="
    cat "$SSH_KEY_ED25519.pub"
    echo ""
    warn "请将上述公钥添加到你的 Git 平台（GitHub/GitLab/Gitee 等）"
fi

# 4. 检测并安装 docker-ce
if command -v docker &> /dev/null; then
    info "docker 已安装，跳过安装步骤"
else
    info "检测到 docker 未安装，开始安装 docker-ce..."
    
    # 安装必要的依赖
    yum install -y yum-utils device-mapper-persistent-data lvm2 || error_exit "安装 docker 依赖失败"
    
    # 添加 Docker 官方仓库（使用阿里云镜像加速）
    yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo || error_exit "添加 Docker 仓库失败"
    
    # 安装 docker-ce
    yum install -y docker-ce || error_exit "docker-ce 安装失败，请检查网络连接和仓库配置"
    
    # 启动 Docker 服务并设置开机自启
    systemctl start docker || error_exit "启动 Docker 服务失败"
    systemctl enable docker || error_exit "设置 Docker 开机自启失败"
    
    info "docker-ce 安装完成"
fi

# 5. 配置 Docker 镜像源
info "配置 Docker 镜像源..."
mkdir -p /etc/docker

# 检查是否已存在 daemon.json
if [ -f /etc/docker/daemon.json ]; then
    # 如果文件存在，检查是否已有 registry-mirrors
    if grep -q "registry-mirrors" /etc/docker/daemon.json; then
        warn "检测到 /etc/docker/daemon.json 中已有 registry-mirrors 配置，将覆盖"
    fi
fi

# 创建或覆盖 daemon.json
cat > /etc/docker/daemon.json << 'EOF'
{
  "registry-mirrors": ["https://docker.1ms.run"]
}
EOF

# 重启 Docker 服务使配置生效
systemctl daemon-reload || error_exit "重新加载 systemd 配置失败"
systemctl restart docker || error_exit "重启 Docker 服务失败"

info "Docker 镜像源配置完成"

# 6. 显示安装的软件版本
echo ""
info "========== 安装信息 =========="
if command -v git &> /dev/null; then
    echo "Git 版本: $(git --version)"
    GIT_EMAIL=$(git config --global user.email 2>/dev/null || echo "未配置")
    GIT_NAME=$(git config --global user.name 2>/dev/null || echo "未配置")
    echo "Git 邮箱: $GIT_EMAIL"
    echo "Git 用户名: $GIT_NAME"
else
    echo "Git: 未安装"
fi

if command -v docker &> /dev/null; then
    echo "Docker 版本: $(docker --version)"
    echo "Docker 服务状态: $(systemctl is-active docker)"
else
    echo "Docker: 未安装"
fi

# 显示 SSH 密钥信息
SSH_KEY_ED25519="$HOME/.ssh/id_ed25519"
SSH_KEY_RSA="$HOME/.ssh/id_rsa"
if [ -f "$SSH_KEY_ED25519" ]; then
    echo "SSH 密钥: $SSH_KEY_ED25519 (ED25519)"
elif [ -f "$SSH_KEY_RSA" ]; then
    echo "SSH 密钥: $SSH_KEY_RSA (RSA)"
else
    echo "SSH 密钥: 未生成"
fi

echo ""
info "✅ 环境初始化完成！"
