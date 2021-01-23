#Requires -Module Az
# Dot source Export-Variables.ps1 first

# Get the target resource group
$ResourceGroup = Get-AzResourceGroup -Name $ResourceGroups.Network.Name
$ResourceGroup = Get-AzResourceGroup -Name "rg-Terraform-$Location"

#region Network
# Network Security Groups
$params = @{
    Name                     = "rdp-rule"
    Description              = "Allow RDP"
    Access                   = "Allow"
    Protocol                 = "Tcp"
    Direction                = "Inbound"
    Priority                 = "100"
    SourceAddressPrefix      = "VirtualNetwork"
    SourcePortRange          = "*"
    DestinationAddressPrefix = "*"
    DestinationPortRange     = "3389"
}
$rdpRule = New-AzNetworkSecurityRuleConfig @params

# Network security groups
ForEach ($item in $NetworkSecurityGroups.GetEnumerator()) {
    $params = @{
        Name              = $item.Value
        ResourceGroupName = $ResourceGroups.Infrastructure
        Location          = $Location
        Tag               = $Tags
    }
    New-AzNetworkSecurityGroup @params
}

# Virtual network peering
$params = @{
    Name              = $VirtualNetworkName
    ResourceGroupName = $ResourceGroups.Infrastructure
    Location          = $Location
    AddressPrefix     = $AddressPrefix
    Tag               = $Tags
}
$VirtualNetwork = New-AzVirtualNetwork @params

# Subnets
ForEach ($item in $Subnets.GetEnumerator()) {
    $params = @{
        Name                 = $item.Value
        AddressPrefix        = $SubnetAddress[$item.Key]
        NetworkSecurityGroup = (Get-AzNetworkSecurityGroup -Name $NetworkSecurityGroups[$item.Key] -ResourceGroupName $ResourceGroups.Infrastructure)
        VirtualNetwork       = $VirtualNetwork
    }
    Add-AzVirtualNetworkSubnetConfig @params
    $VirtualNetwork | Set-AzVirtualNetwork
}


# Get the vnets
$vnet1 = Get-AzVirtualNetwork | Where-Object { $_.Name -eq "vnet-HubNetwork-AustraliaSoutheast" }
$vnet2 = Get-AzVirtualNetwork | Where-Object { $_.Name -eq "vnet-WindowsVirtualDesktop-AustraliaEast" }

# Peer VNet1 to VNet2.
$params = @{
    Name                   = "$($vnet1.Name)-$($vnet2.Name)"
    VirtualNetwork         = $vnet1
    RemoteVirtualNetworkId = $vnet2.Id
    AllowGatewayTransit    = $true
}
Add-AzVirtualNetworkPeering @params

# Peer VNet2 to VNet1.
$params = @{
    Name                   = "$($vnet2.Name)-$($vnet1.Name)"
    VirtualNetwork         = $vnet2
    RemoteVirtualNetworkId = $vnet1.Id
    UseRemoteGateways      = $True
}
Add-AzVirtualNetworkPeering @params

# Set DNS servers
$DomainServers = "10.100.100.2"
ForEach ($vnet in ($vnet1, $vnet2)) {
    ForEach ($server in $DomainServers) {
        $vnet.DhcpOptions.DnsServers += $server
    }
    Set-AzVirtualNetwork -VirtualNetwork $vnet
}

#TODO: GatewaySubnet

#region Add the required rules for AADDS
<#
$Nsg = Get-AzNetworkSecurityGroup -Name $NetworkSecurityGroups.DomainServices -ResourceGroupName $ResourceGroups.Infrastructure
$params = @{
    Name                     = "AzureAdSync"
    Description              = "AADDS sync from Azure AD"
    Access                   = "Allow"
    Protocol                 = "TCP"
    Direction                = "Inbound"
    Priority                 = 100
    SourceAddressPrefix      = "AzureActiveDirectoryDomainServices"
    SourcePortRange          = "*"
    DestinationAddressPrefix = "*"
    DestinationPortRange     = "443"
}
$Nsg | Add-AzNetworkSecurityRuleConfig @params | Set-AzNetworkSecurityGroup

$Nsg = Get-AzNetworkSecurityGroup -Name $NetworkSecurityGroups.DomainServices -ResourceGroupName $ResourceGroups.Infrastructure
$params = @{
    Name                     = "AADDSManagement"
    Description              = "AADDS management services"
    Access                   = "Allow"
    Protocol                 = "TCP"
    Direction                = "Inbound"
    Priority                 = 110
    SourceAddressPrefix      = "AzureActiveDirectoryDomainServices"
    SourcePortRange          = "*"
    DestinationAddressPrefix = "*"
    DestinationPortRange     = "5968"
}
$Nsg | Add-AzNetworkSecurityRuleConfig @params | Set-AzNetworkSecurityGroup

$Nsg = Get-AzNetworkSecurityGroup -Name $NetworkSecurityGroups.DomainServices -ResourceGroupName $ResourceGroups.Infrastructure
$params = @{
    Name                     = "DCManagement"
    Description              = "AADDS DC management from Microsoft corporate network"
    Access                   = "Allow"
    Protocol                 = "TCP"
    Direction                = "Inbound"
    Priority                 = 120
    SourceAddressPrefix      = "CorpNetSaw"
    SourcePortRange          = "*"
    DestinationAddressPrefix = "*"
    DestinationPortRange     = "3389"
}
$Nsg | Add-AzNetworkSecurityRuleConfig @params | Set-AzNetworkSecurityGroup

$Nsg = Get-AzNetworkSecurityGroup -Name $NetworkSecurityGroups.DomainServices -ResourceGroupName $ResourceGroups.Infrastructure
$params = @{
    Name                     = "SecureLDAP"
    Description              = "Secure LDAP"
    Access                   = "Allow"
    Protocol                 = "TCP"
    Direction                = "Inbound"
    Priority                 = 130
    SourceAddressPrefix      = "*"
    SourcePortRange          = "*"
    DestinationAddressPrefix = "*"
    DestinationPortRange     = "636"
}
$Nsg | Add-AzNetworkSecurityRuleConfig @params | Set-AzNetworkSecurityGroup
#>

# Virtual network
$params = @{
    ResourceGroupName = $ResourceGroups.Infrastructure
    Name              = $VirtualNetworkName
}
$VirtualNetwork = Get-AzVirtualNetwork @params

# Add the GatewaySubnet
# Add-AzVirtualNetworkSubnetConfig -Name 'GatewaySubnet' -AddressPrefix $Subnets.Gateway -VirtualNetwork $vnet
# Set-AzVirtualNetwork -VirtualNetwork $vnet