az login --use-device-code
az account set --subscription 63e8f660-f6a4-4ac5-ad4e-623268509f20

az deployment group create --resource-group "rg-HubNetworkInfrastructure-AustraliaSoutheast" \
    --template-file ./update-management.json \
    --parameters ./update-management.parameters.json


az deployment group create --resource-group "rg-WindowsVirtualDesktopInfrastructure-AustraliaEast" \
    --template-file /Users/aaron/Projects/azure/bicep/wvd-workspace.json \
    --parameters /Users/aaron/Projects/azure/bicep/wvd-workspace.parameters.json


az deployment group create --resource-group "rg-WindowsVirtualDesktopPersonal-AustraliaEast" \
    --template-file /Users/aaron/Projects/azure/wvd/personal-hostpool/template.json \
    --parameters /Users/aaron/Projects/azure/wvd/personal-hostpool/parameters.json

