# Quick demo: Flask + public tunnel (cloudflared or ngrok)
# Usage:
#   .\start-demo.ps1                    # local tunnel (random trycloudflare URL)
#   .\start-demo.ps1 -Tunnel ngrok    # ngrok; set $env:NGROK_DOMAIN for a stable name
#
# Permanent project-named URL (recommended for WhatsApp):
#   https://patient-medical-history.onrender.com
#   Deploy once: Render Dashboard → New → Blueprint → this repo (see README).

param(
    [ValidateSet("cloudflared", "ngrok")]
    [string]$Tunnel = "cloudflared"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot
Set-Location $ProjectRoot

$GitHubUrl = "https://github.com/karann18/patient-medical-history-app"
$RenderDemoUrl = "https://patient-medical-history.onrender.com"

function Get-FreePort {
    param([int[]]$Candidates = @(5000, 5001))
    foreach ($p in $Candidates) {
        $inUse = Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue
        if (-not $inUse) { return $p }
    }
    throw "Ports 5000 and 5001 are in use. Stop other Flask instances or set `$env:PORT."
}

function Write-ShareArtifacts {
    param(
        [string]$DemoUrl,
        [string]$Note
    )
    $lines = @(
        "Patient Medical History — Live Demo (Agenix AI internship project)",
        "",
        "Code:  $GitHubUrl",
        "Demo:  $DemoUrl",
        "",
        $Note
    )
    $text = $lines -join "`n"
    $text | Set-Content -Path (Join-Path $ProjectRoot "share-message.txt") -Encoding utf8NoBOM
    $text | Set-Content -Path (Join-Path $ProjectRoot "live-demo-url.txt") -Encoding utf8NoBOM
    Write-Host ""
    Write-Host $text -ForegroundColor Green
    Write-Host ""
    Write-Host "Copied to share-message.txt (WhatsApp-ready)." -ForegroundColor DarkGray
}

if (-not (Test-Path "patients.db")) {
    python -c "from models import init_db; init_db()"
}

$port = Get-FreePort

Write-Host ""
Write-Host "=== Patient Medical History Demo ===" -ForegroundColor Cyan
Write-Host "GitHub:  $GitHubUrl"
Write-Host "Render:  $RenderDemoUrl  (stable name — deploy once via README)"
Write-Host "Local:   http://localhost:$port"
Write-Host ""
Write-Host "Starting Flask on port $port..."
Write-Host "Starting $Tunnel tunnel — public URL appears below."
Write-Host "Keep this window open during your demo."
Write-Host ""

$flaskJob = Start-Job -ScriptBlock {
    Set-Location $using:ProjectRoot
    $env:PORT = $using:port
    python server.py
}

Start-Sleep -Seconds 3

try {
    if ($Tunnel -eq "ngrok") {
        $ngrokCmd = Get-Command ngrok -ErrorAction SilentlyContinue
        if (-not $ngrokCmd) {
            $wingetNgrok = Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter "ngrok.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $wingetNgrok) { throw "ngrok not found. Install: winget install Ngrok.Ngrok" }
            $tunnelExe = $wingetNgrok.FullName
        } else {
            $tunnelExe = $ngrokCmd.Source
        }
        $domain = $env:NGROK_DOMAIN
        if ($domain) {
            Write-Host "Using ngrok domain: $domain" -ForegroundColor Yellow
            & $tunnelExe http $port --domain=$domain
        } else {
            Write-Host "Tip: claim a free static domain at https://dashboard.ngrok.com/domains" -ForegroundColor DarkYellow
            Write-Host "     then: `$env:NGROK_DOMAIN = 'your-name.ngrok-free.app'" -ForegroundColor DarkYellow
            & $tunnelExe http $port
        }
    } else {
        $cf = "${env:ProgramFiles(x86)}\cloudflared\cloudflared.exe"
        if (-not (Test-Path $cf)) { $cf = (Get-Command cloudflared -ErrorAction SilentlyContinue).Source }
        if (-not $cf) { throw "cloudflared not found. Install: winget install Cloudflare.cloudflared" }

        $logOut = Join-Path $ProjectRoot "cloudflared-out.log"
        $logErr = Join-Path $ProjectRoot "cloudflared-err.log"
        $proc = Start-Process -FilePath $cf -ArgumentList "tunnel", "--url", "http://127.0.0.1:$port" -RedirectStandardOutput $logOut -RedirectStandardError $logErr -PassThru -NoNewWindow

        $publicUrl = $null
        for ($i = 0; $i -lt 30; $i++) {
            Start-Sleep -Seconds 1
            $blob = ""
            if (Test-Path $logErr) { $blob += Get-Content $logErr -Raw -ErrorAction SilentlyContinue }
            if (Test-Path $logOut) { $blob += Get-Content $logOut -Raw -ErrorAction SilentlyContinue }
            if ($blob -match "(https://[a-z0-9-]+\.trycloudflare\.com)") {
                $publicUrl = $Matches[1]
                break
            }
        }

        if ($publicUrl) {
            Write-ShareArtifacts -DemoUrl $publicUrl -Note "Local tunnel (URL changes each run). For a stable project link, use: $RenderDemoUrl"
        } else {
            Write-Host "Tunnel started; read https URL from cloudflared-err.log" -ForegroundColor Yellow
        }

        Wait-Process -Id $proc.Id
    }
} finally {
    Stop-Job $flaskJob -ErrorAction SilentlyContinue
    Remove-Job $flaskJob -ErrorAction SilentlyContinue
}
