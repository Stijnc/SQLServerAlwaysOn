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
    [String]$ClusterName,

    [Parameter(Mandatory)]
    [String]$SharePath,

    [String[]]$Nodes,
    [Int]$RetryCount=20,
    [Int]$RetryIntervalSec=30

)

configuration FailoverCluster
{
    Import-DscResource -ModuleName xComputerManagement, xFailOverCluster
    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
   
    Node localhost
    {
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
            DependsOn = "[xComputer]DomainJoin"
        }

        xWaitForFileShareWitness WaitForFSW
        {
            SharePath = $SharePath
            DomainAdministratorCredential = $DomainCreds
            DependsOn = "[xCluster]FailoverCluster"
        }

        xClusterQuorum FailoverClusterQuorum
        {
            Name = $ClusterName
            SharePath = $SharePath
            DomainAdministratorCredential = $DomainCreds
            DependsOn = "[xWaitForFileShareWitness]WaitForFSW"
        }
        LocalConfigurationManager 
        {
            ActionAfterReboot = 'StopConfiguration'
        }
    }
}
