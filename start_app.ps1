#Requires -Version 5.1
<#
.SYNOPSIS
    一键启动 AIDataAnalysis_StarRocks 前后端服务。
.DESCRIPTION
    本脚本在数据栈（Docker）已经启动后执行，负责拉起：
      - backend/app.py          : 5000 (主应用 / Dify 代理 / 登录注册)
      - backend/starrocks_service.py : 5001 (StarRocks SQL 查询服务)
      - backend/auth_service.py : 5002 (用户鉴权服务)
      - frontend dev server     : 3000 (React + Vite)
    前置要求：
      1. Docker 数据栈已启动（Start.ps1 或 docker compose up -d）
      2. StarRocks 已就绪，且 paimon_catalog1.mall_dw 下已有 ADS/DWS 表
      3. MySQL 已就绪，ai_data_analysis 库已初始化
.NOTES
    每个服务会在独立窗口中运行，方便查看日志。关闭窗口即停止对应服务。
#>

param(
    [switch]$SkipFrontend,
    [switch]$SkipBackend,
    [switch]$SkipChecks
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$backendDir = Join-Path $projectRoot "backend"
$frontendDir = Join-Path $projectRoot "frontend"

# ============================================================
# 0. 基础依赖检查
# ============================================================
function Test-CommandExists {
    param([string]$Name)
    $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "AIDataAnalysis_StarRocks 应用启动脚本" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if (-not (Test-CommandExists "python")) {
    Write-Error "未找到 python，请先安装 Python 3.10+ 并加入 PATH。"
}
if (-not $SkipFrontend -and -not (Test-CommandExists "npm")) {
    Write-Error "未找到 npm，请先安装 Node.js 18+ 并加入 PATH。"
}

# ============================================================
# 1. 检查数据栈端口是否就绪
# ============================================================
function Test-TcpPort {
    param(
        [string]$HostName = "localhost",
        [int]$Port = 9030,
        [int]$TimeoutMs = 1000
    )
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $client.Connect($HostName, $Port)
        $client.Close()
        return $true
    }
    catch {
        return $false
    }
}

if (-not $SkipChecks) {
    Write-Host "`n[1/4] 检查数据栈服务端口..." -ForegroundColor Yellow

    $srReady = Test-TcpPort -HostName "localhost" -Port 9030
    if (-not $srReady) {
        Write-Error "StarRocks 查询端口 9030 未连通。请先运行 Start.ps1 或 `docker compose up -d` 启动数据栈。"
    }
    Write-Host "  StarRocks :9030 已连通" -ForegroundColor Green

    $mysqlReady = Test-TcpPort -HostName "localhost" -Port 3307
    if (-not $mysqlReady) {
        Write-Error "MySQL 端口 3307 未连通。请先启动 Docker 数据栈。"
    }
    Write-Host "  MySQL     :3307 已连通" -ForegroundColor Green
}

# ============================================================
# 2. 安装/检查 Python 依赖
# ============================================================
if (-not $SkipBackend) {
    Write-Host "`n[2/4] 检查 Python 依赖..." -ForegroundColor Yellow
    $reqFile = Join-Path $backendDir "requirements.txt"
    & python -m pip install -r $reqFile | Out-String | ForEach-Object { Write-Host $_ }
}

# ============================================================
# 3. 启动后端服务（独立窗口）
# ============================================================
if (-not $SkipBackend) {
    Write-Host "`n[3/4] 启动后端服务..." -ForegroundColor Yellow

    function Start-BackendService {
        param(
            [string]$Name,
            [string]$Script,
            [int]$Port
        )
        $title = "AIDataAnalysis - $Name :$Port"
        $scriptPath = Join-Path $backendDir $Script
        Write-Host "  启动 $Name -> http://localhost:$Port" -ForegroundColor Cyan
        Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd `"$backendDir`"; `$Host.UI.RawUI.WindowTitle='$title'; python `"$scriptPath`""
    }

    Start-BackendService -Name "主应用" -Script "app.py" -Port 5000
    Start-Sleep -Seconds 2
    Start-BackendService -Name "StarRocks查询服务" -Script "starrocks_service.py" -Port 5001
    Start-Sleep -Seconds 2
    Start-BackendService -Name "鉴权服务" -Script "auth_service.py" -Port 5002
}

# ============================================================
# 4. 启动前端 dev server（独立窗口）
# ============================================================
if (-not $SkipFrontend) {
    Write-Host "`n[4/4] 启动前端 dev server..." -ForegroundColor Yellow
    $nodeModules = Join-Path $frontendDir "node_modules"
    if (-not (Test-Path $nodeModules)) {
        Write-Host "  未检测到 node_modules，执行 npm install..." -ForegroundColor Yellow
        & npm install --prefix $frontendDir | Out-String | ForEach-Object { Write-Host $_ }
    }
    Write-Host "  启动 frontend -> http://localhost:3000" -ForegroundColor Cyan
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd `"$frontendDir`"; `$Host.UI.RawUI.WindowTitle='AIDataAnalysis - Frontend :3000'; npm run dev"
}

# ============================================================
# 5. 打印访问地址与后续步骤
# ============================================================
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "应用服务已尝试启动，请检查弹出的 PowerShell 窗口日志。" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "前端地址: http://localhost:3000" -ForegroundColor White
Write-Host "后端接口:" -ForegroundColor White
Write-Host "  - 主应用/登录/聊天 : http://localhost:5000" -ForegroundColor White
Write-Host "  - StarRocks 查询    : http://localhost:5001/api/starrocks/query" -ForegroundColor White
Write-Host "  - 鉴权服务          : http://localhost:5002" -ForegroundColor White
Write-Host "`n默认管理员账号: admin / 123456" -ForegroundColor White
Write-Host "`n如需接入 Dify，请：" -ForegroundColor Yellow
Write-Host "  1. 部署/启动 Dify（http://localhost/v1/workflows/run）" -ForegroundColor Yellow
Write-Host "  2. 修改 backend/app.py 中的 DIFY_API_KEY" -ForegroundColor Yellow
Write-Host "  3. 导入 dify/AI数据分析工作流.yml 并发布" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Green
