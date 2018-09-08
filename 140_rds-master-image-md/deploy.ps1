<#
 .SYNOPSIS
    Deploys a template to Azure

 .DESCRIPTION
    Deploys an Azure Resource Manager template

 .PARAMETER subscriptionId
    The subscription id where the template will be deployed.

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
[CmdletBinding()]
param(
    [Parameter(Mandatory = $False)]
    [string] $subscriptionId = (Get-AzureRmSubscription).Id,

    [Parameter(Mandatory = $False)]
    [string] $resourceGroupLocation = "AustraliaSoutheast",

    [Parameter(Mandatory = $False)]
    [string] $resourceGroupName = "MasterImage-$resourceGroupLocation-rg",

    [Parameter(Mandatory = $False)]
    [string] $deploymentName = "masterImage",

    [Parameter(Mandatory = $False)]
    [string] $templateFilePath = "azuredeploy.json",

    [Parameter(Mandatory = $False)]
    [string] $parametersFilePath = "azuredeploy.parameters.json"
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
$resourceProviders = @("microsoft.compute", "microsoft.resources", "microsoft.devtestlab", "microsoft.storage", "microsoft.network");
if ($resourceProviders.length) {
    Write-Verbose "Registering resource providers"
    foreach ($resourceProvider in $resourceProviders) {
        RegisterRP($resourceProvider);
    }
}

#Create or check for existing resource group
$resourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if (!$resourceGroup) {
    Write-Verbose "Resource group '$resourceGroupName' does not exist.";
    Write-Verbose "Creating resource group '$resourceGroupName' in location '$resourceGroupLocation'";
    New-AzureRmResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation
}
else {
    Write-Verbose "Using existing resource group '$resourceGroupName'";
}

# Start the deployment
Write-Verbose "Starting deployment...";
if (Test-Path $parametersFilePath) {
    Write-Verbose "Using template $templateFilePath with parameters from $parametersFilePath."
    New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath -TemplateParameterFile $parametersFilePath;
}
else {
    Write-Verbose "Using template $templateFilePath with no parameters file."
    New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath;
}
