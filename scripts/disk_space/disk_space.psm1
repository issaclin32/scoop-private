#Requires -Version 3.0

function Check-Disk-Space{
    Param(
    [Parameter(
        Mandatory=$True,
        Position=0
    )]
    [String]$Path,
    [Parameter(
        Mandatory=$True,
        Position=1
    )]
    [String]$Size
    )

    # perform checks
    if (!(Test-Path $Path)) {
        Write-Host "Error: Path `"$Path`" does not exist" -ForegroundColor Red
        return $false
    }
    $volume_id = $Path.Substring(0, 2)

    $Size = $Size.ToLower()
    $unit = $Size.Substring($Size.Length-2)
    if (($unit -ne "mb") -and ($unit -ne "gb")) {
        Write-Host "Error: File size must end with 'MB' or 'GB'" -ForegroundColor Red
        return $false
    }
    $n = [float]$Size.Substring(0, $Size.Length-2)
    if ($unit -eq "mb") {
        $n /= 1024
    }
    $f = "DeviceID='{0}'" -f $volume_id
    $free_space = (Get-WmiObject win32_logicaldisk -filter $f | select-object Freespace).FreeSpace/1GB
    if ($free_space -ge $n) {
        return $true
    }
    return $false
}
Export-ModuleMember -Function Check-Disk-Space
