#!/bin/bash

# 工具函数脚本
# 提供日志、颜色输出、错误处理等通用功能

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志文件路径
LOG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../logs" && pwd)"
LOG_FILE="${LOG_DIR}/deploy-$(date +%Y%m%d-%H%M%S).log"

# 确保日志目录存在
mkdir -p "$LOG_DIR"

# 日志函数
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() {
    log "INFO" "$@"
    echo -e "${BLUE}[INFO]${NC} $@"
}

log_success() {
    log "SUCCESS" "$@"
    echo -e "${GREEN}[SUCCESS]${NC} $@"
}

log_warning() {
    log "WARNING" "$@"
    echo -e "${YELLOW}[WARNING]${NC} $@"
}

log_error() {
    log "ERROR" "$@"
    echo -e "${RED}[ERROR]${NC} $@" >&2
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检查是否为 root 用户
check_root() {
    if [ "$EUID" -eq 0 ]; then
        log_warning "正在以 root 用户运行，建议使用普通用户"
        return 0
    fi
    return 1
}

# 加载环境变量
load_env() {
    local env_file="$1"
    if [ -f "$env_file" ]; then
        log_info "加载环境变量文件: $env_file"
        set -a
        source "$env_file"
        set +a
    else
        log_error "环境变量文件不存在: $env_file"
        return 1
    fi
}

# 获取项目根目录
get_project_root() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    echo "$script_dir"
}

# 获取部署目录
get_deploy_dir() {
    echo "$(get_project_root)"
}

# 确认操作
confirm() {
    local prompt="$1"
    local default="${2:-n}"
    local response
    
    if [ "$default" = "y" ]; then
        prompt="${prompt} [Y/n]: "
    else
        prompt="${prompt} [y/N]: "
    fi
    
    read -p "$prompt" response
    response=${response:-$default}
    
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# 执行命令并检查结果
execute_command() {
    local cmd="$@"
    log_info "执行命令: $cmd"
    
    if eval "$cmd"; then
        log_success "命令执行成功: $cmd"
        return 0
    else
        log_error "命令执行失败: $cmd"
        return 1
    fi
}

# 检查端口是否被占用
check_port() {
    local port=$1
    if command_exists netstat; then
        netstat -tuln | grep -q ":$port "
    elif command_exists ss; then
        ss -tuln | grep -q ":$port "
    else
        log_warning "无法检查端口占用情况（netstat 和 ss 都不可用）"
        return 0
    fi
}

# 等待服务就绪
wait_for_service() {
    local url=$1
    local max_attempts=${2:-30}
    local attempt=0
    
    log_info "等待服务就绪: $url"
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -sf "$url" >/dev/null 2>&1; then
            log_success "服务已就绪: $url"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 2
    done
    
    log_error "服务未能在预期时间内就绪: $url"
    return 1
}

# 清理函数（用于 trap）
cleanup() {
    log_info "执行清理操作..."
    # 可以在这里添加清理逻辑
}

# 设置退出时清理
trap cleanup EXIT

