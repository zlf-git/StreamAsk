#Requires -Version 5.1
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 如果 docker 不在 PATH，自动追加本机 Docker Desktop 路径
$dockerCliPath = "C:\Users\zlf\AppData\Local\Programs\DockerDesktop\resources\bin"
if (Test-Path "$dockerCliPath\docker.exe") {
    $env:Path = "$dockerCliPath;$env:Path"
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " 启动 AIDataAnalysis_StarRocks 本地环境" -ForegroundColor Cyan
Write-Host " (Flink + Paimon + Kafka + StarRocks + MySQL)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 检查 Docker
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "[错误] 未检测到 Docker，请先安装 Docker Desktop 并启动。" -ForegroundColor Red
    exit 1
}

# 首次使用：若本地没有 flink-with-paimon 镜像，需先构建
$hasImg = docker images flink-with-paimon:1.17.2 --format "{{.Repository}}" 2>$null
if ($hasImg -notcontains "flink-with-paimon") {
    Write-Host "[提示] 本地未找到 flink-with-paimon:1.17.2 镜像，正在构建（首次需要 2-5 分钟）..." -ForegroundColor Yellow
    docker build -t flink-with-paimon:1.17.2 docker/flink
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[错误] Flink 镜像构建失败。" -ForegroundColor Red
        exit 1
    }
}

# 启动容器
docker compose up -d
if ($LASTEXITCODE -ne 0) {
    Write-Host "[错误] 容器启动失败，请检查 Docker 是否正常运行。" -ForegroundColor Red
    exit 1
}

Write-Host "`n容器已启动，等待服务就绪..." -ForegroundColor Green

# 等待 MySQL
Write-Host "等待 MySQL 就绪..."
while ($true) {
    $ok = docker exec mysql-ai-analysis mysqladmin ping -uroot -p123456 --silent 2>$null
    if ($LASTEXITCODE -eq 0) { break }
    Start-Sleep -Seconds 2
}
Write-Host "MySQL 已就绪。" -ForegroundColor Green

# 等待 StarRocks
Write-Host "等待 StarRocks 就绪..."
while ($true) {
    try {
        $resp = Invoke-WebRequest -Uri "http://localhost:8030/api/health" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        if ($resp.Content -match "OK") { break }
    } catch {}
    Start-Sleep -Seconds 3
}
Write-Host "StarRocks 已就绪。" -ForegroundColor Green

# 等待 Flink
Write-Host "等待 Flink 就绪..."
while ($true) {
    try {
        $resp = Invoke-WebRequest -Uri "http://localhost:8081/overview" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        if ($resp.StatusCode -eq 200) { break }
    } catch {}
    Start-Sleep -Seconds 3
}
Write-Host "Flink 已就绪。" -ForegroundColor Green

Write-Host "`n环境启动完成！" -ForegroundColor Green
Write-Host "`n服务地址："
Write-Host "  StarRocks 查询 :  localhost:9030  (root / 无密码)"
Write-Host "  StarRocks WebUI :  http://localhost:8030"
Write-Host "  Flink WebUI     :  http://localhost:8081"
Write-Host "  MySQL           :  localhost:3307 (root / 123456)"
Write-Host "  Kafka           :  localhost:9092"
Write-Host "`n初始化与 ETL 请自行执行：" -ForegroundColor Yellow
Write-Host "  [StarRocks] docker exec -i sr-ai-analysis mysql -P9030 -h127.0.0.1 -uroot < docker/starrocks/init.sql"
Write-Host "  [Flink+Paimon ETL] docker exec -i flink-jobmanager ./bin/sql-client.sh -f /flink-init/paimon_demo.sql"
Write-Host "`n直查 Paimon 湖仓（StarRocks 侧）："
Write-Host "  SET CATALOG paimon_catalog1; USE mall_dw;"
Write-Host "  SELECT * FROM paimon_catalog1.mall_dw.ads_trade_overview_di ORDER BY dt DESC;"
