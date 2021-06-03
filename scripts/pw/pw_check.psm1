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

# new method
function Expand-EncryptedArchive {
    param(
        [Parameter(Mandatory)]
        [Alias("aPath")]
        [String]$ArchivePath,
        
        [Parameter(Mandatory)]
        [Alias("oDir")]
        [String]$OutputDirectory
    )
    $key = Get-Key
    if ($key) {
        $proc = Start-Process '7z.exe' -ArgumentList @('x', '-bso0', "-o$OutputDirectory", "-p$key", $ArchivePath) -PassThru
        while(Get-Process -Name '7z' -ErrorAction SilentlyContinue) {
            Start-Sleep -Milliseconds 200
        }
        if ($proc.ExitCode -eq 0) {
            Write-Host 'Password is correct' -ForegroundColor Green
            return
        } else {
            Write-Host ("Error: Archive '{0}' cannot be properly extracted (exit code: {1})" -f $ArchivePath, $proc.ExitCode) -ForegroundColor Red
            Write-Host 'Abort installation' -ForegroundColor Red
            exit(1)
        }
    } else {
        Write-Host 'Password incorrect' -ForegroundColor Red
        Write-Host 'Abort installation' -ForegroundColor Red
        exit(1)
    }
    
}

Export-ModuleMember -Function Get-Key
Export-ModuleMember -Function Expand-EncryptedArchive