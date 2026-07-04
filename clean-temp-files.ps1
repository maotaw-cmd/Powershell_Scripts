Write-Host "Cleaning temporary files..." -ForegroundColor Cyan
Write-Host ""

$folders = @(
    $env:TEMP,
    "$env:SystemRoot\Temp"
)

$daysOld = 1
$limit = (Get-Date).AddDays(-$daysOld)

$deletedFiles = 0
$deletedFolders = 0
$totalBytes = 0

foreach ($folder in $folders) {

    if (!(Test-Path $folder)) {
        continue
    }

    Write-Host "Checking: $folder" -ForegroundColor Yellow

    # Delete old files first
    $files = Get-ChildItem -Path $folder -Recurse -Force -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $limit }

    foreach ($file in $files) {
        try {
            $size = $file.Length

            Remove-Item -Path $file.FullName -Force -ErrorAction Stop

            $deletedFiles++
            $totalBytes += $size
        }
        catch {
            # File is probably in use, skip it
        }
    }

    # Remove empty old folders after files are deleted
    $directories = Get-ChildItem -Path $folder -Recurse -Force -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $limit } |
        Sort-Object FullName -Descending

    foreach ($dir in $directories) {
        try {
            Remove-Item -Path $dir.FullName -Force -ErrorAction Stop
            $deletedFolders++
        }
        catch {
            # Folder is probably not empty or in use, skip it
        }
    }
}

$kbSaved = [math]::Round($totalBytes / 1KB, 2)
$mbSaved = [math]::Round($totalBytes / 1MB, 2)
$gbSaved = [math]::Round($totalBytes / 1GB, 2)

Write-Host ""
Write-Host "Cleanup finished!" -ForegroundColor Green
Write-Host "Files deleted:   $deletedFiles"
Write-Host "Folders deleted: $deletedFolders"
Write-Host "Space saved:     $kbSaved KB"
Write-Host "Space saved:     $mbSaved MB"
Write-Host "Space saved:     $gbSaved GB"
Write-Host ""
Write-Host "Some files may be skipped because Windows is using them." -ForegroundColor DarkYellow
