az login --use-device-code
az account set --subscription "23bf9984-442a-4564-a599-c883a24e3e77"

az deployment group create --resource-group "rg-DomainControllers-AustraliaEast" \
    --template-file ./virtualmachine.json \
    --parameters ./parameters-adc2aue.json
