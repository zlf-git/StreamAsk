@echo off
chcp 65001 >nul

REM Auto-add Docker Desktop to PATH if not found
set "DOCKER_CLI_PATH=C:\Users\zlf\AppData\Local\Programs\DockerDesktop\resources\bin"
if exist "%DOCKER_CLI_PATH%\docker.exe" set "PATH=%DOCKER_CLI_PATH%;%PATH%"

echo ========================================
echo  Start AIDataAnalysis_StarRocks Local Env
echo  (Flink + Paimon + Kafka + StarRocks + MySQL)
echo ========================================
echo.

REM Check Docker
docker --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker not found. Please install Docker Desktop.
    pause
    exit /b 1
)

REM Build local Flink image if missing
docker images flink-with-paimon:1.17.2 --format "{{.Repository}}" | findstr "flink-with-paimon" >nul 2>&1
if errorlevel 1 (
    echo [INFO] Building flink-with-paimon:1.17.2 image (first time only, 2-5 min)...
    docker build -t flink-with-paimon:1.17.2 docker/flink
    if errorlevel 1 (
        echo [ERROR] Flink image build failed.
        pause
        exit /b 1
    )
)

REM Start containers
docker compose up -d
if errorlevel 1 (
    echo [ERROR] Failed to start containers.
    pause
    exit /b 1
)

echo.
echo Containers started, waiting for services...
echo.

REM Wait MySQL
echo Waiting for MySQL...
:wait_mysql
docker exec mysql-ai-analysis mysqladmin ping -uroot -p123456 --silent >nul 2>&1
if errorlevel 1 (
    timeout /t 2 /nobreak >nul
    goto wait_mysql
)
echo MySQL ready.

REM Wait StarRocks
echo Waiting for StarRocks...
:wait_sr
curl -s http://localhost:8030/api/health | findstr "OK" >nul 2>&1
if errorlevel 1 (
    timeout /t 3 /nobreak >nul
    goto wait_sr
)
echo StarRocks ready.

REM Wait Flink
echo Waiting for Flink...
:wait_fl
curl -s -o nul http://localhost:8081/overview
if errorlevel 1 (
    timeout /t 3 /nobreak >nul
    goto wait_fl
)
echo Flink ready.

echo.
echo Environment started!
echo.
echo Services:
echo   StarRocks SQL   :  localhost:9030  (root / no password)
echo   StarRocks WebUI :  http://localhost:8030
echo   Flink WebUI     :  http://localhost:8081
echo   MySQL           :  localhost:3307 (root / 123456)
echo   Kafka           :  localhost:9092
echo.
echo Next steps (run manually):
echo   [StarRocks init] init_starrocks.bat  or  init_starrocks.ps1
echo   [Flink+Paimon]   docker exec -i flink-jobmanager ./bin/sql-client.sh -f /flink-init/paimon_demo.sql
echo.
echo Query Paimon lakehouse from StarRocks:
echo   SET CATALOG paimon_catalog1; USE mall_dw;
echo   SELECT * FROM paimon_catalog1.mall_dw.ads_trade_overview_di ORDER BY dt DESC;
echo.
pause
