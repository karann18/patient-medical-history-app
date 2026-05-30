# Quick demo: Flask + public tunnel (cloudflared or ngrok)
# Usage: .\start-demo.ps1
# Requires: pip install -r requirements.txt

param(
    [ValidateSet("cloudflared", "ngrok")]
    [string]$Tunnel = "cloudflared"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot
Set-Location $ProjectRoot

if (-not (Test-Path "patients.db")) {
    python -c "from models import init_db; init_db()"
}

Write-Host ""
Write-Host "=== Patient Medical History Demo ===" -ForegroundColor Cyan
Write-Host "GitHub: https://github.com/karann18/patient-medical-history-app"
Write-Host "Local:  http://localhost:5000"
Write-Host ""
Write-Host "Starting Flask (port 5000)..."
Write-Host "Starting $Tunnel tunnel — copy the public https URL from its output."
Write-Host "Keep this window open during your demo."
Write-Host ""

$flaskJob = Start-Job -ScriptBlock {
    Set-Location $using:ProjectRoot
    python server.py
}

Start-Sleep -Seconds 3

if ($Tunnel -eq "ngrok") {
    $ngrokCmd = Get-Command ngrok -ErrorAction SilentlyContinue
    if (-not $ngrokCmd) {
        $wingetNgrok = Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter "ngrok.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $wingetNgrok) { throw "ngrok not found. Install: winget install Ngrok.Ngrok" }
        $tunnelExe = $wingetNgrok.FullName
    } else {
        $tunnelExe = $ngrokCmd.Source
    }
    & $tunnelExe http 5000
} else {
    $cf = "${env:ProgramFiles(x86)}\cloudflared\cloudflared.exe"
    if (-not (Test-Path $cf)) { $cf = (Get-Command cloudflared -ErrorAction SilentlyContinue).Source }
    if (-not $cf) { throw "cloudflared not found. Install: winget install Cloudflare.cloudflared" }
    & $cf tunnel --url http://127.0.0.1:5000
}

try {
    Wait-Job $flaskJob
} finally {
    Stop-Job $flaskJob -ErrorAction SilentlyContinue
    Remove-Job $flaskJob -ErrorAction SilentlyContinue
}
