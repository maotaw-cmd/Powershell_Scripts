$clipUrl = Read-Host "Paste Twitch clip URL"

# Create downloads folder in current location
$folder = Join-Path (Get-Location) "Twitch-Clips"
New-Item -ItemType Directory -Force -Path $folder | Out-Null

# Download yt-dlp if missing
$ytdlp = Join-Path (Get-Location) "yt-dlp.exe"

if (!(Test-Path $ytdlp)) {
    Write-Host "Downloading yt-dlp..."
    Invoke-WebRequest `
        -Uri "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe" `
        -OutFile $ytdlp
}

# Download clip
& $ytdlp `
    -P $folder `
    -o "%(title)s.%(ext)s" `
    $clipUrl

Write-Host "Done. Check folder: $folder"
