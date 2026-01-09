#!/bin/bash
# init.sh - 初始化脚本
# 功能：安装 git，配置 git，生成 SSH 密钥，并克隆或拉取部署项目
# 注意：此脚本是独立脚本，可单独使用

# 自动添加执行权限
chmod +x "$0" 2>/dev/null || true

set -e  # 遇到错误立即退出

# ==================== 配置变量 ====================
# Git 配置
GIT_EMAIL="350018736@qq.com"
GIT_NAME="zcc"

# 部署项目仓库地址（请根据实际情况修改）
DEPLOY_REPO_URL="git@github.com:qp91abc1234/thread-me-deploy.git"

# 部署项目目标目录（与脚本同级）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_TARGET_DIR="$SCRIPT_DIR/thread-me-deploy"

# Yum 镜像源配置（CentOS）
YUM_MIRROR_BASE="http://mirrors.aliyun.com"

# ==================== 颜色输出 ====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# ==================== 主函数 ====================
main() {
    info "========== 开始初始化 =========="
    echo ""
    
    # 1. 检查 root 权限（安装软件需要 root）
    if [ "$EUID" -ne 0 ]; then
        error_exit "此脚本需要 root 权限运行，请使用 sudo 或 root 用户执行"
    fi
    
    # 2. 检测操作系统类型
    if [ -f /etc/redhat-release ]; then
        OS_TYPE="centos"
        info "检测到 CentOS 系统"
    elif [ -f /etc/debian_version ]; then
        OS_TYPE="debian"
        info "检测到 Debian/Ubuntu 系统"
    else
        warn "未识别的操作系统，将尝试通用方式安装 git"
        OS_TYPE="unknown"
    fi
    
    # 3. 配置 yum 镜像源（仅 CentOS）
    if [ "$OS_TYPE" = "centos" ]; then
        info "配置 yum 阿里云镜像源..."
        cat > /etc/yum.repos.d/CentOS-Base.repo << EOF
[base]
name=CentOS-\$releasever - Base - mirrors.aliyun.com
failovermethod=priority
baseurl=${YUM_MIRROR_BASE}/centos/\$releasever/os/\$basearch/
gpgcheck=1
gpgkey=${YUM_MIRROR_BASE}/centos/RPM-GPG-KEY-CentOS-7

[updates]
name=CentOS-\$releasever - Updates - mirrors.aliyun.com
failovermethod=priority
baseurl=${YUM_MIRROR_BASE}/centos/\$releasever/updates/\$basearch/
gpgcheck=1
gpgkey=${YUM_MIRROR_BASE}/centos/RPM-GPG-KEY-CentOS-7

[extras]
name=CentOS-\$releasever - Extras - mirrors.aliyun.com
failovermethod=priority
baseurl=${YUM_MIRROR_BASE}/centos/\$releasever/extras/\$basearch/
gpgcheck=1
gpgkey=${YUM_MIRROR_BASE}/centos/RPM-GPG-KEY-CentOS-7
EOF
        
        # 清理 yum 缓存
        yum clean all > /dev/null 2>&1 || warn "清理 yum 缓存失败"
        yum makecache > /dev/null 2>&1 || warn "重建 yum 缓存失败"
        info "yum 镜像源配置完成"
        echo ""
    fi
    
    # 4. 检测并安装 git
    if command -v git &> /dev/null; then
        info "git 已安装: $(git --version)"
    else
        info "检测到 git 未安装，开始安装..."
        
        if [ "$OS_TYPE" = "centos" ]; then
            yum install -y git || error_exit "git 安装失败，请检查网络连接和 yum 源配置"
        elif [ "$OS_TYPE" = "debian" ]; then
            apt-get update || error_exit "更新 apt 源失败"
            apt-get install -y git || error_exit "git 安装失败"
        else
            error_exit "无法自动安装 git，请手动安装后重新运行此脚本"
        fi
        
        success "git 安装完成: $(git --version)"
    fi
    echo ""
    
    # 5. 配置 git 用户信息
    info "配置 git 用户信息..."
    git config --global user.email "$GIT_EMAIL" || error_exit "配置 git user.email 失败"
    git config --global user.name "$GIT_NAME" || error_exit "配置 git user.name 失败"
    success "git 用户信息配置完成"
    echo ""
    
    # 6. 检测并生成 Git SSH 密钥
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
        
        success "SSH 密钥生成完成"
        
        # 显示公钥内容
        echo ""
        info "========== SSH 公钥内容 =========="
        cat "$SSH_KEY_ED25519.pub"
        echo ""
        warn "请将上述公钥添加到你的 Git 平台（GitHub/GitLab/Gitee 等）"
        warn "添加完成后，按 Enter 继续..."
        read -r
    fi
    echo ""
    
    # 7. 克隆或拉取部署项目
    info "处理部署项目仓库..."
    info "仓库地址: $DEPLOY_REPO_URL"
    info "目标目录: $DEPLOY_TARGET_DIR"
    echo ""
    
    if [ -d "$DEPLOY_TARGET_DIR" ]; then
        # 目录存在，检查是否是 git 仓库
        if [ -d "$DEPLOY_TARGET_DIR/.git" ]; then
            info "检测到已存在的 git 仓库: $DEPLOY_TARGET_DIR"
            info "拉取最新代码..."
            
            cd "$DEPLOY_TARGET_DIR"
            
            # 检查是否有未提交的更改
            if [ -n "$(git status --porcelain)" ]; then
                warn "检测到未提交的更改，尝试暂存..."
                git stash || warn "暂存失败，继续执行拉取操作"
            fi
            
            # 拉取最新代码
            git pull || error_exit "拉取部署项目失败"
            
            success "部署项目拉取完成"
        else
            warn "目录 $DEPLOY_TARGET_DIR 存在但不是 git 仓库"
            read -p "是否删除该目录并重新克隆？(y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                rm -rf "$DEPLOY_TARGET_DIR"
                info "开始克隆仓库..."
                git clone "$DEPLOY_REPO_URL" "$DEPLOY_TARGET_DIR" || error_exit "克隆部署项目失败"
                success "部署项目克隆完成"
            else
                error_exit "请手动处理目录 $DEPLOY_TARGET_DIR 后重新运行"
            fi
        fi
    else
        # 目录不存在，克隆仓库
        info "目录不存在，开始克隆仓库..."
        git clone "$DEPLOY_REPO_URL" "$DEPLOY_TARGET_DIR" || error_exit "克隆部署项目失败"
        success "部署项目克隆完成"
    fi
    echo ""
    
    # 8. 显示完成信息
    echo ""
    info "========== 初始化完成 =========="
    if command -v git &> /dev/null; then
        echo "Git 版本: $(git --version)"
        GIT_EMAIL_CONFIG=$(git config --global user.email 2>/dev/null || echo "未配置")
        GIT_NAME_CONFIG=$(git config --global user.name 2>/dev/null || echo "未配置")
        echo "Git 邮箱: $GIT_EMAIL_CONFIG"
        echo "Git 用户名: $GIT_NAME_CONFIG"
    fi
    
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
    success "部署项目位置: $DEPLOY_TARGET_DIR"
    echo ""
}

# 执行主函数
main
