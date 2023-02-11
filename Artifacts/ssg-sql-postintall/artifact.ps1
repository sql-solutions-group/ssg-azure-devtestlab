[CmdletBinding()]
param
(
    [Parameter(Mandatory = $true)]
    [string] $ServiceAccountUsername,

    [Parameter(Mandatory = $true)]
    [string] $ServiceAccountPassword
)

###################################################################################################
#
# PowerShell configurations
#

# NOTE: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.
#       This is necessary to ensure we capture errors inside the try-catch-finally block.
$ErrorActionPreference = "Stop"

# Ensure we set the working directory to that of the script.
Push-Location $PSScriptRoot

###################################################################################################
#
# Handle all errors in this script.
#

trap {
    # NOTE: This trap will handle all errors. There should be no need to use a catch below in this
    #       script, unless you want to ignore a specific error.
    $message = $error[0].Exception.Message
    if ($message) {
        Write-Host -Object "ERROR: $message" -ForegroundColor Red
    }

    # IMPORTANT NOTE: Throwing a terminating error (using $ErrorActionPreference = "Stop") still
    # returns exit code zero from the PowerShell script when using -File. The workaround is to
    # NOT use -File when calling this script and leverage the try-catch-finally block and return
    # a non-zero exit code from the catch block.
    Write-Host 'Artifact failed to apply.'
    exit -1
}

###################################################################################################
#
# Functions used in this script.
#



###################################################################################################
#
# Main execution block.
#

try {
    if ($PSVersionTable.PSVersion.Major -lt 3) {
        throw "The current version of PowerShell is $($PSVersionTable.PSVersion.Major). Prior to running this artifact, ensure you have PowerShell 3 or higher installed."
    }

    Import-Module dbatools

    #permissions on temp drive
    $acl = Get-Acl -Path T:\
    $new = New-Object System.Security.AccessControl.FileSystemAccessRule("$ServiceAccountUserName", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.AddAccessRule($new)
    Set-Acl -Path T:\ -AclObject $acl

    #service account
    Write-Host "Changing service account for SQL Engine, Agent, SSIS to `'$ServiceAccountUsername`'"
    $securePass = ConvertTo-SecureString $ServiceAccountPassword -AsPlainText -Force
    [PSCredential]$cred = New-Object System.Management.Automation.PSCredential ($ServiceAccountUsername, $securePass)
    Get-DbaService -SqlInstance localhost -Type Agent, Engine, SSIS | Update-DbaServiceAccount -ServiceCredential $cred

    #user rights
    Write-Host "Setting UserRight - Lock Pages In Memory for '$ServiceAccountUsername'"
    .\Set-UserRights -AddRight -UserName $ServiceAccountUsername -UserRight SeLockMemoryPrivilege
    Write-Host "Setting UserRight - Perform Volume Maintenance Tasks for '$ServiceAccountUsername'"
    .\Set-UserRights -AddRight -UserName $ServiceAccountUsername -UserRight SeManageVolumePrivilege

    Start-DbaService -ComputerName localhost -Type Engine, Agent, SSIS

    #parallelism
    Write-Host "Setting MAXDOP"
    Set-DbaMaxDop -SqlInstance localhost

    #max memory
    Write-Host "Setting MaxMemory"
    Set-DbaMaxMemory -SqlInstance localhost

    Restart-DbaService -ComputerName  localhost -Type Agent, Engine, SSIS

    Write-Host 'Artifact applied successfully.'
}
finally {
    Pop-Location
}
