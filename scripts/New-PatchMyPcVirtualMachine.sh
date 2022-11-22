# Login and select the target subscription
az login --use-device-code
az account set --subscription 63e8f660-f6a4-4ac5-ad4e-623268509f20

# Create the resource group
az group create \
    --name rg-PatchMyPC-AustraliaEast \
    --location AustraliaEast \
    --tags environment=production function=PatchMyPc

# Create the network security group
az network nsg create \
  --resource-group rg-PatchMyPC-AustraliaEast \
  --name nsg-pmp \
  --tags environment=production function=PatchMyPc

# Create the virtual network with a single subnet
az network vnet create \
  --name vnet-PatchMyPC-AustraliaEast \
  --location AustraliaEast \
  --resource-group rg-PatchMyPC-AustraliaEast \
  --address-prefix 10.0.0.0/16 \
  --subnet-name subnet-pmp \
  --subnet-prefixes 10.0.0.0/24 \
  --network-security-group nsg-pmp \
  --tags environment=production function=PatchMyPc

# Enable the Microsoft.Storage service endpoint for the subnet
az network vnet subnet update \
  --vnet-name vnet-PatchMyPC-AustraliaEast \
  --resource-group rg-PatchMyPC-AustraliaEast \
  --name subnet-pmp \
  --service-endpoints Microsoft.Storage

# Create a storage account for VM diags
az storage account create \
  --name sadiagspmpaue \
  --resource-group rg-PatchMyPC-AustraliaEast \
  --location AustraliaEast \
  --sku Standard_LRS \
  --allow-blob-public-access false \
  --bypass AzureServices \
  --default-action Deny \
  --encryption-key-source Microsoft.Storage \
  --https-only true \
  --min-tls-version TLS1_2 \
  --public-network-access Disabled \
  --subnet subnet-pmp \
  --vnet-name vnet-PatchMyPC-AustraliaEast \
  --tags environment=production function=PatchMyPc

# Create a public IP address
az network public-ip create \
  --name pmp01-pip \
  --resource-group rg-PatchMyPC-AustraliaEast \
  --location AustraliaEast \
  --allocation-method Dynamic \
  --sku Basic \
  --tags environment=production function=PatchMyPc

# Create a NIC for the VM
az network nic create \
  --name pmp01-nic01 \
  --resource-group rg-PatchMyPC-AustraliaEast \
  --location AustraliaEast \
  --vnet-name vnet-PatchMyPC-AustraliaEast \
  --subnet subnet-pmp \
  --public-ip-address pmp01-pip \
  --tags environment=production function=PatchMyPc

# Create the virtual machine
az vm create \
  --resource-group rg-PatchMyPC-AustraliaEast \
  --name pmp01 \
  --location AustraliaEast \
  --admin-password 'dX63saQYXxeUwCiQ' \
  --admin-username rmuser \
  --boot-diagnostics-storage sadiagspmpaue \
  --image 'MicrosoftWindowsServer:WindowsServer:2022-datacenter-azure-edition:latest' \
  --size Standard_B2s \
  --nics pmp01-nic01 \
  --security-type TrustedLaunch \
  --enable-secure-boot true \
  --enable-vtpm true \
  --tags environment=production function=PatchMyPc

# Enable Azure AD sign-in
az vm extension set \
    --publisher Microsoft.Azure.ActiveDirectory \
    --name AADLoginForWindows \
    --resource-group rg-PatchMyPC-AustraliaEast \
    --vm-name pmp01

# Enable the IaaS anti-malware extension
az vm extension set \
    --publisher Microsoft.Azure.Security \
    --name IaaSAntimalware \
    --resource-group rg-PatchMyPC-AustraliaEast \
    --vm-name pmp01

# Download and install the PMP Publisher
az vm run-command invoke \
    --command-id RunPowerShellScript \
    --name pmp01 \
    --resource-group rg-PatchMyPC-AustraliaEast \
    --scripts 'md C:\Temp' \
    'iwr -Uri https://patchmypc.com/scupcatalog/downloads/publishingservice/PatchMyPC-Publishing-Service.msi -OutFile C:\Temp\PatchMyPC-Publishing-Service.msi -UseBasicParsing' \
    'Install-WindowsFeature -Name UpdateServices-API' \
    'msiexec /i C:\Temp\PatchMyPC-Publishing-Service.msi INTUNEONLYMODE=1 RUNAPPLICATION=0 /qn'

# Show the public IP address of the new VM
az network public-ip show \
  --resource-group rg-PatchMyPC-AustraliaEast  \
  --name pmp01-pip \
  --query ipAddress \
  --output tsv
