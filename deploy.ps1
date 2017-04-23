<#
 .SYNOPSIS
    Deploys a template to Azure

 .DESCRIPTION
    Deploys an Azure Resource Manager template

 .PARAMETER resourceGroupName
    The resource group where the template will be deployed. Can be the name of an existing or a new resource group.

 .PARAMETER resourceGroupLocation
    Optional, a resource group location. If specified, will try to create a new resource group in this location. If not specified, assumes resource group is existing.

 .PARAMETER deploymentName
    The deployment name.

 .PARAMETER templateFilePath
    Optional, path to the template file. Defaults to template.json.

 .PARAMETER parametersFilePath
    Optional, path to the parameters file. Defaults to parameters.json. If file is not found, will prompt for parameter values based on template.
#>

param(
    [Parameter(Mandatory=$False)]
    [string]$subscriptionId,

    [Parameter(Mandatory=$False)]
    [string]$resourceGroupName = "Core-AuSE_rg",

    [Parameter(Mandatory=$False)]
    [string]$resourceGroupLocation = "australiasoutheast",

    [Parameter(Mandatory=$False)]
    [string]$deploymentName,

    [Parameter(Mandatory=$False)]
    [string]$templateFilePath = ".\azuredeploy.json",

    [Parameter(Mandatory=$False)]
    [string]$parametersFilePath = ".\azuredeploy.parameters.json"
)

<#
.SYNOPSIS
    Registers RPs
#>
Function RegisterRP {
    Param(
        [string]$ResourceProviderNamespace
    )

    Write-Host "Registering resource provider '$ResourceProviderNamespace'";
    Register-AzureRmResourceProvider -ProviderNamespace $ResourceProviderNamespace;
}

#******************************************************************************
# Script body
# Execution begins here
#******************************************************************************
$ErrorActionPreference = "Stop"

# Register RPs
$resourceProviders = @("microsoft.compute","microsoft.storage","microsoft.network");
If ($resourceProviders.length) {
    Write-Host "Registering resource providers"
    ForEach ($resourceProvider in $resourceProviders) {
        RegisterRP($resourceProvider);
    }
}

#Create or check for existing resource group
$resourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
If (!$resourceGroup) {
    Write-Host "Resource group '$resourceGroupName' does not exist. To create a new resource group, please enter a location.";
    If (!$resourceGroupLocation) {
        $resourceGroupLocation = Read-Host "resourceGroupLocation";
    }
    Write-Host "Creating resource group '$resourceGroupName' in location '$resourceGroupLocation'";
    New-AzureRmResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation
} Else {
    Write-Host "Using existing resource group '$resourceGroupName'";
}

$dirs = Get-ChildItem -Attribute Directory
ForEach ($dir in $dirs) {
    If ((Test-Path("$($dir.FullName)\azuredeploy.json")) -and (Test-Path("$($dir.FullName)\azuredeploy.parameters.json"))) {
        
        Write-Host "Testing deployment..."
        Test-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile "$($dir.FullName)\azuredeploy.json" -TemplateParameterFile "$($dir.FullName)\azuredeploy.parameters.json" -Verbose

        Write-Host "Starting deployment..."
        New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile "$($dir.FullName)\azuredeploy.json" -TemplateParameterFile "$($dir.FullName)\azuredeploy.parameters.json" -Verbose
    }
}


#        "networkSecurityGroupName2": {
#            "value": "[concat(parameters('subnet2Name'),'_nsg')]"
#        }
