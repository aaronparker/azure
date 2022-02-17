<#
    .SYNOPSIS
        Create a virtual network, storage account and virtual machine in Azure.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
[CmdletBinding()]
param (
    [Parameter()]
    [System.String] $SubscriptionId = "63e8f660-f6a4-4ac5-ad4e-623268509f20",

    [Parameter()]
    [System.String] $ResourceGroupName = "rg-PatchMyPC-AustraliaEast",

    [Parameter()]
    [System.String] $Location = "AustraliaEast",

    [Parameter()]
    [System.Collections.Hashtable] $Tag = @{
        "environment" = "production"
        "function"    = "PatchMyPc"
        "owner"       = "aaronparker@cloud.stealthpuppy.com"
    },

    [Parameter()]
    [System.String] $NetworkSecurityGroupName = "nsg-pmp",

    [Parameter()]
    [System.String] $VirtualNetworkName = "vnet-PatchMyPC-AustraliaEast",

    [Parameter()]
    [System.String] $AddressPrefix = "10.0.0.0/16",

    [Parameter()]
    [System.Collections.Hashtable] $Subnet = @{
        "subnet-pmp" = "10.0.0.0/24"
    },

    [Parameter()]
    [System.String] $StorageAccountName = "pmpdiagaue",

    [Parameter()]
    [System.String] $ServiceEndpointPolicyDefinitionName = "MicrosoftStorageServiceEndpointPolicyAustraliaEast"
)

# Trust the PSGallery for modules
$Repository = "PSGallery"
If (Get-PSRepository | Where-Object { $_.Name -eq $Repository -and $_.InstallationPolicy -ne "Trusted" }) {
    try {
        Install-PackageProvider -Name "NuGet" -MinimumVersion "2.8.5.208" -Force
        Set-PSRepository -Name $Repository -InstallationPolicy "Trusted"
    }
    catch {
        $_.Exception.Message
    }
}

# Install the required modules
ForEach ($module in "Az") {
    $installedModule = Get-Module -Name $module -ListAvailable -ErrorAction "SilentlyContinue" | `
        Sort-Object -Property @{ Expression = { [System.Version]$_.Version }; Descending = $true } | `
        Select-Object -First 1
    $publishedModule = Find-Module -Name $module -ErrorAction "SilentlyContinue"
    If (($Null -eq $installedModule) -or ([System.Version]$publishedModule.Version -gt [System.Version]$installedModule.Version)) {
        $params = @{
            Name               = $module
            SkipPublisherCheck = $true
            Force              = $true
            ErrorAction        = "Stop"
        }
        Install-Module @params
        Import-Module -Name "Az"
    }
}

# Connect to Azure
Connect-AzAccount -UseDeviceAuthentication
If ($Null -eq (Get-AzAccessToken -ErrorAction "SilentlyContinue")) {
    Write-Error -Message "Failed to find an access token."
}
Select-AzSubscription -Subscription $SubscriptionId | Format-List

# Create the resource group
ForEach ($Group in $ResourceGroupName) {
    $params = @{
        Name     = $Group
        Location = $Location
        Tag      = $Tag
    }
    New-AzResourceGroup @params
}

# Network security groups
ForEach ($Group in $NetworkSecurityGroupName) {
    $params = @{
        Name              = $Group
        ResourceGroupName = $ResourceGroupName
        Location          = $Location
        Tag               = $Tag
    }
    $NetworkSecurityGroup = New-AzNetworkSecurityGroup @params
}

# Virtual networks
$params = @{
    Name              = $VirtualNetworkName
    ResourceGroupName = $ResourceGroupName
    Location          = $Location
    AddressPrefix     = $AddressPrefix
    Tag               = $Tag
}
$VirtualNetwork = New-AzVirtualNetwork @params

# Subnets
ForEach ($item in $Subnet.GetEnumerator()) {
    $params = @{
        Name              = $NetworkSecurityGroupName
        ResourceGroupName = $ResourceGroupName
    }
    $NetworkSecurityGroup = Get-AzNetworkSecurityGroup @params

    $params = @{
        Name                 = $item.Name
        AddressPrefix        = $Subnet[$item.Key]
        NetworkSecurityGroup = $NetworkSecurityGroup
        VirtualNetwork       = $VirtualNetwork
    }
    $VirtualNetworkConfig = Add-AzVirtualNetworkSubnetConfig @params
    $VirtualNetworkConfig | Set-AzVirtualNetwork
}

# Standard storage
$params = @{
    Name              = $StorageAccountName.ToLower()
    ResourceGroupName = $ResourceGroupName
    Location          = $Location
    Kind              = "StorageV2"
    SkuName           = "Standard_LRS"
    AccessTier        = "Hot"
    Tag               = $Tag
}
$StorageAccount = New-AzStorageAccount @params

# Declare service endpoint policy definition
$params = @{
    Name            = $ServiceEndpointPolicyDefinitionName
    Service         = "Microsoft.Storage"
    ServiceResource = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName"
    Description     = "Enables the Microsoft.Storage service endpoint"
}
$PolicyDefinition = New-AzServiceEndpointPolicyDefinition @params

# Service Endpoint Policy
$params = @{
    ResourceGroupName               = $ResourceGroupName
    Name                            = "ServiceEndpointMicrosoftStorage$Location"
    Location                        = $Location
    ServiceEndpointPolicyDefinition = $PolicyDefinition
}
$ServiceEndpoint = New-AzServiceEndpointPolicy @params

# Associate a subnet to the service endpoint policy
ForEach ($item in $Subnet.GetEnumerator()) {
    $params = @{
        Name                  = $item.Name
        VirtualNetwork        = $VirtualNetwork
        AddressPrefix          = $Subnet[$item.Key]
        ServiceEndpointPolicy = $ServiceEndpoint
    }
    Set-AzVirtualNetworkSubnetConfig @params
}
