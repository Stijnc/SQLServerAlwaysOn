#
# Copyright="© Microsoft Corporation. All rights reserved."
#

configuration CreateFailoverCluster
{
    param
    (
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

        [Parameter(Mandatory)]
        [String]$ClusterName,

        [Parameter(Mandatory)]
        [String]$SharePath,

        [String[]]$Nodes,
        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30

    )

    Import-DscResource -ModuleName xComputerManagement, xFailOverCluster,CDisk,xActiveDirectory,XDisk
    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
   
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

        xWaitforDisk Disk3
        {
             DiskNumber = 3
             RetryIntervalSec =$RetryIntervalSec
             RetryCount = $RetryCount
        }

        cDiskNoRestart LogDisk
        {
            DiskNumber = 3
            DriveLetter = "G"
        }

        WindowsFeature FC
        {
            Name = "Failover-Clustering"
            Ensure = "Present"
        }

        WindowsFeature FCPS
        {
            Name = "RSAT-Clustering-PowerShell"
            Ensure = "Present"
        }

        WindowsFeature ADPS
        {
            Name = "RSAT-AD-PowerShell"
            Ensure = "Present"
        }
        xWaitForADDomain DscForestWait 
        { 
            DomainName = $DomainName 
            DomainUserCredential= $DomainCreds
            RetryCount = $RetryCount 
            RetryIntervalSec = $RetryIntervalSec 
        }
        xComputer DomainJoin
        {
            Name = $env:COMPUTERNAME
            DomainName = $DomainName
            Credential = $DomainCreds
        }
          
        xCluster FailoverCluster
        {
            Name = $ClusterName
            DomainAdministratorCredential = $DomainCreds
            Nodes = $Nodes
        }

        xWaitForFileShareWitness WaitForFSW
        {
            SharePath = $SharePath
            DomainAdministratorCredential = $DomainCreds
        }

        xClusterQuorum FailoverClusterQuorum
        {
            Name = $ClusterName
            SharePath = $SharePath
            DomainAdministratorCredential = $DomainCreds
        }
        LocalConfigurationManager 
        {
            ActionAfterReboot = 'StopConfiguration'
        }
    }
}
