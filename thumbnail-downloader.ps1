Write-Host "YouTube Thumbnail Downloader"
$url = Read-Host "Paste YouTube URL"

if ($url -match "v=([^&]+)") {
    $videoId = $matches[1]
}
elseif ($url -match "youtu\.be/([^?&]+)") {
    $videoId = $matches[1]
}
elseif ($url -match "shorts/([^?&]+)") {
    $videoId = $matches[1]
}
else {
    Write-Host "Could not find YouTube video ID."
    pause
    exit
}

$thumbnailUrl = "https://img.youtube.com/vi/$videoId/maxresdefault.jpg"

$saveFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
$outputFile = Join-Path $saveFolder "youtube_thumbnail_$videoId.jpg"

Invoke-WebRequest -Uri $thumbnailUrl -OutFile $outputFile

Write-Host ""
Write-Host "Downloaded successfully!"
Write-Host "Saved here:"
Write-Host $outputFile

pause
