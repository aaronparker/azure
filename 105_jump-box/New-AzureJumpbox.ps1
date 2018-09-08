## Virtual machines
$locations = @("AustraliaSoutheast")
ForEach ($location in $locations) {

    # Common variables
    $resourceGroup = "Core-Vnet-$($location)-rg"
    $virtualNetwork = "Core-$($location)-vnet"
    $jumpSubnet = "Jumpbox-$($location)-subnet"
    $resourceGroup = "Jumpbox-$($location)-rg"
    $keyVaultName = "AusSE-keyvault"
    $image = "win2016datacenter"
    $vmName = "jumpbox01"
    $adminUser = (Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name localUser).SecretValueText
    $adminPass = (Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name localPass).SecretValue
    $nicName = "$($vmName)-nic01"
    $vmSize = "Standard_B2s"
    $timeZone = "AUS Eastern Standard Time"
    $diagStorageAccount = "slthvmdiagsause"

    $vnet = Get-AzureRmVirtualNetwork -Name $virtualNetwork -ResourceGroupName "Core-Vnet-$($location)-rg"
    $subnetId = ($vnet.subnets | Where-Object { $_.Name -like "Jumpbox-$($location)-subnet" }).Id

    If (!(Get-AzureRmResourceGroup -Name $resourceGroup -ErrorAction SilentlyContinue)) {
        Write-Verbose "Resource group '$resourceGroup' does not exist.";
        Write-Verbose "Creating resource group '$resourceGroup' in location '$location'";
        New-AzureRmResourceGroup -Name $resourceGroup -Location $location
    }
    Else {
        Write-Verbose "Using existing resource group '$resourceGroupName'";
    }

    $pip = New-AzureRmPublicIpAddress -Name "$vmName-pip" -ResourceGroupName $resourceGroup -Location $location `
        -AllocationMethod Dynamic -Sku Basic -DomainNameLabel "st-$($vmName.ToLower())" -IpAddressVersion IPv4

    $nic = New-AzureRmNetworkInterface -Name $nicName -ResourceGroupName $resourceGroup -Location $location `
        -SubnetId $subnetId -PublicIpAddressId $pip.Id

    $credential = New-Object System.Management.Automation.PSCredential ($adminUser, $adminPass)

    $virtualMachine = New-AzureRmVMConfig -VMName $vmName -VMSize $vmSize
    $virtualMachine = Set-AzureRmVMOperatingSystem -VM $virtualMachine -Windows -ComputerName $vmName `
        -Credential $credential -ProvisionVMAgent -EnableAutoUpdate -TimeZone $timeZone
    $virtualMachine = Add-AzureRmVMNetworkInterface -VM $virtualMachine -Id $nic.Id
    $virtualMachine = Set-AzureRmVMSourceImage -VM $virtualMachine -PublisherName 'MicrosoftWindowsServer' `
        -Offer 'WindowsServer' -Skus '2016-Datacenter' -Version latest

    $vm = New-AzureRmVM -ResourceGroupName $resourceGroup -Location $location -VM $virtualMachine
    Write-Output $vm
}