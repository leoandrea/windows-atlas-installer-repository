[CmdletBinding()]
param(
    # Space-, comma- or semicolon-separated list of Chocolatey packages.
    [string] $Packages,

    [string] $Username,

    [string] $Password
)

function Handle-LastError
{
    [CmdletBinding()]
    param(
    )

    $message = $error[0].Exception.Message
    if ($message)
    {
        Write-Host -Object "ERROR: $message" -ForegroundColor Red
    }

    # IMPORTANT NOTE: Throwing a terminating error (using $ErrorActionPreference = "Stop") still
    # returns exit code zero from the PowerShell script when using -File. The workaround is to
    # NOT use -File when calling this script and leverage the try-catch-finally block and return
    # a non-zero exit code from the catch block.
    exit -1
}

function Add-LocalAdminUser
{
    [CmdletBinding()]
    param(
        [string] $UserName,
        [string] $Password,
        [string] $Description = 'DevTestLab artifact installer',
        [switch] $Overwrite = $true
    )
$secPassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
New-LocalUser $UserName -Password $secPassword -FullName $UserName -Description "Description of this account."
Add-LocalGroupMember -Group "Administrators" -Member $UserName
Add-LocalGroupMember -Group "Users" -Member $UserName

}

function Remove-LocalAdminUser
{
    [CmdletBinding()]
    param(
        [string] $UserName
    )

    if ([ADSI]::Exists('WinNT://./' + $UserName))
    {
        $computer = [ADSI]"WinNT://$env:ComputerName"
        $computer.Delete('User', $UserName)
        try
        {
            gwmi win32_userprofile | ? { $_.LocalPath -like "*$UserName*" -and -not $_.Loaded } | % { $_.Delete() | Out-Null }
        }
        catch
        {
            # Ignore any errors, specially with locked folders/files. It will get cleaned up at a later time, when another artifact is installed.
        }
    }
}

function Get-TempPassword
{
    [CmdletBinding()]
    param(
        [int] $length = 43
    )

    $sourceData = $null
    33..126 | % { $sourceData +=,[char][byte]$_ }

    1..$length | % { $tempPassword += ($sourceData | Get-Random) }

    return $tempPassword
}

function Invoke-ChocolateyPackageInstaller
{
    [CmdletBinding()]
    param(
        [string] $UserName,
        [string] $Password,
        [string] $PackageList
    )

    $secPassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential("$env:COMPUTERNAME\$($UserName)", $secPassword)
    $command = "$PSScriptRoot\install-choco-packages.ps1 atlastestcenter"
	
    #Invoke-Command -ComputerName $env:COMPUTERNAME -Credential $credential -ScriptBlock {param($command, $arguments) Start-Process -FilePath $command -ArgumentList $arguments} -ArgumentList ($command, $arguments)

    #$s = New-PSSession -ComputerName $env:ComputerName -Credential($credential)
    #Invoke-Command -Session $s -FilePath $command -ArgumentList $PackageList

    invoke-expression $command
}

$Password = Get-TempPassword
$UserName = "tempuser"
try {
	#Add-LocalAdminUser -UserName $UserName -Password $password | Out-Null
	Invoke-ChocolateyPackageInstaller -UserName $Username -Password $Password -PackageList $Packages
}
catch
{
    Handle-LastError
}
finally
{
    #Remove-LocalAdminUser -UserName $UserName
}
