

## Networks
# Australia East
$location = "AustraliaEast"
$locPrefix = "AuE"
$addressSpace = "10.0.0.0/16"
$gatewayAddress = "10.0.0.0/27"
$dmzAddress = "10.0.1.0/27"
$authAddress = "10.0.2.0/24"
$dataAddress = "10.0.3.0/24"
$appAddress = "10.0.4.0/24"

# Australia Southeast
$location = "AustraliaSoutheast"
$locPrefix = "AuSE"
$addressSpace = "10.1.0.0/16"
$gatewayAddress = "10.1.0.0/27"
$dmzAddress = "10.1.1.0/27"
$authAddress = "10.1.2.0/24"
$dataAddress = "10.1.3.0/24"
$appAddress = "10.1.4.0/24"


# Common variables
$gateway = "GatewaySubnet"
$resourceGroup = "$($locPrefix)-vnet-rg"
$virtualNetwork = "$($locPrefix)-CORE-vnet"
$appSubnet = "$($locPrefix)-App-subnet"
$authSubnet = "$($locPrefix)-Authn-subnet"
$dataSubnet = "$($locPrefix)-Data-subnet"
$dmzSubnet = "$($locPrefix)-DMZ-subnet"

# New Resource Group
New-AzureRmResourceGroup -Name $resourceGroup -Location $location -Force

# NSG rules
$rdpRule = New-AzureRmNetworkSecurityRuleConfig -Name "rdp-rule" -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 `
    -SourceAddressPrefix "VirtualNetwork" -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389

# Network security group
$appNsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location -Name "$($appSubnet)-nsg"
$authNsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location -Name "$($authSubnet)-nsg"
$dataNsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location -Name "$($dataSubnet)-nsg"
$dmzNsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location -Name "$($dmzSubnet)-nsg"

# Subnets
$gatewaySubnetCfg = New-AzureRmVirtualNetworkSubnetConfig -Name $gateway -AddressPrefix $gatewayAddress
$appSubnetCfg = New-AzureRmVirtualNetworkSubnetConfig -Name $appSubnet -AddressPrefix $appAddress -NetworkSecurityGroup $appNsg
$authSubnetCfg = New-AzureRmVirtualNetworkSubnetConfig -Name $authSubnet -AddressPrefix $authAddress -NetworkSecurityGroup $authNsg
$dataSubnetCfg = New-AzureRmVirtualNetworkSubnetConfig -Name $dataSubnet -AddressPrefix $dataAddress -NetworkSecurityGroup $dataNsg
$dmzSubnetCfg = New-AzureRmVirtualNetworkSubnetConfig -Name $dmzSubnet -AddressPrefix $dmzAddress -NetworkSecurityGroup $dmzNsg

# Virtual network
New-AzureRmVirtualNetwork -Name $virtualNetwork -ResourceGroupName $resourceGroup -Location $location -AddressPrefix $addressSpace `
    -Subnet $gatewaySubnetCfg, $appSubnetCfg, $authSubnetCfg, $dataSubnetCfg, $dmzSubnetCfg



## Virtual network gateway
# Australia East
$location = "AustraliaEast"
$locPrefix = "AuE"

# Australia Souteast
$location = "AustraliaSoutheast"
$locPrefix = "AuSE"


# Common variables
$gatewayName = "$locPrefix-vnetgateway"
$resourceGroup = "$($locPrefix)-vnet-rg"
$virtualNetwork = "$($locPrefix)-CORE-vnet"
$gpipConfig = "$locPrefix-gwipconfig1"

# Create public IP address
$gwpip = New-AzureRmPublicIpAddress -Name "$gatewayName-pip" -ResourceGroupName $resourceGroup -Location $location `
    -AllocationMethod Dynamic -Sku Basic -DomainNameLabel "sp-$($locPrefix.ToLower())-vnet" -IpAddressVersion IPv4

# Virtual network gateway configuration
$vnet = Get-AzureRmVirtualNetwork -Name $virtualNetwork -ResourceGroupName $resourceGroup
$subnet = Get-AzureRmVirtualNetworkSubnetConfig -Name 'GatewaySubnet' -VirtualNetwork $vnet
$gwipconfig = New-AzureRmVirtualNetworkGatewayIpConfig -Name $gpipConfig -SubnetId $subnet.Id -PublicIpAddressId $gwpip.Id

# Create virtual network gateway
New-AzureRmVirtualNetworkGateway -Name $gatewayName -ResourceGroupName $resourceGroup -Location $location `
    -IpConfigurations $gwipconfig -GatewayType "Vpn" -VpnType "RouteBased" -GatewaySku "VpnGw1"


## Virtual Network Gateway Connections
# Australia East
$location = "AustraliaEast"
$locPrefix = "AuE"
$resourceGroup = "$($locPrefix)-vnet-rg"
$localNetName = "Sydney-localnetgwy"
$gatewayIpAddress = ""
$addressPrefix = @('192.168.1.0/24', '192.168.2.0/24', '192.168.3.0/24')
$connectionName = "AuECore-to-Sydney"
$sharedKey = ""
$routingWeight = 10

# Australia Southeast
$location = "AustraliaSoutheast"
$locPrefix = "AuSE"
$resourceGroup = "$($locPrefix)-vnet-rg"
$localNetName = "Melbourne-localnetgwy"
$gatewayIpAddress = ""
$addressPrefix = @('192.168.112.0/24')
$connectionName = "AuSECore-to-Melbourne"
$sharedKey = ""
$routingWeight = 10

# Virtual network gateway connections
$localNetworkGateway = New-AzureRmLocalNetworkGateway -Name $localNetName -ResourceGroupName $resourceGroup -Location $location `
    -GatewayIpAddress $GatewayIpAddress -AddressPrefix $addressPrefix

$virtualNetworkGateway = Get-AzureRmVirtualNetworkGateway -ResourceGroupName $resourceGroup -Name "$locPrefix-vnetgateway"

New-AzureRmVirtualNetworkGatewayConnection -Name $connectionName -ConnectionType IPsec -ResourceGroupName $resourceGroup `
    -Location $location -VirtualNetworkGateway1 $virtualNetworkGateway -LocalNetworkGateway2 $localNetworkGateway `
    -RoutingWeight $routingWeight -SharedKey $sharedKey


## Vnet Peering
$locPrefix = "AuE"
$resourceGroup = "$($locPrefix)-vnet-rg"
$virtualNetwork = "$($locPrefix)-CORE-vnet"
$virtualNetwork1 = Get-AzureRmVirtualNetwork -ResourceGroupName $resourceGroup -Name $virtualNetwork
$locPrefix = "AuSE"
$resourceGroup = "$($locPrefix)-vnet-rg"
$virtualNetwork = "$($locPrefix)-CORE-vnet"
$virtualNetwork2 = Get-AzureRmVirtualNetwork -ResourceGroupName $resourceGroup -Name $virtualNetwork

Add-AzureRmVirtualNetworkPeering -Name "AuE-AuSE-vnetpeer" `
    -VirtualNetwork $virtualNetwork1 `
    -RemoteVirtualNetworkId $virtualNetwork2.Id -AllowForwardedTraffic

Add-AzureRmVirtualNetworkPeering -Name "AuSE-AuE-vnetpeer" `
    -VirtualNetwork $virtualNetwork2 `
    -RemoteVirtualNetworkId $virtualNetwork1.Id -AllowForwardedTraffic


# Vnet Peering 2
$locPrefix = "AuE"
$resourceGroup = "$($locPrefix)-vnet-rg"
$virtualNetwork = "$($locPrefix)-CORE-vnet"
$virtualNetwork1 = Get-AzureRmVirtualNetwork -ResourceGroupName $resourceGroup -Name $virtualNetwork
$locPrefix = "EA"
$resourceGroup = "$($locPrefix)-vnet-rg"
$virtualNetwork = "$($locPrefix)-CORE-vnet"
$virtualNetwork2 = Get-AzureRmVirtualNetwork -ResourceGroupName $resourceGroup -Name $virtualNetwork

Add-AzureRmVirtualNetworkPeering -Name "AuE-EA-vnetpeer" `
    -VirtualNetwork $virtualNetwork1 `
    -RemoteVirtualNetworkId $virtualNetwork2.Id -AllowForwardedTraffic

Add-AzureRmVirtualNetworkPeering -Name "EA-AuE-vnetpeer" `
    -VirtualNetwork $virtualNetwork2 `
    -RemoteVirtualNetworkId $virtualNetwork1.Id -AllowForwardedTraffic




## Key Vault
# Australia East
$location = "AustraliaEast"
$locPrefix = "AuE"
$resourceGroup = "$($locPrefix)-secure-rg"
New-AzureRmResourceGroup -Name $resourceGroup -Location $location -Force
$keyVaultName = "stealthpuppy-$($locPrefix)-keyvault"

# Australia Southeast
$location = "AustraliaSoutheast"
$locPrefix = "AuSE"
$resourceGroup = "$($locPrefix)-secure-rg"
New-AzureRmResourceGroup -Name $resourceGroup -Location $location -Force
$keyVaultName = "stealthpuppy-$($locPrefix)-keyvault"

New-AzureRmKeyVault -Name $keyVaultName -ResourceGroupName $resourceGroup -Location $location -Sku Premium `
    -EnabledForDeployment -EnabledForDiskEncryption -EnabledForTemplateDeployment

# Add secrets to the vault
$secretvalue = ConvertTo-SecureString 'locuser' -AsPlainText -Force
$secret = Set-AzureKeyVaultSecret -VaultName "stealthpuppy-$($locPrefix)-keyvault" -Name 'localUser' -SecretValue $secretvalue

$secretvalue = ConvertTo-SecureString 'kXq8fdsfCdugfHdfd(LG7Tav' -AsPlainText -Force
$secret = Set-AzureKeyVaultSecret -VaultName "stealthpuppy-$($locPrefix)-keyvault" -Name 'localPass' -SecretValue $secretvalue

$secretvalue = ConvertTo-SecureString 'nDdaHfNkRsdfwerggdsyjty%$qffhsqMq*D9JTvqgNeMdrLLdfzBwTwfPHPFw2DM' -AsPlainText -Force
$secret = Set-AzureKeyVaultSecret -VaultName "stealthpuppy-$($locPrefix)-keyvault" -Name 'vnetGatewaySharedKey' -SecretValue $secretvalue


## Virtual machines
# Australia East
$location = "AustraliaEast"
$locPrefix = "AuE"
$virtualNetwork = "$($locPrefix)-CORE-vnet"
$resourceGroup = "$($locPrefix)-jumpbox-rg"
$keyVaultName = "stealthpuppy-$($locPrefix)-keyvault"
$image = "win2016datacenter"
$vmName = "$($locPrefix)jumpbox1"
$adminUser = (Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name localUser).SecretValueText
$adminPass = (Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name localPass).SecretValue
$nicName = "$($vmName)-nic001"
$vmSize = "Standard_B1s"
$timeZone = "AUS Eastern Standard Time"

New-AzureRmResourceGroup -Name "$($locPrefix)-Diagnostics-rg" -Location $location -Force
$diagStorageAccount = New-AzureRmStorageAccount -Name "rc$($locPrefix.ToLower())vmdiagstoracc" `
    -ResourceGroupName "$($locPrefix)-Diagnostics-rg" -Location $location -EnableHttpsTrafficOnly $True `
    -Kind "Storage" -SkuName "Standard_LRS"

$vnet = Get-AzureRmVirtualNetwork -Name $virtualNetwork -ResourceGroupName "$($locPrefix)-vnet-rg"
$pip = New-AzureRmPublicIpAddress -Name "$vmName-pip" -ResourceGroupName $resourceGroup -Location $location `
    -AllocationMethod Dynamic -Sku Basic -DomainNameLabel "rc-$($vmName.ToLower())" -IpAddressVersion IPv4
$nic = New-AzureRmNetworkInterface -Name $nicName -ResourceGroupName $resourceGroup -Location $location `
    -SubnetId $vnet.Subnets[1].Id -PublicIpAddressId $pip.Id

$credential = New-Object System.Management.Automation.PSCredential ($adminUser, $adminPass)

$virtualMachine = New-AzureRmVMConfig -VMName $vmName -VMSize $vmSize
$virtualMachine = Set-AzureRmVMOperatingSystem -VM $virtualMachine -Windows -ComputerName $vmName `
    -Credential $credential -ProvisionVMAgent -EnableAutoUpdate -TimeZone $timeZone
$virtualMachine = Add-AzureRmVMNetworkInterface -VM $virtualMachine -Id $nic.Id
$virtualMachine = Set-AzureRmVMSourceImage -VM $virtualMachine -PublisherName 'MicrosoftWindowsServer' `
    -Offer 'WindowsServer' -Skus '2019-Datacenter' -Version latest
New-AzureRmVM -ResourceGroupName $resourceGroup -Location $location -VM $virtualMachine -Verbose


# Australia Southeast
$location = "AustraliaSoutheast"
$locPrefix = "AuSE"
New-AzureRmResourceGroup -Name "$($locPrefix)-Diagnostics-rg" -Location $location -Force
$diagStorageAccount = New-AzureRmStorageAccount -Name "rc$($locPrefix.ToLower())vmdiagstoracc" `
    -ResourceGroupName "$($locPrefix)-Diagnostics-rg" -Location $location -EnableHttpsTrafficOnly $True `
    -Kind "Storage" -SkuName "Standard_LRS"



# Virtual Machines
$location = "AustraliaEast"
$locPrefix = "AuE"

$location = "AustraliaSoutheast"
$locPrefix = "AuSE"

$resourceGroup = "$($locPrefix)-Authn-rg"
New-AzureRmResourceGroup -Name $resourceGroup -Location $location -Force
New-AzureRmAvailabilitySet -ResourceGroupName $resourceGroup -Name "$($locPrefix)-Authn-as" -Location $location `
    -Sku aligned -PlatformFaultDomainCount 2 -PlatformUpdateDomainCount 5



# Virtual Machines
$location = "AustraliaEast"
$locPrefix = "AuE"

$location = "AustraliaSoutheast"
$locPrefix = "AuSE"

$resourceGroup = "$($locPrefix)-Authn-rg"
New-AzureRmResourceGroup -Name $resourceGroup -Location $location -Force
New-AzureRmAvailabilitySet -ResourceGroupName $resourceGroup -Name "$($locPrefix)-Authn-as" -Location $location `
    -Sku aligned -PlatformFaultDomainCount 2 -PlatformUpdateDomainCount 5


# Tags
Get-AzureRmResourceGroup -Location AustraliaEast | Set-AzureRmResourceGroup -Tag @{ Role = ""; Environment = "Production"; Contains = "" }
Get-AzureRmResourceGroup -Location AustraliaSouthEast | Set-AzureRmResourceGroup -Tag @{ Role = ""; Environment = "Production"; Contains = "" }

$a = Get-AzureRmStorageAccount
$r = Get-AzureRmResource -ResourceName $a.StorageAccountName -ResourceGroupName $a.ResourceGroupName
Set-AzureRmResource -Tag @{ Role = "Diagnostics"; Environment = "Production"; Contains = "VM diagnostics data" } -ResourceId $r.ResourceId -Force

$vaults = Get-AzureRmKeyVault
ForEach ($vault in $vaults) {
    $r = Get-AzureRmResource -ResourceName $vault.VaultName -ResourceGroupName $vault.ResourceGroupName
    Set-AzureRmResource -Tag @{ Role = "Security"; Environment = "Production"; Contains = "Secrets" } -ResourceId $r.ResourceId -Force
}

$groups = Get-AzureRmNetworkSecurityGroup
ForEach ($group in $groups) {
    $r = Get-AzureRmResource -ResourceName $group.Name -ResourceGroupName $group.ResourceGroupName
    Set-AzureRmResource -Tag @{ Role = "Security"; Environment = "Production" } -ResourceId $r.ResourceId -Force
}

$networks = Get-AzureRmVirtualNetwork
ForEach ($network in $networks) {
    $r = Get-AzureRmResource -ResourceName $network.Name -ResourceGroupName $network.ResourceGroupName
    Set-AzureRmResource -Tag @{ Environment = "Production" } -ResourceId $r.ResourceId -Force
}

$r = Get-AzureRmResource -ResourceName "AuE-vnetgateway" -ResourceGroupName "aue-vnet-rg"
Set-AzureRmResource -Tag @{ Environment = "Production" } -ResourceId $r.ResourceId -Force


# Static IP
$resourceGroups = @("AuE-Authn-rg", "AuSE-Authn-rg")
ForEach ($resourceGroup in $resourceGroups) {
    $nics = Get-AzureRmNetworkInterface -ResourceGroupName $resourceGroup
    ForEach ($nic in $nics) {
        $nic.IpConfigurations[0].PrivateIpAllocationMethod = "Static"
        Set-AzureRmNetworkInterface -NetworkInterface $nic
    }
}


# Log Analytics
(manual configuration)

# Automation account
New-AzureRmAutomationAccount -ResourceGroupName "AuSE-LogAnalytics-rg" -Name "AuSE-LogAnalytics-AutomationAccount" -Location "AustraliaSoutheast" -Plan "Basic" -Verbose


# Recovery Services Vault
$location = "AustraliaEast"
$resourceGroup = "AuE-RecoveryVaults-rg"
New-AzureRmResourceGroup -Name $resourceGroup -Location $location -Force
New-AzureRmRecoveryServicesVault -Location $location -Name "AuE-AD-RecoveryVault" -ResourceGroupName $resourceGroup
New-AzureRmRecoveryServicesVault -Location $location -Name "AuE-AppData-RecoveryVault" -ResourceGroupName $resourceGroup

$location = "AustraliaSoutheast"
$resourceGroup = "AuSE-RecoveryVaults-rg"
New-AzureRmResourceGroup -Name $resourceGroup -Location $location -Force
New-AzureRmRecoveryServicesVault -Location $location -Name "AuSE-AD-RecoveryVault" -ResourceGroupName $resourceGroup
New-AzureRmRecoveryServicesVault -Location $location -Name "AuSE-AppData-RecoveryVault" -ResourceGroupName $resourceGroup


## Encrypt virtual machines
# Australia East
$keyVault = 'stealthpuppy-AuE-keyvault'
$appName = "VmDiskEncryption"
$secret = "vmDiskEncryptionServicePrincipalPassword"
$securePassword = (Get-AzureKeyVaultSecret -VaultName $keyVault -Name $secret).SecretValue
$app = New-AzureRmADApplication -DisplayName $appName `
    -HomePage "https://vmencryption.stealthpuppy.com" `
    -IdentifierUris "https://stealthpuppy.com/vmencryption" `
    -Password $securePassword
New-AzureRmADServicePrincipal -ApplicationId $app.ApplicationId

Set-AzureRmKeyVaultAccessPolicy -VaultName $keyVault `
    -ServicePrincipalName $app.ApplicationId `
    -PermissionsToKeys "WrapKey" `
    -PermissionsToSecrets "Set"

Add-AzureKeyVaultKey -VaultName $keyVault -Name "diskEncryption" -Destination "HSM"

# Encrypt VM in Australia East
$rgName = "AuE-Authn-rg"
$vmName = "AuE-AAD01"
$kVault = Get-AzureRmKeyVault -VaultName $keyVault
$diskEncryptionKeyVaultUrl = $kVault.VaultUri
$keyVaultResourceId = $kVault.ResourceId
$keyEncryptionKeyUrl = (Get-AzureKeyVaultKey -VaultName $keyVault -Name "diskEncryption").Key.kid

Set-AzureRmVMDiskEncryptionExtension -ResourceGroupName $rgName `
    -VMName $vmName `
    -AadClientID $app.ApplicationId `
    -AadClientSecret (New-Object PSCredential "user", $securePassword).GetNetworkCredential().Password `
    -DiskEncryptionKeyVaultUrl $diskEncryptionKeyVaultUrl `
    -DiskEncryptionKeyVaultId $keyVaultResourceId `
    -KeyEncryptionKeyUrl $keyEncryptionKeyUrl `
    -KeyEncryptionKeyVaultId $keyVaultResourceId -Verbose


# Australia Southeast
$keyVault = 'stealthpuppy-AuE-keyvault'
$securePassword = (Get-AzureKeyVaultSecret -VaultName $keyVault -Name $secret).SecretValue
$keyVault = 'stealthpuppy-AuSE-keyvault'
$appName = "VmDiskEncryption"
$app = Get-AzureRmADApplication -DisplayName $appName
Set-AzureRmKeyVaultAccessPolicy -VaultName $keyVault `
    -ServicePrincipalName $app.ApplicationId `
    -PermissionsToKeys "WrapKey" `
    -PermissionsToSecrets "Set"
Add-AzureKeyVaultKey -VaultName $keyVault -Name "diskEncryption" -Destination "HSM"

# Encrypt VM in Australia Southast
$rgName = "AuSE-Authn-rg"
$vmName = "AuSE-AAD01"
$vmName = "AuSE-DC01"
$kVault = Get-AzureRmKeyVault -VaultName $keyVault
$diskEncryptionKeyVaultUrl = $kVault.VaultUri
$keyVaultResourceId = $kVault.ResourceId
$keyEncryptionKeyUrl = (Get-AzureKeyVaultKey -VaultName $keyVault -Name "diskEncryption").Key.kid

Set-AzureRmVMDiskEncryptionExtension -ResourceGroupName $rgName `
    -VMName $vmName `
    -AadClientID $app.ApplicationId `
    -AadClientSecret (New-Object PSCredential "user", $securePassword).GetNetworkCredential().Password `
    -DiskEncryptionKeyVaultUrl $diskEncryptionKeyVaultUrl `
    -DiskEncryptionKeyVaultId $keyVaultResourceId `
    -KeyEncryptionKeyUrl $keyEncryptionKeyUrl `
    -KeyEncryptionKeyVaultId $keyVaultResourceId -Verbose


# Enable Windows Server Core BDE
net use \\server\ipc$ /user:rmuser
robocopy \\server\admin$\system32 %SystemRoot%\system32 bdehdcfg.exe
robocopy \\server\admin$\system32 %SystemRoot%\system32 bdehdcfglib.dll
robocopy \\server\admin$\system32\en-US %SystemRoot%\system32\en-US bdehdcfglib.dll.mui
robocopy \\server\admin$\system32\en-US %SystemRoot%\system32\en-US bdehdcfg.exe.mui
bdehdcfg.exe -target default


## Azure AD Connect
Get-NetFirewallRule -DisplayGroup 'File and Printer Sharing' | Set-NetFirewallRule -Profile 'Private, Domain' -Enabled True -PassThru `
    | Select-Object Name, DisplayName, Enabled, Profile | Format-Table -Auto
"F:\Temp\AzureADConnect.msi"
"C:\Program Files\Microsoft Azure Active Directory Connect\AzureADConnect.exe"

Get-ADSyncServerConfiguration -Path "C:\Temp\Migrate"


# Azure Site Recovery
# Australia East
$location = "AustraliaEast"
$locPrefix = "AuE"
$virtualNetwork = "$($locPrefix)-CORE-vnet"
$resourceGroup = "$($locPrefix)-VirtualMachineStorage-rg"
$storageAccountName = $("rc$($locPrefix)vm01storacc").ToLower()

New-AzureRmResourceGroup -Name $resourceGroup -Location $location -Force -Verbose

$storageAccount = New-AzureRmStorageAccount -Name $storageAccountName `
    -ResourceGroupName $resourceGroup -Location $location -EnableHttpsTrafficOnly $True `
    -Kind "Storage" -SkuName "Standard_GRS" -Verbose

# Azure Migrate Rg
New-AzureRmResourceGroup -Name "AuE-AzureMigrate-rg" -Location $location -Force -Verbose


Get-AzureRmADServicePrincipal | Where-Object { $_.DisplayName -like "Backup Management Service" }
Set-AzureRmKeyVaultAccessPolicy -VaultName 'Contoso03Vault' -ServicePrincipalName 'http://payroll.contoso.com' -PermissionsToSecrets Get, Set


## Test Network
$location = "AustraliaEast"
$locPrefix = "AuE"
$addressSpace = "10.20.0.0/16"
$gatewayAddress = "10.20.0.0/27"
$dmzAddress = "10.20.1.0/27"
$authAddress = "10.20.2.0/24"
$dataAddress = "10.20.3.0/24"
$appAddress = "10.20.4.0/24"

# Common variables
$gateway = "GatewaySubnet"
$resourceGroup = "$($locPrefix)-vnet-FailoverTest-rg"
$virtualNetwork = "$($locPrefix)-CORE-FailoverTest-vnet"
$appSubnet = "$($locPrefix)-App-subnet"
$authSubnet = "$($locPrefix)-Authn-subnet"
$dataSubnet = "$($locPrefix)-Data-subnet"
$dmzSubnet = "$($locPrefix)-DMZ-subnet"

# New Resource Group
New-AzureRmResourceGroup -Name $resourceGroup -Location $location -Force

# Network security group
$appNsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location -Name "$($appSubnet)-nsg" -SecurityRules $rdpRule
$authNsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location -Name "$($authSubnet)-nsg" -SecurityRules $rdpRule
$dataNsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location -Name "$($dataSubnet)-nsg" -SecurityRules $rdpRule
$dmzNsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location -Name "$($dmzSubnet)-nsg" -SecurityRules $rdpRule

# Subnets
$gatewaySubnetCfg = New-AzureRmVirtualNetworkSubnetConfig -Name $gateway -AddressPrefix $gatewayAddress
$appSubnetCfg = New-AzureRmVirtualNetworkSubnetConfig -Name $appSubnet -AddressPrefix $appAddress -NetworkSecurityGroup $appNsg
$authSubnetCfg = New-AzureRmVirtualNetworkSubnetConfig -Name $authSubnet -AddressPrefix $authAddress -NetworkSecurityGroup $authNsg
$dataSubnetCfg = New-AzureRmVirtualNetworkSubnetConfig -Name $dataSubnet -AddressPrefix $dataAddress -NetworkSecurityGroup $dataNsg
$dmzSubnetCfg = New-AzureRmVirtualNetworkSubnetConfig -Name $dmzSubnet -AddressPrefix $dmzAddress -NetworkSecurityGroup $dmzNsg

# Virtual network
New-AzureRmVirtualNetwork -Name $virtualNetwork -ResourceGroupName $resourceGroup -Location $location -AddressPrefix $addressSpace `
    -Subnet $gatewaySubnetCfg, $appSubnetCfg, $authSubnetCfg, $dataSubnetCfg, $dmzSubnetCfg

