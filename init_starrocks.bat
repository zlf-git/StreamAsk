@echo off
chcp 65001 >nul

REM Auto-add Docker Desktop to PATH if not found
set "DOCKER_CLI_PATH=C:\Users\zlf\AppData\Local\Programs\DockerDesktop\resources\bin"
if exist "%DOCKER_CLI_PATH%\docker.exe" set "PATH=%DOCKER_CLI_PATH%;%PATH%"

echo ========================================
echo  Initialize StarRocks
echo ========================================

REM Copy SQL into container first (Windows CMD redirect is unreliable)
docker cp docker\starrocks\init.sql sr-ai-analysis:/tmp/init.sql
if errorlevel 1 (
    echo [ERROR] Failed to copy init.sql into container.
    pause
    exit /b 1
)

docker exec sr-ai-analysis mysql -P9030 -h127.0.0.1 -uroot -e "source /tmp/init.sql"
if errorlevel 1 (
    echo [ERROR] StarRocks init failed.
    pause
    exit /b 1
)

echo.
echo StarRocks initialized successfully.
pause
