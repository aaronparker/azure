az account set --subscription 63e8f660-f6a4-4ac5-ad4e-623268509f20
az deployment group create --resource-group "rg-HubNetworkInfrastructure-AustraliaSoutheast" \
    --template-file ./update-management.json \
    --parameters ./update-management.parameters.json
