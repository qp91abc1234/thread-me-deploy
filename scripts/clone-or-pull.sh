#!/bin/bash

# Git 仓库管理脚本
# 检查项目目录，执行 clone 或 pull 操作

# 加载工具函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# 获取部署目录
DEPLOY_DIR="$(get_deploy_dir)"
PARENT_DIR="$(dirname "$DEPLOY_DIR")"

# Clone 或 Pull 项目
manage_repo() {
    local repo_url=$1
    local repo_name=$2
    local branch=${3:-main}
    local target_dir="${PARENT_DIR}/${repo_name}"
    
    log_info "处理仓库: $repo_name"
    log_info "仓库地址: $repo_url"
    log_info "分支: $branch"
    log_info "目标目录: $target_dir"
    
    if [ -d "$target_dir" ]; then
        log_info "目录已存在，执行 pull 操作"
        cd "$target_dir" || return 1
        
        # 检查是否为 git 仓库
        if [ -d ".git" ]; then
            # 获取当前分支
            local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
            
            # 如果当前分支不是目标分支，尝试切换
            if [ "$current_branch" != "$branch" ]; then
                log_info "当前分支: $current_branch，切换到: $branch"
                if git fetch origin "$branch" 2>/dev/null; then
                    if git checkout "$branch" 2>/dev/null; then
                        log_success "已切换到分支: $branch"
                    else
                        log_warning "无法切换到分支: $branch，继续使用当前分支"
                    fi
                else
                    log_warning "无法获取分支: $branch，继续使用当前分支"
                fi
            fi
            
            # 执行 pull
            log_info "执行 git pull..."
            if execute_command "git pull origin $(git rev-parse --abbrev-ref HEAD)"; then
                log_success "代码更新成功: $repo_name"
                return 0
            else
                log_error "代码更新失败: $repo_name"
                if confirm "Pull 失败，是否继续？"; then
                    return 0
                else
                    return 1
                fi
            fi
        else
            log_warning "目录存在但不是 git 仓库，尝试重新 clone"
            if confirm "是否删除现有目录并重新 clone？"; then
                cd "$PARENT_DIR" || return 1
                if execute_command "rm -rf $target_dir"; then
                    # 继续执行 clone
                else
                    log_error "无法删除目录: $target_dir"
                    return 1
                fi
            else
                log_error "无法继续，目录已存在但不是 git 仓库"
                return 1
            fi
        fi
    fi
    
    # 执行 clone
    if [ ! -d "$target_dir" ]; then
        log_info "目录不存在，执行 clone 操作"
        cd "$PARENT_DIR" || return 1
        
        log_info "克隆仓库到: $target_dir"
        if execute_command "git clone -b $branch $repo_url $target_dir"; then
            log_success "代码克隆成功: $repo_name"
            return 0
        else
            log_error "代码克隆失败: $repo_name"
            return 1
        fi
    fi
    
    return 0
}

# 处理前端项目
manage_frontend() {
    local frontend_repo_url="${FRONTEND_REPO_URL}"
    local frontend_branch="${FRONTEND_BRANCH:-main}"
    local frontend_name="thread-me-admin"
    
    if [ -z "$frontend_repo_url" ]; then
        log_error "前端仓库地址未配置 (FRONTEND_REPO_URL)"
        return 1
    fi
    
    log_info "========== 处理前端项目 =========="
    if manage_repo "$frontend_repo_url" "$frontend_name" "$frontend_branch"; then
        return 0
    else
        return 1
    fi
}

# 处理后端项目
manage_backend() {
    local backend_repo_url="${BACKEND_REPO_URL}"
    local backend_branch="${BACKEND_BRANCH:-main}"
    local backend_name="thread-me-api"
    
    if [ -z "$backend_repo_url" ]; then
        log_error "后端仓库地址未配置 (BACKEND_REPO_URL)"
        return 1
    fi
    
    log_info "========== 处理后端项目 =========="
    if manage_repo "$backend_repo_url" "$backend_name" "$backend_branch"; then
        return 0
    else
        return 1
    fi
}

# 主函数
main() {
    local target=${1:-all}  # all, frontend, backend
    
    log_info "开始管理 Git 仓库..."
    
    case "$target" in
        frontend)
            manage_frontend
            ;;
        backend)
            manage_backend
            ;;
        all|*)
            local frontend_ok=true
            local backend_ok=true
            
            if ! manage_frontend; then
                frontend_ok=false
            fi
            
            if ! manage_backend; then
                backend_ok=false
            fi
            
            if [ "$frontend_ok" = true ] && [ "$backend_ok" = true ]; then
                log_success "所有仓库管理完成"
                return 0
            else
                log_error "部分仓库管理失败"
                return 1
            fi
            ;;
    esac
}

# 如果直接执行此脚本
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi

