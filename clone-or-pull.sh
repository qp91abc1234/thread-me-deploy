#!/bin/bash
# clone-or-pull.sh - 代码仓库克隆/拉取脚本
# 功能：检查代码仓库是否存在，不存在则克隆，存在则拉取最新代码

# 自动添加执行权限
chmod +x "$0" 2>/dev/null || true

set -e  # 遇到错误立即退出

# ==================== 代码仓库配置 ====================
# 代码仓库地址（请根据实际情况修改）
REPO_ADMIN="git@github.com:qp91abc1234/thread-me-admin.git"  # admin 仓库地址
REPO_API="git@github.com:qp91abc1234/thread-me-api.git"      # api 仓库地址
REPO_DEPLOY="git@github.com:qp91abc1234/thread-me-deploy.git" # deploy 仓库地址

# 仓库列表（仓库名称:仓库地址）
REPOS=(
    "thread-me-admin:$REPO_ADMIN"
    "thread-me-api:$REPO_API"
    "thread-me-deploy:$REPO_DEPLOY"
)

# 目标目录（脚本所在目录，作为独立脚本使用）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$SCRIPT_DIR"

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

# 处理单个仓库
process_repo() {
    local repo_name=$1
    local repo_url=$2
    local repo_dir="$TARGET_DIR/$repo_name"
    
    info "处理仓库: $repo_name"
    
    # 检查目录是否存在
    if [ -d "$repo_dir" ]; then
        # 目录存在，检查是否是 git 仓库
        if [ -d "$repo_dir/.git" ]; then
            info "检测到已存在的 git 仓库: $repo_dir"
            info "拉取最新代码..."
            
            cd "$repo_dir"
            
            # 检查是否有未提交的更改
            if [ -n "$(git status --porcelain)" ]; then
                warn "检测到未提交的更改，尝试暂存..."
                git stash || warn "暂存失败，继续执行拉取操作"
            fi
            
            # 拉取最新代码
            git pull || error_exit "拉取 $repo_name 失败"
            
            success "$repo_name 拉取完成"
        else
            warn "目录 $repo_dir 存在但不是 git 仓库，跳过"
        fi
    else
        # 目录不存在，克隆仓库
        info "目录不存在，开始克隆仓库..."
        info "克隆地址: $repo_url"
        info "目标目录: $repo_dir"
        
        # 克隆仓库
        git clone "$repo_url" "$repo_dir" || error_exit "克隆 $repo_name 失败"
        
        success "$repo_name 克隆完成"
    fi
    
    echo ""
}

# 主函数
main() {
    info "========== 开始处理代码仓库 =========="
    info "目标目录: $TARGET_DIR"
    echo ""
    
    # 检查 git 是否安装
    if ! command -v git &> /dev/null; then
        error_exit "git 未安装，请先安装 git"
    fi
    
    # 处理每个仓库
    for repo_info in "${REPOS[@]}"; do
        IFS=':' read -r repo_name repo_url <<< "$repo_info"
        process_repo "$repo_name" "$repo_url"
    done
    
    echo ""
    success "========== 所有仓库处理完成 =========="
}

# 执行主函数
main
