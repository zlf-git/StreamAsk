#Requires -Version 5.1
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " 鍒濆鍖?StarRocks" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 濡傛灉 docker 涓嶅湪 PATH锛岃嚜鍔ㄨ拷鍔犳湰鏈?Docker Desktop 璺緞
$dockerCli = "C:\Users\zlf\AppData\Local\Programs\DockerDesktop\resources\bin"
if (Test-Path "$dockerCli\docker.exe") {
    $env:PATH = "$dockerCli;$($env:PATH)"
}

# 澶嶅埗 SQL 鍒板鍣ㄥ唴鍐嶆墽琛岋紙Windows 涓?< 閲嶅畾鍚戜笉鍙潬锛?docker cp docker\starrocks\init.sql sr-ai-analysis:/tmp/init.sql
if ($LASTEXITCODE -ne 0) {
    Write-Host "[閿欒] 澶嶅埗 SQL 鏂囦欢鍒板鍣ㄥけ璐ャ€? -ForegroundColor Red
    exit 1
}

docker exec sr-ai-analysis mysql -P9030 -h127.0.0.1 -uroot -e "source /tmp/init.sql"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[閿欒] StarRocks 鍒濆鍖栧け璐ャ€? -ForegroundColor Red
    exit 1
}

Write-Host "`nStarRocks 鍒濆鍖栧畬鎴愩€? -ForegroundColor Green

