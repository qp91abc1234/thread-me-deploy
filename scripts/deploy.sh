#!/bin/bash

# 主部署脚本
# 功能：
# 1. 检查系统依赖（git, docker, docker-compose）
# 2. 检查/安装 git（如果缺失）
# 3. 检查前后端项目目录，执行 clone 或 pull
# 4. 交互式选择部署选项（前端/后端/全部）
# 5. 根据选择执行对应的 Docker 构建和运行

set -e  # 遇到错误立即退出

# 加载工具函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# 获取部署目录
DEPLOY_DIR="$(get_deploy_dir)"
DOCKER_DIR="${DEPLOY_DIR}/docker"
ENV_FILE="${DEPLOY_DIR}/.env"

# 显示欢迎信息
show_welcome() {
    echo ""
    echo "=========================================="
    echo "   Thread-Me 项目部署脚本"
    echo "=========================================="
    echo ""
}

# 加载环境变量
load_environment() {
    log_info "加载环境变量..."
    
    if [ ! -f "$ENV_FILE" ]; then
        log_error "环境变量文件不存在: $ENV_FILE"
        log_info "请复制 .env.example 为 .env 并配置相关参数"
        exit 1
    fi
    
    load_env "$ENV_FILE"
    log_success "环境变量加载完成"
}

# 检查系统依赖
check_system_dependencies() {
    log_info "========== 检查系统依赖 =========="
    source "${SCRIPT_DIR}/check-dependencies.sh"
    if ! main; then
        log_error "系统依赖检查失败，请解决后重试"
        exit 1
    fi
    echo ""
}

# 管理 Git 仓库
manage_git_repos() {
    log_info "========== 管理 Git 仓库 =========="
    source "${SCRIPT_DIR}/clone-or-pull.sh"
    if ! main "all"; then
        log_error "Git 仓库管理失败"
        if ! confirm "是否继续部署？"; then
            exit 1
        fi
    fi
    echo ""
}

# 选择部署选项
select_deploy_option() {
    echo ""
    echo "请选择部署选项："
    echo "  1) 部署前端"
    echo "  2) 部署后端"
    echo "  3) 同时部署前后端"
    echo "  4) 退出"
    echo ""
    
    read -p "请输入选项 [1-4]: " choice
    
    case $choice in
        1)
            echo "frontend"
            ;;
        2)
            echo "backend"
            ;;
        3)
            echo "all"
            ;;
        4|*)
            log_info "退出部署"
            exit 0
            ;;
    esac
}

# 构建 Docker 镜像
build_image() {
    local service=$1
    local context_path=""
    local dockerfile_path=""
    
    case $service in
        frontend|thread-me-admin)
            context_path="$(dirname "$DEPLOY_DIR")/thread-me-admin"
            dockerfile_path="${context_path}/Dockerfile"
            service_name="thread-me-admin"
            ;;
        backend|thread-me-api)
            context_path="$(dirname "$DEPLOY_DIR")/thread-me-api"
            dockerfile_path="${context_path}/Dockerfile"
            service_name="thread-me-api"
            ;;
        *)
            log_error "未知的服务: $service"
            return 1
            ;;
    esac
    
    if [ ! -d "$context_path" ]; then
        log_error "项目目录不存在: $context_path"
        return 1
    fi
    
    if [ ! -f "$dockerfile_path" ]; then
        log_error "Dockerfile 不存在: $dockerfile_path"
        return 1
    fi
    
    log_info "构建 $service_name 镜像..."
    log_info "构建上下文: $context_path"
    
    cd "$DOCKER_DIR" || return 1
    
    # 构建参数
    local build_args=""
    if [ "$service_name" = "thread-me-admin" ]; then
        build_args="--build-arg VITE_BASE_URL=${VITE_BASE_URL:-/api}"
    fi
    
    # 使用 docker compose build 或 docker-compose build
    if docker compose version >/dev/null 2>&1; then
        if execute_command "docker compose build $build_args $service_name"; then
            log_success "$service_name 镜像构建成功"
            return 0
        else
            log_error "$service_name 镜像构建失败"
            return 1
        fi
    elif command_exists docker-compose; then
        if execute_command "docker-compose build $build_args $service_name"; then
            log_success "$service_name 镜像构建成功"
            return 0
        else
            log_error "$service_name 镜像构建失败"
            return 1
        fi
    else
        log_error "Docker Compose 不可用"
        return 1
    fi
}

# 启动服务
start_service() {
    local service=$1
    local service_name=""
    
    case $service in
        frontend)
            service_name="thread-me-admin"
            ;;
        backend)
            service_name="thread-me-api"
            ;;
        all)
            service_name=""
            ;;
        *)
            log_error "未知的服务: $service"
            return 1
            ;;
    esac
    
    log_info "启动服务: ${service_name:-所有服务}"
    
    cd "$DOCKER_DIR" || return 1
    
    # 使用 docker compose 或 docker-compose
    if docker compose version >/dev/null 2>&1; then
        if [ -n "$service_name" ]; then
            if execute_command "docker compose up -d $service_name"; then
                log_success "$service_name 服务启动成功"
                return 0
            else
                log_error "$service_name 服务启动失败"
                return 1
            fi
        else
            if execute_command "docker compose up -d"; then
                log_success "所有服务启动成功"
                return 0
            else
                log_error "服务启动失败"
                return 1
            fi
        fi
    elif command_exists docker-compose; then
        if [ -n "$service_name" ]; then
            if execute_command "docker-compose up -d $service_name"; then
                log_success "$service_name 服务启动成功"
                return 0
            else
                log_error "$service_name 服务启动失败"
                return 1
            fi
        else
            if execute_command "docker-compose up -d"; then
                log_success "所有服务启动成功"
                return 0
            else
                log_error "服务启动失败"
                return 1
            fi
        fi
    else
        log_error "Docker Compose 不可用"
        return 1
    fi
}

# 执行部署
deploy_service() {
    local service=$1
    
    log_info "========== 部署 $service =========="
    
    # 构建镜像
    case $service in
        frontend)
            if ! build_image "frontend"; then
                return 1
            fi
            ;;
        backend)
            if ! build_image "backend"; then
                return 1
            fi
            ;;
        all)
            if ! build_image "frontend"; then
                log_warning "前端构建失败，继续部署后端"
            fi
            if ! build_image "backend"; then
                return 1
            fi
            ;;
    esac
    
    # 启动服务
    if ! start_service "$service"; then
        return 1
    fi
    
    # 等待服务就绪
    log_info "等待服务就绪..."
    sleep 5
    
    # 显示服务状态
    show_service_status
    
    log_success "========== 部署完成 =========="
    echo ""
    show_service_info
}

# 显示服务状态
show_service_status() {
    log_info "========== 服务状态 =========="
    cd "$DOCKER_DIR" || return 1
    
    if docker compose version >/dev/null 2>&1; then
        docker compose ps
    elif command_exists docker-compose; then
        docker-compose ps
    fi
    echo ""
}

# 显示服务信息
show_service_info() {
    local frontend_port="${FRONTEND_PORT:-80}"
    local backend_port="${BACKEND_PORT:-3000}"
    
    echo "=========================================="
    echo "   部署信息"
    echo "=========================================="
    echo "前端服务: http://localhost:${frontend_port}"
    echo "后端服务: http://localhost:${backend_port}"
    echo ""
    echo "查看日志:"
    echo "  cd $DOCKER_DIR"
    if docker compose version >/dev/null 2>&1; then
        echo "  docker compose logs -f"
    else
        echo "  docker-compose logs -f"
    fi
    echo ""
    echo "停止服务:"
    echo "  cd $DOCKER_DIR"
    if docker compose version >/dev/null 2>&1; then
        echo "  docker compose down"
    else
        echo "  docker-compose down"
    fi
    echo "=========================================="
    echo ""
}

# 主函数
main() {
    show_welcome
    
    # 加载环境变量
    load_environment
    
    # 检查系统依赖
    check_system_dependencies
    
    # 管理 Git 仓库
    manage_git_repos
    
    # 选择部署选项
    local deploy_option=$(select_deploy_option)
    
    if [ -z "$deploy_option" ]; then
        log_info "已取消部署"
        exit 0
    fi
    
    # 执行部署
    if deploy_service "$deploy_option"; then
        log_success "部署流程完成"
        exit 0
    else
        log_error "部署流程失败"
        exit 1
    fi
}

# 执行主函数
main "$@"

