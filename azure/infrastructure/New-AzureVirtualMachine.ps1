#Requires -Module Az
# Dot source Export-Variables.ps1 first

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
