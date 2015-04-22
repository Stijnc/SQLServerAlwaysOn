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
    [System.Management.Automation.PSCredential]$SqlServerServiceAccountcreds,

    [Parameter(Mandatory)]
    [String]$SqlAlwaysOnEndpointName,
    
    [String]$DomainNetbiosName=(Get-NetBIOSName -DomainName $DomainName),
    
    [UInt32]$DatabaseEnginePort = 1433
)

configuration AvailabilityGroupNode
{
    Import-DscResource -ModuleName xComputerManagement, xNetworking, xSqlPs, xActiveDirectory

    [System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($Admincreds.UserName)", $Admincreds.Password)
    [System.Management.Automation.PSCredential]$SQLCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($SqlServerServiceAccountcreds.UserName)", $SqlServerServiceAccountcreds.Password)


    Node localhost
    {
        xFirewall DatabaseEngineFirewallRule
        {
            Direction = "Inbound"
            Name = "SQL-Server-Database-Engine-TCP-In"
            DisplayName = "SQL Server Database Engine (TCP-In)"
            Description = "Inbound rule for SQL Server to allow TCP traffic for the Database Engine."
            DisplayGroup = "SQL Server"
            State = "Enabled"
            Access = "Allow"
            Protocol = "TCP"
            LocalPort = $DatabaseEnginePort -as [String]
            Ensure = "Present"
        }

        xFirewall DatabaseMirroringFirewallRule
        {
            Direction = "Inbound"
            Name = "SQL-Server-Database-Mirroring-TCP-In"
            DisplayName = "SQL Server Database Mirroring (TCP-In)"
            Description = "Inbound rule for SQL Server to allow TCP traffic for the Database Mirroring."
            DisplayGroup = "SQL Server"
            State = "Enabled"
            Access = "Allow"
            Protocol = "TCP"
            LocalPort = "5022"
            Ensure = "Present"
        }

        xFirewall ListenerFirewallRule
        {
            Direction = "Inbound"
            Name = "SQL-Server-Availability-Group-Listener-TCP-In"
            DisplayName = "SQL Server Availability Group Listener (TCP-In)"
            Description = "Inbound rule for SQL Server to allow TCP traffic for the Availability Group listener."
            DisplayGroup = "SQL Server"
            State = "Enabled"
            Access = "Allow"
            Protocol = "TCP"
            LocalPort = "59999"
            Ensure = "Present"
        }

        xSqlLogin AddDomainAdminAccountToSysadminServerRole
        {
            Name = "${DomainNetbiosName}\$($Admincreds.UserName)"
            LoginType = "WindowsUser"
            ServerRoles = "sysadmin"
            Enabled = $true
            Credential = $Admincreds      
        }

        xADUser CreateSqlServerServiceAccount
        {
            DomainAdministratorCredential = $Domaincreds
            DomainName = $DomainName
            UserName = $SqlServerServiceAccountcreds.UserName
            Password =  $SQLCreds
            Ensure = "Present"
        }

        xSqlServer ConfigureSqlServerWithAlwaysOn
        {
            InstanceName = $env:COMPUTERNAME
            SqlAdministratorCredential = $DomainCreds
            ServiceCredential = sqlCreds
            Hadr = "Enabled"
            MaxDegreeOfParallelism = 1
            FilePath = "F:\DATA"
            LogPath = "G:\LOG"
            DomainAdministratorCredential = $Domaincreds
            DependsOn = "[xADUser]CreateSqlServerServiceAccount"
        }

        xSqlEndpoint SqlAlwaysOnEndpoint
        {
            InstanceName = $env:COMPUTERNAME
            Name = $SqlAlwaysOnEndpointName
            PortNumber = 5022
            AllowedUser = $SqlServerServiceAccountcreds.UserName
            SqlAdministratorCredential = $Domaincreds
            DependsOn = "[xSqlServer]ConfigureSqlServerWithAlwaysOn"
        }
        LocalConfigurationManager 
        {
            ActionAfterReboot = 'StopConfiguration'
        }

    }
}
function Get-NetBIOSName
{ 
    [OutputType([string])]
    param(
        [string]$DomainName
    )

    if ($DomainName.Contains('.')) {
        $length=$DomainName.IndexOf('.')
        if ( $length -ge 16) {
            $length=15
        }
        return $DomainName.Substring(0,$length)
    }
    else {
        if ($DomainName.Length -gt 15) {
            return $DomainName.Substring(0,15)
        }
        else {
            return $DomainName
        }
    }
}
