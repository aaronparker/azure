#Requires -Module Az
# Dot source Export-Variables.ps1 first

$Tags = @{
    Environment = "Development"
    Function    = "VpnGateway"
    Owner       = $Context.Account
}

# Create local network gateway
$LocalNetworkGatewayName = "lng-$LongName-$Location"
$params = @{
    Name              = $LocalNetworkGatewayName
    ResourceGroupName = $ResourceGroups.Infrastructure
    Location          = $Location
    GatewayIpAddress  = "180.150.38.232"
    AddressPrefix     = @("10.100.100.0/24", "192.168.0.0/24")
    Tag               = $Tags
}
$LocalNetworkGateway = New-AzLocalNetworkGateway @params

# Public IP address for the VPN gateway
$params = @{
    Name              = "gwip-$LongName-$Location"
    DomainNameLabel   = ("$($LongName)$($ShortName)").ToLower()
    ResourceGroupName = $ResourceGroups.Infrastructure
    Location          = $Location
    AllocationMethod  = "Dynamic"
    Sku               = "Basic"
    IpAddressVersion  = "IPv4"
    Tag               = $Tags
}
$GatewayPublicIP = New-AzPublicIpAddress @params

# Create the gateway IP addressing configuration
$VirtualNetwork = Get-AzVirtualNetwork -Name $VirtualNetworkName -ResourceGroupName $ResourceGroups.Infrastructure
$GatewaySubnet = Get-AzVirtualNetworkSubnetConfig -Name $Subnets.GatewaySubnet -VirtualNetwork $VirtualNetwork
$params = @{
    Name              = 'gwipconfig1'
    SubnetId          = $GatewaySubnet.Id
    #SubnetId          = $SubnetAddress.GatewaySubnet
    PublicIpAddressId = $GatewayPublicIP.Id
}
$gwipconfig = New-AzVirtualNetworkGatewayIpConfig @params

# Create the virtual network gateway
$params = @{
    Name              = "$gatewayPrefix-$LongName-$Location"
    ResourceGroupName = $ResourceGroups.Infrastructure
    Location          = $Location
    IpConfigurations  = $gwipconfig
    GatewayType       = "Vpn"
    VpnType           = "RouteBased"
    GatewaySku        = "Basic"
    Tag               = $Tags
}
$VirtualNetworkGateway = New-AzVirtualNetworkGateway @params

# Preshared key
#TODO Add VPN pre-shared key to vault
$VpnSharedKey = (Get-AzKeyVaultSecret -VaultName $KeyVault.VaultName -Name "GatewaySecret").SecretValueText

# IPsec/IKE policy for Lab
$params = @{
    IkeEncryption     = "AES256"
    IkeIntegrity      = "SHA256"
    DhGroup           = "DHGroup2"
    IpsecEncryption   = "AES256"
    IpsecIntegrity    = "SHA256"
    PfsGroup          = "None"
    SALifeTimeSeconds = "86400"
}
$IpsecPolicy = New-AzIpsecPolicy @params

# Create the S2S VPN connection with policy-based traffic selectors and IPsec/IKE policy
$params = @{
    Name                           = "connection-$LongName-$Location"
    ResourceGroupName              = $ResourceGroups.Infrastructure
    VirtualNetworkGateway1         = $VirtualNetworkGateway
    LocalNetworkGateway2           = $LocalNetworkGateway
    Location                       = $Location
    ConnectionType                 = "IPsec"
    UsePolicyBasedTrafficSelectors = $True
    IpsecPolicies                  = $IpsecPolicy
    SharedKey                      = $VpnSharedKey
    Tag                            = $Tags
}
New-AzVirtualNetworkGatewayConnection @params
#endregion

#region Recreate gateway connection
$params = @{
    VaultName = $KeyVault
    Name      = "VpnPresharedKey"
}
$VpnSharedKey = (Get-AzKeyVaultSecret @params).SecretValueText
$params = @{
    Name              = "$gatewayPrefix-$LongName-$Location"
    ResourceGroupName = $ResourceGroups.Infrastructure
}
$VirtualNetworkGateway = Get-AzVirtualNetworkGateway @params
$params = @{
    Name              = $LocalNetworkGatewayName
    ResourceGroupName = $ResourceGroups.Infrastructure
}
$LocalNetworkGateway = Get-AzLocalNetworkGateway @params
$params = @{
    IkeEncryption     = "AES256"
    IkeIntegrity      = "SHA256"
    DhGroup           = "DHGroup2"
    IpsecEncryption   = "AES256"
    IpsecIntegrity    = "SHA256"
    PfsGroup          = "PFS2"
    SALifeTimeSeconds = "86400"
}
$IpsecPolicy = New-AzIpsecPolicy @params
$params = @{
    Name                           = "connection-$LongName-$ShortName"
    ResourceGroupName              = $ResourceGroups.Infrastructure
    VirtualNetworkGateway1         = $VirtualNetworkGateway
    LocalNetworkGateway2           = $LocalNetworkGateway
    Location                       = $Location
    ConnectionType                 = "IPsec"
    UsePolicyBasedTrafficSelectors = $True
    IpsecPolicies                  = $IpsecPolicy
    SharedKey                      = $VpnSharedKey
}
New-AzVirtualNetworkGatewayConnection @params
#endregion
