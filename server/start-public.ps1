$ErrorActionPreference = "Stop"

$serverDir = $PSScriptRoot
$projectDir = Split-Path -Parent $serverDir
$nodeExe = "C:\Users\cycos\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe"
$cloudflaredExe = Join-Path $serverDir "tools\cloudflared.exe"
$addressFile = Join-Path $projectDir "public-address.txt"
$tunnelOut = Join-Path $env:TEMP ("best-tcg-tunnel-" + [guid]::NewGuid().ToString("N") + ".out.log")
$tunnelErr = Join-Path $env:TEMP ("best-tcg-tunnel-" + [guid]::NewGuid().ToString("N") + ".err.log")
$nodeProcess = $null
$tunnelProcess = $null
$ownsNode = $false

function Test-GameServer {
    try {
        $response = Invoke-WebRequest -Uri "http://127.0.0.1:8000" -UseBasicParsing -TimeoutSec 2
        return $response.StatusCode -eq 200
    } catch {
        return $false
    }
}

try {
    if (-not (Test-Path -LiteralPath $nodeExe)) {
        throw "Node runtime was not found. Open this project in Codex and ask it to repair the public server launcher."
    }
    if (-not (Test-Path -LiteralPath $cloudflaredExe)) {
        throw "Cloudflare Tunnel was not found. Open this project in Codex and ask it to install the public server tool."
    }
    if (-not (Test-Path -LiteralPath (Join-Path $serverDir "node_modules\ws"))) {
        throw "The WebSocket server module is missing. Open this project in Codex and ask it to install the server module."
    }

    if (-not (Test-GameServer)) {
        Write-Host "Starting the game server..."
        $nodeProcess = Start-Process -FilePath $nodeExe -ArgumentList "room_server.js" -WorkingDirectory $serverDir -WindowStyle Hidden -PassThru
        $ownsNode = $true
        for ($attempt = 0; $attempt -lt 20 -and -not (Test-GameServer); $attempt++) {
            Start-Sleep -Milliseconds 250
        }
        if (-not (Test-GameServer)) {
            throw "The local game server did not start. Port 8000 may already be in use."
        }
    } else {
        Write-Host "Using the game server already running on port 8000."
    }

    Write-Host "Creating a temporary public HTTPS address..."
    $arguments = @("tunnel", "--no-autoupdate", "--url", "http://127.0.0.1:8000")
    $tunnelProcess = Start-Process -FilePath $cloudflaredExe -ArgumentList $arguments -WindowStyle Hidden -RedirectStandardOutput $tunnelOut -RedirectStandardError $tunnelErr -PassThru

    $publicUrl = $null
    for ($attempt = 0; $attempt -lt 120 -and -not $publicUrl; $attempt++) {
        Start-Sleep -Milliseconds 500
        $text = ""
        if (Test-Path -LiteralPath $tunnelOut) { $text += Get-Content -LiteralPath $tunnelOut -Raw -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $tunnelErr) { $text += Get-Content -LiteralPath $tunnelErr -Raw -ErrorAction SilentlyContinue }
        $match = [regex]::Match($text, "https://[a-z0-9-]+\.trycloudflare\.com")
        if ($match.Success) { $publicUrl = $match.Value }
        if ($tunnelProcess.HasExited -and -not $publicUrl) {
            throw "The public tunnel stopped before creating an address.`n$text"
        }
    }
    if (-not $publicUrl) {
        throw "Timed out while creating the public address. Check the internet connection and try again."
    }

    Set-Content -LiteralPath $addressFile -Value $publicUrl -Encoding UTF8
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "PUBLIC GAME ADDRESS" -ForegroundColor Green
    Write-Host $publicUrl -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "Send this address and the six-character room code to your friend."
    Write-Host "Keep this window open. Close it to stop sharing the game."
    Write-Host "The address is also saved in public-address.txt."
    Write-Host ""

    Start-Process $publicUrl
    Wait-Process -Id $tunnelProcess.Id
} catch {
    Write-Host ""
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
} finally {
    if ($tunnelProcess -and -not $tunnelProcess.HasExited) {
        Stop-Process -Id $tunnelProcess.Id -Force -ErrorAction SilentlyContinue
    }
    if ($ownsNode -and $nodeProcess -and -not $nodeProcess.HasExited) {
        Stop-Process -Id $nodeProcess.Id -Force -ErrorAction SilentlyContinue
    }
    Remove-Item -LiteralPath $tunnelOut,$tunnelErr -Force -ErrorAction SilentlyContinue
}
