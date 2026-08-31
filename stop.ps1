#Requires -Version 5.1
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 如果 docker 不在 PATH，自动追加本机 Docker Desktop 路径
$dockerCliPath = "C:\Users\zlf\AppData\Local\Programs\DockerDesktop\resources\bin"
if (Test-Path "$dockerCliPath\docker.exe") {
    $env:Path = "$dockerCliPath;$env:Path"
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " 停止 AIDataAnalysis_StarRocks 本地环境" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

docker compose down

Write-Host "`n环境已停止。" -ForegroundColor Green
