@echo off
chcp 65001 >nul
title AIDataAnalysis_StarRocks 应用启动

echo ========================================
echo AIDataAnalysis_StarRocks 应用启动脚本
echo ========================================
echo.

REM 检查 python
python --version >nul 2>&1
if errorlevel 1 (
    echo [错误] 未找到 python，请先安装 Python 3.10+ 并加入 PATH。
    pause
    exit /b 1
)

REM 检查 npm
npm --version >nul 2>&1
if errorlevel 1 (
    echo [错误] 未找到 npm，请先安装 Node.js 18+ 并加入 PATH。
    pause
    exit /b 1
)

REM 进入项目目录
set "PROJECT_ROOT=%~dp0"
cd /d "%PROJECT_ROOT%"

REM 检查端口（简单超时检测）
echo [1/4] 检查数据栈端口...
python -c "import socket; s=socket.socket(); s.settimeout(1); s.connect(('localhost',9030)); s.close()" >nul 2>&1
if errorlevel 1 (
    echo [错误] StarRocks 端口 9030 未连通，请先启动 Docker 数据栈。
    pause
    exit /b 1
)
echo   StarRocks :9030 已连通

python -c "import socket; s=socket.socket(); s.settimeout(1); s.connect(('localhost',3307)); s.close()" >nul 2>&1
if errorlevel 1 (
    echo [错误] MySQL 端口 3307 未连通，请先启动 Docker 数据栈。
    pause
    exit /b 1
)
echo   MySQL     :3307 已连通

REM 安装 Python 依赖
echo.
echo [2/4] 检查 Python 依赖...
python -m pip install -r backend\requirements.txt

REM 启动后端服务
echo.
echo [3/4] 启动后端服务...
start "AIDataAnalysis - 主应用 :5000" cmd /k "cd /d %PROJECT_ROOT%backend && python app.py"
timeout /t 2 /nobreak >nul
start "AIDataAnalysis - StarRocks查询 :5001" cmd /k "cd /d %PROJECT_ROOT%backend && python starrocks_service.py"
timeout /t 2 /nobreak >nul
start "AIDataAnalysis - 鉴权服务 :5002" cmd /k "cd /d %PROJECT_ROOT%backend && python auth_service.py"
timeout /t 2 /nobreak >nul

REM 启动前端
echo.
echo [4/4] 启动前端 dev server...
if not exist "frontend\node_modules" (
    echo   未检测到 node_modules，执行 npm install...
    cd /d "%PROJECT_ROOT%frontend"
    call npm install
    cd /d "%PROJECT_ROOT%"
)
start "AIDataAnalysis - Frontend :3000" cmd /k "cd /d %PROJECT_ROOT%frontend && npm run dev"

echo.
echo ========================================
echo 应用服务已尝试启动，请检查弹出的命令行窗口日志。
echo ========================================
echo 前端地址: http://localhost:3000
echo 后端接口:
echo   - 主应用/登录/聊天 : http://localhost:5000
echo   - StarRocks 查询    : http://localhost:5001/api/starrocks/query
echo   - 鉴权服务          : http://localhost:5002
echo.
echo 默认管理员账号: admin / 123456
echo.
echo 如需接入 Dify，请：
echo   1. 部署/启动 Dify（http://localhost/v1/workflows/run）
echo   2. 修改 backend/app.py 中的 DIFY_API_KEY
echo   3. 导入 dify/AI数据分析工作流.yml 并发布
echo ========================================
pause
