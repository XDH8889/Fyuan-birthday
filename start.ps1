$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

# 清理旧进程（精确匹配本项目启动的 node server.js 与 cloudflared tunnel）
Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
  Where-Object {
    ($_.Name -eq 'node.exe' -and $_.CommandLine -like '*server.js*') -or
    ($_.Name -eq 'cloudflared.exe' -and $_.CommandLine -like '*tunnel*')
  } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -Confirm:$false -ErrorAction SilentlyContinue }

$tunnelOut = Join-Path $env:TEMP 'birthday-tunnel-out.log'
$tunnelErr = Join-Path $env:TEMP 'birthday-tunnel-err.log'
Remove-Item $tunnelOut, $tunnelErr -Force -ErrorAction SilentlyContinue

# 1. 启动静态服务器
Start-Process -FilePath 'node' -ArgumentList 'server.js' -WindowStyle Hidden | Out-Null
Start-Sleep -Seconds 1

$serverOk = $false
for ($i = 0; $i -lt 10; $i++) {
  Start-Sleep -Seconds 1
  try {
    $null = Invoke-WebRequest -Uri 'http://localhost:8000/' -UseBasicParsing -TimeoutSec 3
    $serverOk = $true; break
  } catch { }
}
if (-not $serverOk) {
  Write-Host '本地服务器启动失败，请检查 node 是否已安装。' -ForegroundColor Red
  exit 1
}
Write-Host '本地服务器已启动: http://localhost:8000/' -ForegroundColor Green

# 2. 启动 HTTPS 隧道
$cloudflared = Join-Path $root 'cloudflared.exe'
if (-not (Test-Path $cloudflared)) {
  Write-Host '未找到 cloudflared.exe，将使用局域网地址生成二维码（手机麦克风不可用，只能点击吹灭）。' -ForegroundColor Yellow
  node genqr.js
  Start-Process (Join-Path $root '二维码.png')
  exit 0
}

Start-Process -FilePath $cloudflared -ArgumentList 'tunnel', '--url', 'http://localhost:8000' `
  -RedirectStandardOutput $tunnelOut -RedirectStandardError $tunnelErr -WindowStyle Hidden | Out-Null

# 3. 等待隧道 URL（最多 40 秒）
$url = $null
for ($i = 0; $i -lt 40; $i++) {
  Start-Sleep -Seconds 1
  $match = (Get-Content $tunnelOut, $tunnelErr -ErrorAction SilentlyContinue) |
    Select-String -Pattern 'https://[a-z0-9-]+\.trycloudflare\.com' | Select-Object -First 1
  if ($match) { $url = $match.Matches[0].Value; break }
}

if (-not $url) {
  Write-Host '隧道启动超时，将使用局域网地址生成二维码（手机麦克风不可用，只能点击吹灭）。' -ForegroundColor Yellow
  node genqr.js
  Start-Process (Join-Path $root '二维码.png')
  exit 0
}

# 4. 关闭正在查看旧二维码的图片查看器，避免文件占用
Get-Process Photos -ErrorAction SilentlyContinue | Stop-Process -Force -Confirm:$false -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500

# 5. 生成并打开二维码
node genqr.js $url
Start-Process (Join-Path $root '二维码.png')
Write-Host '全部就绪！手机扫码即可（支持麦克风吹气）。' -ForegroundColor Green
Write-Host "HTTPS 地址: $url" -ForegroundColor Cyan
Write-Host '注意：隧道地址是一次性的，每次运行本脚本都会变化。' -ForegroundColor DarkGray
