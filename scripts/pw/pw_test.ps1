Import-Module ".\pw_check.psm1" -DisableNameChecking

# --- main program ---
if(Get-Key){
    Write-Host "Password is correct" -ForegroundColor Green
} else {
    Write-Host "Password incorrect -- abort installation" -ForegroundColor Red
}