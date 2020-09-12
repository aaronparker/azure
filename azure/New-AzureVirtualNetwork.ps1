# Properties
Function New-AzureVirtualNetwork {
    <#
        Create a new virtual network
    #>
    [CmdletBinding()]
    Param (
        [Parameter()] $Location        = 'AustraliaSoutheast',
        [Parameter()] $AddressSpace    = '10.0.0.0/16',
        [Parameter()] $GatewayAddress  = '10.0.0.0/27',
        [Parameter()] $JumpAddress     = '10.0.1.0/27',
        [Parameter()] $AuthAddress     = '10.0.2.0/24',
        [Parameter()] $DataAddress     = '10.0.3.0/24',
        [Parameter()] $AppAddress      = '10.0.4.0/24',
        [Parameter()] $RdsAddress      = '10.0.5.0/24',
        [Parameter()] $DmzAddress      = '10.0.254.0/24'
    )

    # Common variables
    $gateway = "GatewaySubnet"
    $resourceGroup = "Core-Vnet-$($location)-rg"
    $virtualNetwork = "Core-$($location)-vnet"
    $appSubnet = "App-$($location)-subnet"
    $authSubnet = "Authn-$($location)-subnet"
    $dataSubnet = "Data-$($location)-subnet"
    $dmzSubnet = "Dmz-$($location)-subnet"
    $jumpSubnet = "Jumpbox-$($location)-subnet"
    $rdsSubnet = "Rds-$($location)-subnet"

    # New Resource Group
    New-AzResourceGroup -Name $resourceGroup -Location $location

    # NSG rules
    $rdpRule = New-AzNetworkSecurityRuleConfig -Name rdp-rule -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 `
        -SourceAddressPrefix "VirtualNetwork" -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389

    # Network security group
    $appNsg = New-AzNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location -Name "$($appSubnet)-nsg"
    $authNsg = New-AzNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location -Name "$($authSubnet)-nsg"
    $dataNsg = New-AzNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location -Name "$($dataSubnet)-nsg"
    $dmzNsg = New-AzNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location -Name "$($dmzSubnet)-nsg"
    $rdsNsg = New-AzNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location -Name "$($rdsSubnet)-nsg"
    $jumpNsg = New-AzNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location -Name "$($jumpSubnet)-nsg" -SecurityRules $rdpRule

    # Subnets
    $gatewaySubnetCfg = New-AzVirtualNetworkSubnetConfig -Name $gateway -AddressPrefix $gatewayAddress
    $appSubnetCfg = New-AzVirtualNetworkSubnetConfig -Name $appSubnet -AddressPrefix $appAddress -NetworkSecurityGroup $appNsg
    $authSubnetCfg = New-AzVirtualNetworkSubnetConfig -Name $authSubnet -AddressPrefix $authAddress -NetworkSecurityGroup $authNsg
    $dataSubnetCfg = New-AzVirtualNetworkSubnetConfig -Name $dataSubnet -AddressPrefix $dataAddress -NetworkSecurityGroup $dataNsg
    $dmzSubnetCfg = New-AzVirtualNetworkSubnetConfig -Name $dmzSubnet -AddressPrefix $dmzAddress -NetworkSecurityGroup $dmzNsg
    $jumpSubnetCfg = New-AzVirtualNetworkSubnetConfig -Name $jumpSubnet -AddressPrefix $jumpAddress -NetworkSecurityGroup $jumpNsg
    $rdsSubnetCfg = New-AzVirtualNetworkSubnetConfig -Name $rdsSubnet -AddressPrefix $rdsAddress -NetworkSecurityGroup $rdsNsg

    # Virtual network
    $vnet = New-AzVirtualNetwork -Name $virtualNetwork -ResourceGroupName $resourceGroup -Location $location -AddressPrefix $addressSpace `
        -Subnet $gatewaySubnetCfg, $appSubnetCfg, $authSubnetCfg, $dataSubnetCfg, $dmzSubnetCfg, $jumpSubnetCfg, $rdsSubnetCfg

    $output += $vnet
    Write-Output $output
}



$network1 = @{
    Location        = 'AustraliaSoutheast'
    AddressSpace    = '10.0.0.0/16'
    GatewayAddress  = '10.0.0.0/27'
    JumpAddress     = '10.0.1.0/27'
    AuthAddress     = '10.0.2.0/24'
    DataAddress     = '10.0.3.0/24'
    AppAddress      = '10.0.4.0/24'
    RdsAddress      = '10.0.5.0/24'
    DmzAddress      = '10.0.254.0/24'
}
$network2 = @{
    Location        = 'AustraliaEast'
    AddressSpace    = '10.1.0.0/16'
    GatewayAddress  = '10.1.0.0/27'
    JumpAddress     = '10.1.1.0/27'
    AuthAddress     = '10.1.2.0/24'
    DataAddress     = '10.1.3.0/24'
    AppAddress      = '10.1.4.0/24'
    RdsAddress      = '10.1.5.0/24'
    DmzAddress      = '10.1.254.0/24'
}



$sharedKey = (Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name vnetGatewaySharedKey).SecretValueText

# Virtual network gateway connections
$localNetworkGateway = New-AzLocalNetworkGateway -Name $localNetName -ResourceGroupName $resourceGroup -Location $location `
    -GatewayIpAddress $GatewayIpAddress -AddressPrefix $addressPrefix

$virtualNetworkGateway = Get-AzVirtualNetworkGateway -ResourceGroupName $resourceGroup -Name "$locPrefix-vnetgateway"

New-AzVirtualNetworkGatewayConnection -Name $connectionName -ConnectionType IPsec -ResourceGroupName $resourceGroup `
    -Location $location -VirtualNetworkGateway1 $virtualNetworkGateway -LocalNetworkGateway2 $localNetworkGateway `
    -RoutingWeight $routingWeight -SharedKey $sharedKey
