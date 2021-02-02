#Requires -Module Az
# Dot source Export-Variables.ps1 first

## Virtual machines
# Australia East

$image = "win2016datacenter"

$vmName = "$($locPrefix)jumpbox1"
$adminUser = (Get-AzKeyVaultSecret -VaultName $KeyVault -Name localUser).SecretValueText
$adminPass = (Get-AzKeyVaultSecret -VaultName $KeyVault -Name localPass).SecretValue
$nicName = "$($vmName)-nic001"
$vmSize = "Standard_B1s"
$timeZone = "AUS Eastern Standard Time"



$nic = New-AzNetworkInterface -Name $nicName -ResourceGroupName $resourceGroup -Location $location `
    -SubnetId $vnet.Subnets[1].Id -PublicIpAddressId $pip.Id

$credential = New-Object System.Management.Automation.PSCredential ($adminUser, $adminPass)

$virtualMachine = New-AzVMConfig -VMName $vmName -VMSize $vmSize
$virtualMachine = Set-AzVMOperatingSystem -VM $virtualMachine -Windows -ComputerName $vmName `
    -Credential $credential -ProvisionVMAgent -EnableAutoUpdate -TimeZone $timeZone
$virtualMachine = Add-AzVMNetworkInterface -VM $virtualMachine -Id $nic.Id
$virtualMachine = Set-AzVMSourceImage -VM $virtualMachine -PublisherName 'MicrosoftWindowsServer' `
    -Offer 'WindowsServer' -Skus '2019-Datacenter' -Version latest
New-AzVM -ResourceGroupName $resourceGroup -Location $location -VM $virtualMachine -Verbose



$VMLocalAdminUser = "LocalAdminUser"
$VMLocalAdminSecurePassword = ConvertTo-SecureString  -AsPlainText -Force
$LocationName = "westus"
$ResourceGroupName = "MyResourceGroup"
$ComputerName = "MyVM"
$VMName = "MyVM"
$VMSize = "Standard_DS3"

$NetworkName = "MyNet"
$NICName = "MyNIC"
$SubnetName = "MySubnet"
$SubnetAddressPrefix = "10.0.0.0/24"
$VnetAddressPrefix = "10.0.0.0/16"

$SingleSubnet = New-AzVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetAddressPrefix
$Vnet = New-AzVirtualNetwork -Name $NetworkName -ResourceGroupName $ResourceGroupName -Location $LocationName -AddressPrefix $VnetAddressPrefix -Subnet $SingleSubnet
$NIC = New-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -Location $LocationName -SubnetId $Vnet.Subnets[0].Id

$Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword);

$VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize
$VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $ComputerName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
$VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
$VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' -Skus '2012-R2-Datacenter' -Version latest

New-AzVM -ResourceGroupName $ResourceGroupName -Location $LocationName -VM $VirtualMachine -Verbose