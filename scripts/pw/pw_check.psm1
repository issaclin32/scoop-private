#Requires -Version 3.0
function Encrypt-String{
Param(
    
    [Parameter(
        Mandatory=$True,
        Position=0,
        ValueFromPipeLine=$true
    )]
    [Alias("String")]
    [String]$PlainTextString,
    
    [Parameter(
        Mandatory=$True,
        Position=1
    )]
    [Alias("Key")]
    [byte[]]$EncryptionKey
)
    Try{
        $secureString = Convertto-SecureString $PlainTextString -AsPlainText -Force
        $EncryptedString = ConvertFrom-SecureString -SecureString $secureString -Key $EncryptionKey

        return $EncryptedString
    }
    Catch{
        #Throw $_
        return ""
    }

}

function Decrypt-String{
    Param(
        [Parameter(
            Mandatory=$True,
            Position=0,
            ValueFromPipeLine=$true
        )]
        [Alias("String")]
        [String]$EncryptedString,
    
        [Parameter(
            Mandatory=$True,
            Position=1
        )]
        [Alias("Key")]
        [byte[]]$EncryptionKey
    )
        $ErrorActionPreference = 'SilentlyContinue'
        Try{
            $SecureString = ConvertTo-SecureString $EncryptedString -Key $EncryptionKey
            $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
            [string]$String = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    
            return $String
        }
        Catch{
            #Throw $_
            return ""
        }
    
    }

function Validate-Key {
    param(
        [Parameter(Mandatory)][String]$Key,
        [Parameter(Mandatory)][String]$TestString,
        [Parameter(Mandatory)][String]$EncyptedTestString
    )
    $ErrorActionPreference = 'SilentlyContinue'
    if ($Key.length -gt 32) { $Key = $Key.Substring(0,32) }
    elseif ($Key.length -lt 32){ $Key += "_"*(32-$Key.length) }
    $k = [System.Text.Encoding]::UTF8.GetBytes($Key)

    $decoded_test_string = Decrypt-String -String $EncyptedTestString -Key $k
    if ($decoded_test_string -ne $TestString) {
        return $False
    } else {
        return $True
    }
}

function Load-Or-Input-Key {
    param(
        [Parameter(Mandatory)][String]$KeyFilePath,
        [Parameter(Mandatory)][String]$TestString,
        [Parameter(Mandatory)][String]$EncryptedTestString
    )

    if (Test-Path $KeyFilePath) {
        $key = Get-Content -Path $KeyFilePath -Encoding ascii
        if (Validate-Key $key $TestString $EncryptedTestString) { # key is correct
            return $True
        } else {  
            Write-Host ("Password stored in '{0}' is incorrect. Please type the password again." -f $KeyFilePath) -ForegroundColor Red
        }
    }

    # input new key
    $key = Read-Host "Password"
    if (Validate-Key $key $TestString $EncryptedTestString) {
        Set-Content -Path $KeyFilePath -Encoding ascii -Value $key
        return $True
    } else {
        return $False
    }
}

# quick patch for applying on Scoop manifests
function Get-Key {
    $key_file_path = ($PSScriptRoot+"\password.cfg")
    $test_string = Get-Content -Path ($PSScriptRoot+"\test_string.cfg") -Encoding ascii
    $encrypted_test_string = Get-Content -Path ($PSScriptRoot+"\encrypted_test_string.cfg") -Encoding ascii
    if(Load-Or-Input-Key $key_file_path $test_string $encrypted_test_string){
        $key = Get-Content -Path $key_file_path -Encoding ascii
        return $key
    } else {
        return ""
    }
}

function Expand-EncryptedArchive {
    param(
        [Parameter(Mandatory)]
        [Alias("aPath")]
        [String]$ArchivePath,
        
        [Parameter(Mandatory)]
        [Alias("oDir")]
        [String]$OutputDirectory,

        [switch]$ExitIfError = $false,

        [switch]$Removal = $false
    )

    $key = Get-Key
    if(!(key)) {
        Write-Host 'Password incorrect' -ForegroundColor Red
        if ($ExitOnError) {
            Write-Host 'Abort installation' -ForegroundColor Red
            exit(1)
        }
        else {return $False}
    }

    $proc = Start-Process '7z.exe' -ArgumentList @('x', '-aoa', "`"-o$OutputDirectory`"", "-p$key", "`"$ArchivePath`"") -PassThru -Wait

    if ($proc.ExitCode -ne 0) {
        Write-Host ("Error: Archive '{0}' cannot be properly extracted (exit code: {1})" -f $ArchivePath, $proc.ExitCode) -ForegroundColor Red
        if ($ExitOnError) {
            Write-Host 'Abort installation' -ForegroundColor Red
            exit(1)
        }
        else {return $False}
    }

    Write-Host 'Password is correct' -ForegroundColor Green
    if ($Removal) {Remove-Item $ArchivePath}

    if ($ExitIfError) {return}  # This avoids the use of '... | Out-Null'
    else {return $True} # This allows us to check if the archive is properly extracted by 'if (Expand-EncryptedArchive ...)'
}

Export-ModuleMember -Function Get-Key
Export-ModuleMember -Function Expand-EncryptedArchive
