# Quick demo: Flask + public tunnel
# Usage: .\start-demo.ps1
# Requires: pip install -r requirements.txt
# Ngrok: free account + authtoken from https://dashboard.ngrok.com/get-started/your-authtoken

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot
Set-Location $ProjectRoot

if (-not (Test-Path "patients.db")) {
    python -c "from models import init_db; init_db()"
}

$ngrokCmd = Get-Command ngrok -ErrorAction SilentlyContinue
if (-not $ngrokCmd) {
  $wingetNgrok = Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter "ngrok.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($wingetNgrok) { $ngrokExe = $wingetNgrok.FullName } else { throw "ngrok not found. Install: winget install Ngrok.Ngrok" }
} else {
  $ngrokExe = $ngrokCmd.Source
}

Write-Host ""
Write-Host "=== Patient Medical History Demo ===" -ForegroundColor Cyan
Write-Host "GitHub: https://github.com/karann18/patient-medical-history-app"
Write-Host ""
Write-Host "Starting Flask on http://localhost:5000 ..."
Write-Host "Starting ngrok tunnel (copy the https Forwarding URL) ..."
Write-Host "Keep this window open during your demo."
Write-Host ""

$flaskJob = Start-Job -ScriptBlock {
    Set-Location $using:ProjectRoot
    python server.py
}

Start-Sleep -Seconds 3
Start-Process -FilePath $ngrokExe -ArgumentList "http","5000" -NoNewWindow

try {
    Wait-Job $flaskJob
} finally {
    Stop-Job $flaskJob -ErrorAction SilentlyContinue
    Remove-Job $flaskJob -ErrorAction SilentlyContinue
}
