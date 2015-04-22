#
# Copyright="© Microsoft Corporation. All rights reserved."
#

param
(
    [Parameter(Mandatory)]
    [String]$DomainName,

    [Parameter(Mandatory)]
    [System.Management.Automation.PSCredential]$Admincreds,

    [Parameter(Mandatory)]
    [String]$SharePath,

    [Int]$RetryCount=20,
    [Int]$RetryIntervalSec=30
)

configuration CreateFileShareWitness
{
    Import-DscResource -ModuleName xComputerManagement, xSmbShare, cDisk,xDisk
    
    Node localhost
    {
        xWaitforDisk Disk2
        {
             DiskNumber = 2
             RetryIntervalSec =$RetryIntervalSec
             RetryCount = $RetryCount
        }

        cDiskNoRestart DataDisk
        {
            DiskNumber = 2
            DriveLetter = "F"
        }

        xComputer DomainJoin
        {
            Name = $env:COMPUTERNAME
            DomainName = $DomainName
            Credential = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
        }

        File FSWFolder
        {
            DestinationPath = "F:\$($SharePath.ToUpperInvariant())"
            Type = "Directory"
            Ensure = "Present"
            DependsOn = "[xComputer]DomainJoin"
        }

        xSmbShare FSWShare
        {
            Name = $SharePath.ToUpperInvariant()
            Path = "F:\$($SharePath.ToUpperInvariant())"
            FullAccess = "BUILTIN\Administrators"
            Ensure = "Present"
            DependsOn = "[File]FSWFolder"
        }
        LocalConfigurationManager 
        {
            ActionAfterReboot = 'StopConfiguration'
        }
    }     
}
