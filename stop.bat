@echo off
chcp 65001 >nul

REM Auto-add Docker Desktop to PATH if not found
set "DOCKER_CLI_PATH=C:\Users\zlf\AppData\Local\Programs\DockerDesktop\resources\bin"
if exist "%DOCKER_CLI_PATH%\docker.exe" set "PATH=%DOCKER_CLI_PATH%;%PATH%"

echo ========================================
echo  Stop AIDataAnalysis_StarRocks Local Env
echo ========================================

docker compose down

echo.
echo Environment stopped.
pause
