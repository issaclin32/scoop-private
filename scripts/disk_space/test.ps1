Import-Module ".\disk_space.psm1" -DisableNameChecking

Write-Host $(Check-Disk-Space "D:\scoop" "2GB") -ForegroundColor Yellow
Write-Host $(Check-Disk-Space "D:\scoop" "2000GB") -ForegroundColor Yellow
