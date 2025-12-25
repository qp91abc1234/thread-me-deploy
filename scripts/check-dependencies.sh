#!/bin/bash

# 检查系统依赖脚本
# 检查 git, docker, docker-compose 是否已安装

# 加载工具函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# 检查 Git
check_git() {
    log_info "检查 Git..."
    if command_exists git; then
        local git_version=$(git --version | awk '{print $3}')
        log_success "Git 已安装: $git_version"
        return 0
    else
        log_warning "Git 未安装"
        return 1
    fi
}

# 安装 Git（根据不同的 Linux 发行版）
install_git() {
    log_info "尝试安装 Git..."
    
    if command_exists apt-get; then
        # Debian/Ubuntu
        log_info "检测到 Debian/Ubuntu 系统，使用 apt-get 安装"
        if execute_command "sudo apt-get update && sudo apt-get install -y git"; then
            log_success "Git 安装成功"
            return 0
        fi
    elif command_exists yum; then
        # CentOS/RHEL
        log_info "检测到 CentOS/RHEL 系统，使用 yum 安装"
        if execute_command "sudo yum install -y git"; then
            log_success "Git 安装成功"
            return 0
        fi
    elif command_exists dnf; then
        # Fedora
        log_info "检测到 Fedora 系统，使用 dnf 安装"
        if execute_command "sudo dnf install -y git"; then
            log_success "Git 安装成功"
            return 0
        fi
    else
        log_error "无法自动安装 Git，请手动安装后重试"
        return 1
    fi
    
    return 1
}

# 检查 Docker
check_docker() {
    log_info "检查 Docker..."
    if command_exists docker; then
        local docker_version=$(docker --version | awk '{print $3}' | sed 's/,//')
        log_success "Docker 已安装: $docker_version"
        
        # 检查 Docker 服务是否运行
        if docker info >/dev/null 2>&1; then
            log_success "Docker 服务正在运行"
            return 0
        else
            log_error "Docker 已安装但服务未运行，请启动 Docker 服务"
            log_info "尝试启动 Docker 服务..."
            if command_exists systemctl; then
                if execute_command "sudo systemctl start docker"; then
                    log_success "Docker 服务已启动"
                    return 0
                fi
            fi
            return 1
        fi
    else
        log_error "Docker 未安装"
        log_info "请访问 https://docs.docker.com/get-docker/ 安装 Docker"
        return 1
    fi
}

# 检查 Docker Compose
check_docker_compose() {
    log_info "检查 Docker Compose..."
    
    # 检查 docker compose（新版本，作为插件）
    if docker compose version >/dev/null 2>&1; then
        local compose_version=$(docker compose version | awk '{print $4}')
        log_success "Docker Compose 已安装（插件版本）: $compose_version"
        return 0
    fi
    
    # 检查 docker-compose（旧版本，独立命令）
    if command_exists docker-compose; then
        local compose_version=$(docker-compose --version | awk '{print $3}' | sed 's/,//')
        log_success "Docker Compose 已安装（独立版本）: $compose_version"
        return 0
    fi
    
    log_error "Docker Compose 未安装"
    log_info "请访问 https://docs.docker.com/compose/install/ 安装 Docker Compose"
    return 1
}

# 主函数
main() {
    log_info "开始检查系统依赖..."
    
    local all_ok=true
    
    # 检查 Git
    if ! check_git; then
        if confirm "Git 未安装，是否自动安装？"; then
            if ! install_git; then
                all_ok=false
            fi
        else
            all_ok=false
        fi
    fi
    
    # 检查 Docker
    if ! check_docker; then
        all_ok=false
    fi
    
    # 检查 Docker Compose
    if ! check_docker_compose; then
        all_ok=false
    fi
    
    if [ "$all_ok" = true ]; then
        log_success "所有依赖检查通过"
        return 0
    else
        log_error "部分依赖检查失败，请解决后重试"
        return 1
    fi
}

# 如果直接执行此脚本
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi

