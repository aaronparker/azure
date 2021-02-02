#Requires -Module Az
<#
    .SYNOPSIS
    Dot source this script to export variables for use with deployment scripts.
#>
[CmdletBinding()]
[OutputType([Boolean])]
Param (
    [Parameter(Mandatory = $False)]
    [ValidateSet("AustraliaSoutheast", "AustraliaEast")]
    [System.String] $Location = "AustraliaSoutheast",

    [Parameter(Mandatory = $False)]
    [ValidateSet("Hub", "WindowsVirtualDesktop", "Terraform")]
    [System.String] $Resource = "Hub"
)

#region Common variables
$SubscriptionName = "Visual Studio Enterprise Subscription"
$SubscriptionId = (Get-AzSubscription | Where-Object { $_.Name -eq $SubscriptionName }).Id
Set-AzContext -SubscriptionId $SubscriptionId
$Context = Get-AzContext

$OrgName = "stealthpuppy"
$ShortOrgName = "stpy"

$ManagementGroups = @{
    Production = "mg-prod-$OrgName-au"
    Test       = "mg-test-$OrgName-au"
}

Switch ($Location) {
    "AustraliaSoutheast" {
        $ShortLocation = "ause"
    }
    "AustraliaEast" {
        $ShortLocation = "aue"
    }
}
#endregion

Switch ($Resource) {
    "Hub" {
        #region Hub variables
        $LongName = "Hub"
        $ShortName = "hub"
        $KeyVault = "$($OrgName.ToLower())$ShortName"
        $ResourceGroups = @{
            Infrastructure     = "rg-$($LongName)Infrastructure-$Location"
            DeviceManagement   = "rg-DeviceManagement-$Location"
            IdentityManagement = "rg-IdentityManagement-$Location"
        }
        $VirtualNetworkName = "vnet-$LongName-$Location"
        $NetworkSecurityGroups = @{
            Firewall = "nsg-Firewall"
            Identity = "nsg-Identity"
        }
        $Subnets = @{
            GatewaySubnet = "GatewaySubnet"
            Firewall      = "subnet-Firewall"
            Identity      = "subnet-Identity"
        }
        $AddressPrefix = "10.0.0.0/16"
        $SubnetAddress = @{
            GatewaySubnet = "10.0.0.0/24"
            Firewall      = "10.0.1.0/24"
            Identity      = "10.0.2.0/24"
        }
        $gatewayPrefix = "virtualgateway"
    }

    "Terraform" {
        #region Hub variables
        $LongName = "Terraform"
        $ShortName = "tfrm"
        $KeyVault = "$($OrgName.ToLower())$ShortName"
        $ResourceGroups = @{
            Core = @{
                Name     = "rg-$LongName-$Location"
                Location = $Location
                Function = $LongName
            }
        }
    }

    "WindowsVirtualDesktop" {
        #region WVD variables
        $LongName = "WindowsVirtualDesktop"
        $ShortName = "wvd"
        $KeyVault = "$($OrgName.ToLower())$ShortName"
        $ResourceGroups = @{
            Images         = "rg-$($LongName)Images-$Location"
            Infrastructure = "rg-$($LongName)Infrastructure-$Location"
            Personal       = "rg-$($LongName)Personal-$Location"
            Pooled         = "rg-$($LongName)Pooled-$Location"
        }
        $ResourceGroups = @{
            Infrastructure = "rg-$($LongName)Infrastructure-$Location"
            Personal       = "rg-$($LongName)Personal-$Location"
            Pooled         = "rg-$($LongName)Pooled-$Location"
        }
        $VirtualNetworkName = "vnet-$LongName-$Location"
        $NetworkSecurityGroups = @{
            Infrastructure = "nsg-Infrastructure"
            Pooled         = "nsg-PooledDesktops"
            Personal       = "nsg-PersonalDesktops"
        }
        $Subnets = @{
            Infrastructure = "subnet-Infrastructure"
            Pooled         = "subnet-PooledDesktops"
            Personal       = "subnet-PersonalDesktops"
        }
        $AddressPrefix = "10.1.0.0/16"
        $SubnetAddress = @{
            Infrastructure = "10.1.1.0/24"
            Pooled         = "10.1.2.0/24"
            Personal       = "10.1.3.0/24"
        }
        $gatewayPrefix = "virtualgateway"
        $FileShares = @{
            # FSLogixShare = "FSLogixContainers"
            Profile = "ProfileContainers"
            Office  = "OfficeContainers"
        }
        $BlobContainers = @{
            Apps    = "apps"
            Scripts = "scripts"
        }
        #region
    }
}
#endregion

# Tags
$Tags = @{
    Environment = "Development"
    Function    = $LongName
    CreatedDate = (Get-Date -Format dd-MM-yyyy)
    CreatedBy   = $Context.Account
    Owner       = "stealthpuppy"
}
