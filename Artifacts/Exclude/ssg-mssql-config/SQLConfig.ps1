# Powershell Configurations
$ErrorActionPreference = "stop"

Enable-PSRemoting -Force -SkipNetworkProfileCheck

# Ensure that current process can run scripts.
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Location of the log files
#$ScriptLogFolder = Join-Path $PSScriptRoot -ChildPath $("EnableProtocols" + [System.DateTime]::Now.ToString("yyyy-MM-dd-HH-mm-ss"))
$ScriptLog = Join-Path -Path $PSScriptRoot -ChildPath ("EnableProtocols" + [System.DateTime]::Now.ToString("yyyy-MM-dd-HH-mm-ss") + ".log")

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

    ################  Protocols  ################################

    Import-Module sqlps
    $computerName = (Get-Item env:\computername).Value

    WriteLog "Enabling Protocols ..."
    $smo = 'Microsoft.SqlServer.Management.Smo.'
    $wmi = new-object ($smo + 'Wmi.ManagedComputer').

    # Enable the TCP protocol on the default instance.
    $uri = "ManagedComputer[@Name='$computerName']/ServerInstance[@Name='MSSQLSERVER']/ServerProtocol[@Name='Tcp']"
    $Tcp = $wmi.GetSmoObject($uri)
    $Tcp.IsEnabled = $true
    $Tcp.Alter()
    $Tcp

    # Enable the named pipes protocol for the default instance.
    $uri = "ManagedComputer[@Name='$computerName']/ ServerInstance[@Name='MSSQLSERVER']/ServerProtocol[@Name='Np']"
    $Np = $wmi.GetSmoObject($uri)
    $Np.IsEnabled = $true
    $Np.Alter()
    $Np

    ##########################  Disks #############################

    #add data and log disks
    $vm = Get-AzVM -Name $computerName
    $diskConfig = New-AzDiskConfig -CreateOption Empty -DiskSizeGB 64 -SkuName Premium_LRS -Location ($vm.Location)
    $dataDisk = New-AzDisk -ResourceGroupName ($vm.ResourceGroupName) -DiskName ("$computerName_SQLDATA") -Disk $diskConfig

    $diskConfig = New-AzDiskConfig -CreateOption Empty -DiskSizeGB 16 -SkuName Premium_LRS -Location ($vm.Location)
    $logDisk = New-AzDisk -ResourceGroupName ($vm.ResourceGroupName) -DiskName ("$computerName_SQLLOG") -Disk $diskConfig

    $vm = Add-AzVMDataDisk -VM $vm -Name "$computerName_SQLDATA" -CreateOption Attach -ManagedDiskId $dataDisk.Id -Lun 1
    $vm = Add-AzVMDataDisk -VM $vm -Name "$computerName_SQLLOG" -CreateOption Attach -ManagedDiskId $logDisk.Id -Lun 2

    Update-AzVM -ResourceGroupName $vm.ResourceGroupName -VM $vm

    #initialize disks
    #    Get-Disk | Where PartitionStyle -eq 'raw' | Initialize-Disk -PartitionStyle MBR -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel #myDemoDataDisk" -Confirm:$false

    #create folders for data and log disks

    #move tempdb to temp storage

    #move system dbs to data drives

    #set service account to domain account

    #max memory

    #maxdop

    






    #move tempdb to temp storage

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