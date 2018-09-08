# Australia Southeast
$locations = @("AustraliaSoutheast")

# Network space
$addressSpace = "10.0.0.0/16"
$gatewayAddress = "10.0.0.0/27"
$jumpAddress = "10.0.1.0/27"
$authAddress = "10.0.2.0/24"
$dataAddress = "10.0.3.0/24"
$appAddress = "10.0.4.0/24"
$rdsAddress = "10.0.5.0/24"
$dmzAddress = "10.0.254.0/24"

ForEach ($location in $locations) {

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
    New-AzureRmResourceGroup -Name $resourceGroup -Location $location

    # NSG rules
    $rdpRule = New-AzureRmNetworkSecurityRuleConfig -Name rdp-rule -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 `
        -SourceAddressPrefix "VirtualNetwork" -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389

    # Network security group
    $appNsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location -Name "$($appSubnet)-nsg"
    $authNsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location -Name "$($authSubnet)-nsg"
    $dataNsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location -Name "$($dataSubnet)-nsg"
    $dmzNsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location -Name "$($dmzSubnet)-nsg"
    $rdsNsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location -Name "$($rdsSubnet)-nsg"
    $jumpNsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location -Name "$($jumpSubnet)-nsg" -SecurityRules $rdpRule

    # Subnets
    $gatewaySubnetCfg = New-AzureRmVirtualNetworkSubnetConfig -Name $gateway -AddressPrefix $gatewayAddress
    $appSubnetCfg = New-AzureRmVirtualNetworkSubnetConfig -Name $appSubnet -AddressPrefix $appAddress -NetworkSecurityGroup $appNsg
    $authSubnetCfg = New-AzureRmVirtualNetworkSubnetConfig -Name $authSubnet -AddressPrefix $authAddress -NetworkSecurityGroup $authNsg
    $dataSubnetCfg = New-AzureRmVirtualNetworkSubnetConfig -Name $dataSubnet -AddressPrefix $dataAddress -NetworkSecurityGroup $dataNsg
    $dmzSubnetCfg = New-AzureRmVirtualNetworkSubnetConfig -Name $dmzSubnet -AddressPrefix $dmzAddress -NetworkSecurityGroup $dmzNsg
    $jumpSubnetCfg = New-AzureRmVirtualNetworkSubnetConfig -Name $jumpSubnet -AddressPrefix $jumpAddress -NetworkSecurityGroup $jumpNsg
    $rdsSubnetCfg = New-AzureRmVirtualNetworkSubnetConfig -Name $rdsSubnet -AddressPrefix $rdsAddress -NetworkSecurityGroup $rdsNsg

    # Virtual network
    $vnet = New-AzureRmVirtualNetwork -Name $virtualNetwork -ResourceGroupName $resourceGroup -Location $location -AddressPrefix $addressSpace `
        -Subnet $gatewaySubnetCfg, $appSubnetCfg, $authSubnetCfg, $dataSubnetCfg, $dmzSubnetCfg, $jumpSubnetCfg, $rdsSubnetCfg

    $output += $vnet
}

Write-Output $output
