$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Clear-Host
Write-Host "================================" -ForegroundColor Cyan
Write-Host "     YouTube MP3 Downloader" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Folder containing this PowerShell script
$folder = Split-Path -Parent $MyInvocation.MyCommand.Path

if ([string]::IsNullOrWhiteSpace($folder)) {
    $folder = (Get-Location).Path
}

$ytDlp      = Join-Path $folder "yt-dlp.exe"
$ffmpeg     = Join-Path $folder "ffmpeg.exe"
$ffprobe    = Join-Path $folder "ffprobe.exe"
$deno       = Join-Path $folder "deno.exe"

$downloadFolder = Join-Path $folder "Downloads"

# ------------------------------------------------------------
# Create download folder
# ------------------------------------------------------------

if (-not (Test-Path $downloadFolder)) {
    New-Item -ItemType Directory -Path $downloadFolder | Out-Null
}

# ------------------------------------------------------------
# Download yt-dlp
# ------------------------------------------------------------

if (-not (Test-Path $ytDlp)) {
    Write-Host "Downloading yt-dlp..." -ForegroundColor Yellow

    Invoke-WebRequest `
        -Uri "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe" `
        -OutFile $ytDlp `
        -UseBasicParsing

    Write-Host "yt-dlp downloaded." -ForegroundColor Green
}

# Try updating yt-dlp
Write-Host "Checking yt-dlp updates..." -ForegroundColor DarkGray

try {
    & $ytDlp --update-to nightly
}
catch {
    Write-Host "Could not update yt-dlp, continuing..." -ForegroundColor Yellow
}

# ------------------------------------------------------------
# Download Deno JavaScript runtime
# ------------------------------------------------------------

if (-not (Test-Path $deno)) {
    Write-Host ""
    Write-Host "Downloading Deno JavaScript runtime..." -ForegroundColor Yellow

    $denoZip  = Join-Path $folder "deno.zip"
    $denoTemp = Join-Path $folder "deno_temp"

    if (Test-Path $denoTemp) {
        Remove-Item $denoTemp -Recurse -Force
    }

    Invoke-WebRequest `
        -Uri "https://github.com/denoland/deno/releases/latest/download/deno-x86_64-pc-windows-msvc.zip" `
        -OutFile $denoZip `
        -UseBasicParsing

    Expand-Archive `
        -Path $denoZip `
        -DestinationPath $denoTemp `
        -Force

    $denoFound = Get-ChildItem `
        -Path $denoTemp `
        -Filter "deno.exe" `
        -Recurse |
        Select-Object -First 1

    if (-not $denoFound) {
        throw "deno.exe was not found inside the downloaded ZIP."
    }

    Copy-Item $denoFound.FullName $deno -Force

    Remove-Item $denoZip -Force
    Remove-Item $denoTemp -Recurse -Force

    Write-Host "Deno downloaded." -ForegroundColor Green
}

# ------------------------------------------------------------
# Download FFmpeg
# ------------------------------------------------------------

if (-not (Test-Path $ffmpeg)) {
    Write-Host ""
    Write-Host "Downloading FFmpeg..." -ForegroundColor Yellow

    $ffmpegZip  = Join-Path $folder "ffmpeg.zip"
    $ffmpegTemp = Join-Path $folder "ffmpeg_temp"

    if (Test-Path $ffmpegTemp) {
        Remove-Item $ffmpegTemp -Recurse -Force
    }

    Invoke-WebRequest `
        -Uri "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip" `
        -OutFile $ffmpegZip `
        -UseBasicParsing

    Expand-Archive `
        -Path $ffmpegZip `
        -DestinationPath $ffmpegTemp `
        -Force

    $ffmpegFound = Get-ChildItem `
        -Path $ffmpegTemp `
        -Filter "ffmpeg.exe" `
        -Recurse |
        Select-Object -First 1

    $ffprobeFound = Get-ChildItem `
        -Path $ffmpegTemp `
        -Filter "ffprobe.exe" `
        -Recurse |
        Select-Object -First 1

    if (-not $ffmpegFound) {
        throw "ffmpeg.exe was not found."
    }

    Copy-Item $ffmpegFound.FullName $ffmpeg -Force

    if ($ffprobeFound) {
        Copy-Item $ffprobeFound.FullName $ffprobe -Force
    }

    Remove-Item $ffmpegZip -Force
    Remove-Item $ffmpegTemp -Recurse -Force

    Write-Host "FFmpeg downloaded." -ForegroundColor Green
}

# ------------------------------------------------------------
# Ask for URL
# ------------------------------------------------------------

Write-Host ""
$url = Read-Host "Paste one YouTube video URL"

if ([string]::IsNullOrWhiteSpace($url)) {
    Write-Host "No URL entered." -ForegroundColor Red
    Pause
    exit
}

# Remove playlist information from YouTube URLs
try {
    $uri = [System.Uri]$url

    if ($uri.Host -match "youtube\.com" -and $url -match "[?&]v=([^&]+)") {
        $videoId = $matches[1]
        $url = "https://www.youtube.com/watch?v=$videoId"
    }
}
catch {
    Write-Host "The URL could not be cleaned, using it as entered." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Downloading one video as MP3..." -ForegroundColor Green
Write-Host ""

# ------------------------------------------------------------
# Download and convert
# ------------------------------------------------------------

& $ytDlp `
    --no-playlist `
    --js-runtimes "deno:$deno" `
    --remote-components "ejs:npm" `
    --ffmpeg-location $folder `
    --extract-audio `
    --audio-format mp3 `
    --audio-quality 0 `
    --embed-thumbnail `
    --embed-metadata `
    --windows-filenames `
    --retries 10 `
    --fragment-retries 10 `
    -o "$downloadFolder\%(title)s.%(ext)s" `
    $url

# ------------------------------------------------------------
# Result
# ------------------------------------------------------------

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "MP3 downloaded successfully!" -ForegroundColor Green
    Write-Host "Saved in:" -ForegroundColor Cyan
    Write-Host $downloadFolder -ForegroundColor White

    Start-Process explorer.exe $downloadFolder
}
else {
    Write-Host ""
    Write-Host "Download failed." -ForegroundColor Red
    Write-Host ""
    Write-Host "Open the video in your browser first and try again." -ForegroundColor Yellow
}

Write-Host ""
Pause
