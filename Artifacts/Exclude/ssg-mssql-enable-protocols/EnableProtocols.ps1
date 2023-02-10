# Powershell Configurations
$ErrorActionPreference = "stop"

Enable-PSRemoting -Force -SkipNetworkProfileCheck

# Ensure that current process can run scripts.
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Location of the log files
#$ScriptLogFolder = Join-Path $PSScriptRoot -ChildPath $("EnableProtocols" + [System.DateTime]::Now.ToString("yyyy-MM-dd-HH-mm-ss"))
$ScriptLog = Join-Path -Path $PSScriptRoot -ChildPath "EnableProtocols" + [System.DateTime]::Now.ToString("yyyy-MM-dd-HH-mm-ss") + ".log"

# Default exit code
$ExitCode = 0

function WriteLog
{
    Param(
        <# Can be null or empty #> $message
    )

    $timestampedMessage = $("[" + [System.DateTime]::Now + "] " + $message) | % {
        Write-Host -Object $_
        Out-File -InputObject $_ -FilePath $ScriptLog -Append
    }
}


try
{
    Import-Module sqlps

    WriteLog "Enabling Protocols ..."
    $smo = 'Microsoft.SqlServer.Management.Smo.'
    $wmi = new-object ($smo + 'Wmi.ManagedComputer').

    # Enable the TCP protocol on the default instance.
    $uri = "ManagedComputer[@Name='" + (get-item env:\computername).Value + "']/ServerInstance[@Name='MSSQLSERVER']/ServerProtocol[@Name='Tcp']"
    $Tcp = $wmi.GetSmoObject($uri)
    $Tcp.IsEnabled = $true
    $Tcp.Alter()
    $Tcp

    # Enable the named pipes protocol for the default instance.
    $uri = "ManagedComputer[@Name='" + (get-item env:\computername).Value + "']/ ServerInstance[@Name='MSSQLSERVER']/ServerProtocol[@Name='Np']"
    $Np = $wmi.GetSmoObject($uri)
    $Np.IsEnabled = $true
    $Np.Alter()
    $Np
}

catch
{
    if (($null -ne $Error[0]) -and ($null -ne $Error[0].Exception) -and ($null -ne $Error[0].Exception.Message))
    {
        $errMsg = $Error[0].Exception.Message
        WriteLog $errMsg
        Write-Host $errMsg
    }
    $ExitCode = -1
}

finally
{
    WriteLog $("This output log has been saved to: " + $ScriptLog)

    WriteLog $("Exiting with " + $ExitCode)
    exit $ExitCode
}