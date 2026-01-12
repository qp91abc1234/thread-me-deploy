@echo off
REM docker-desktop.bat - Windows Docker Desktop 管理脚本
REM 用于管理 docker-compose-desktop.yml 服务

chcp 65001 >nul
setlocal enabledelayedexpansion

REM 获取脚本所在目录（即部署项目根目录）
set "SCRIPT_DIR=%~dp0"
REM 配置文件目录
set "CONFIGS_DIR=%SCRIPT_DIR%configs"
REM docker-compose-desktop.yml 文件路径
set "COMPOSE_FILE=%CONFIGS_DIR%\docker-compose-desktop.yml"

REM 检查 docker-compose 是否可用
docker-compose --version >nul 2>&1
if errorlevel 1 (
    echo [错误] 未找到 docker-compose 命令，请确保 Docker Desktop 已安装并运行
    exit /b 1
)

REM 检查配置文件是否存在
if not exist "%COMPOSE_FILE%" (
    echo [错误] 找不到配置文件: %COMPOSE_FILE%
    exit /b 1
)

REM 如果有命令行参数，直接执行对应操作
if not "%~1"=="" (
    set "ACTION=%~1"
    goto :execute_action
)

REM 显示菜单
:menu
cls
echo ========================================
echo   Docker Desktop 服务管理
echo ========================================
echo   1. 启动服务
echo   2. 停止服务（保留数据）
echo   3. 停止服务并删除卷（清除数据）
echo   0. 退出
echo ========================================
set /p "CHOICE=请选择操作: "

if "%CHOICE%"=="1" (
    set "ACTION=start"
    goto :execute_action
)
if "%CHOICE%"=="2" (
    set "ACTION=stop"
    goto :execute_action
)
if "%CHOICE%"=="3" (
    set "ACTION=remove"
    goto :execute_action
)
if "%CHOICE%"=="0" (
    echo 再见！
    exit /b 0
)

echo [错误] 无效的选择，请重新输入
pause
goto :menu

:execute_action
pushd "%CONFIGS_DIR%"

if "%ACTION%"=="start" (
    echo.
    echo [信息] 正在启动服务...
    docker-compose -f docker-compose-desktop.yml up -d
    if errorlevel 1 (
        echo [错误] 服务启动失败
    ) else (
        echo [成功] 服务启动成功！
        echo.
        echo 查看服务状态: docker-compose -f docker-compose-desktop.yml ps
        echo 查看日志: docker-compose -f docker-compose-desktop.yml logs -f
    )
    goto :end
)

if "%ACTION%"=="stop" (
    echo.
    echo [信息] 正在停止服务（保留数据）...
    docker-compose -f docker-compose-desktop.yml down
    if errorlevel 1 (
        echo [错误] 停止服务失败
    ) else (
        echo [成功] 服务已停止，数据已保留
    )
    goto :end
)

if "%ACTION%"=="remove" (
    echo.
    echo [警告] 此操作将停止服务并删除所有数据卷！
    echo [警告] 所有数据将被永久删除，此操作不可恢复！
    set /p "CONFIRM=确认继续？(输入 yes 继续，其他任意键取消): "
    
    if not "!CONFIRM!"=="yes" (
        echo [信息] 操作已取消
        goto :end
    )
    
    echo.
    echo [信息] 正在停止服务并删除数据卷...
    docker-compose -f docker-compose-desktop.yml down -v
    if errorlevel 1 (
        echo [错误] 操作失败
    ) else (
        echo [成功] 服务已停止，所有数据卷已删除
    )
    goto :end
)

echo [错误] 未知的操作: %ACTION%
echo 用法: docker-desktop.bat [start^|stop^|remove]
echo   或直接运行脚本进入交互式菜单

:end
popd
if "%~1"=="" (
    pause
)
