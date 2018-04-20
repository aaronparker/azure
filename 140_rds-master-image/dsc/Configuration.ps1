configuration DomainJoin 
{ 
    param 
    ( 
        [Parameter(Mandatory)]
        [String]$domainName,

        [Parameter(Mandatory)]
        [PSCredential]$adminCreds
    ) 
    
    Import-DscResource -ModuleName xComputerManagement, xRemoteDesktopSessionHost

    $username = $adminCreds.UserName -split '\\' | Select-Object -last 1
    $domainCreds = New-Object System.Management.Automation.PSCredential ("$($username)@$($domainName)", $adminCreds.Password)
       
    Node localhost
    {
        LocalConfigurationManager {
            RebootNodeIfNeeded = $true
        }

        WindowsFeature ADPowershell {
            Name   = "RSAT-AD-PowerShell"
            Ensure = "Present"
        } 

        xComputer DomainJoin {
            Name       = $env:COMPUTERNAME
            DomainName = $domainName
            Credential = $domainCreds
            DependsOn  = "[WindowsFeature]ADPowershell" 
        }
    }
}

configuration SessionHost
{
    param 
    ( 
        [Parameter(Mandatory)]
        [String]$domainName,

        [Parameter(Mandatory)]
        [PSCredential]$adminCreds
    ) 


    Node localhost
    {
        LocalConfigurationManager {
            RebootNodeIfNeeded = $true
            ConfigurationMode  = "ApplyOnly"
        }

<#        DomainJoin DomainJoin {
            domainName = $domainName 
            adminCreds = $adminCreds 
        }
#>

        WindowsFeature RDS-RD-Server {
            Ensure = "Present"
            Name   = "RDS-RD-Server"
        }

        WindowsFeature Server-Media-Foundation {
            Ensure = "Present"
            Name = "Server-Media-Foundation"
        }
        
        WindowsFeature Search-Service {
            Ensure = "Present"
            Name = "Search-Service"
        }
        
        WindowsFeature NET-Framework-Core {
            Ensure = "Present"
            Name = "NET-Framework-Core"
        }

        WindowsFeature BitLocker {
            Ensure = "Absent"
            Name = "BitLocker"
        }
        
        WindowsFeature EnhancedStorage {
            Ensure = "Absent"
            Name = "EnhancedStorage"
        }
        
        WindowsFeature PowerShell-ISE {
            Ensure = "Absent"
            Name = "PowerShell-ISE"
        }
    }
}
