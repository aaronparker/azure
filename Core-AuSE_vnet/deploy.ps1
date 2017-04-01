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

param(
    [Parameter(Mandatory=$False)]
    [string]$subscriptionId,

    [Parameter(Mandatory=$False)]
    [string]$resourceGroupName,

    [Parameter(Mandatory=$False)]
    [string]$resourceGroupLocation = "australiasoutheast",

    [Parameter(Mandatory=$False)]
    [string]$deploymentName,

    [Parameter(Mandatory=$False)]
    [string]$templateFilePath = ".\template.json",

    [Parameter(Mandatory=$False)]
    [string]$parametersFilePath = ".\parameters.json"
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

# sign in
Write-Host "Logging in...";
# Login-AzureRmAccount;
$Username = 'user@account.com'
$Password = 'password'
$SecurePassword = convertto-securestring -String $Password -AsPlainText -Force
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $Username, $SecurePassword

# $RmLogin = Login-AzureRmAccount -Credential $cred
# $Subscription = Select-AzureRmSubscription -SubscriptionName $RmLogin.Context.Subscription.SubscriptionName -TenantId $RmLogin.Context.Subscription.TenantId


# select subscription
# Write-Host "Selecting subscription '$subscriptionId'";
# Select-AzureRmSubscription -SubscriptionID $subscriptionId;
Write-Host "Selecting subscription"
$RmLogin = Login-AzureRmAccount
$Subscription = Select-AzureRmSubscription -SubscriptionName $RmLogin.Context.Subscription.SubscriptionName -TenantId $RmLogin.Context.Subscription.TenantId

# Register RPs
$resourceProviders = @("microsoft.network");
if($resourceProviders.length) {
    Write-Host "Registering resource providers"
    foreach($resourceProvider in $resourceProviders) {
        RegisterRP($resourceProvider);
    }
}

#Create or check for existing resource group
$resourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if(!$resourceGroup)
{
    Write-Host "Resource group '$resourceGroupName' does not exist. To create a new resource group, please enter a location.";
    if(!$resourceGroupLocation) {
        $resourceGroupLocation = Read-Host "resourceGroupLocation";
    }
    Write-Host "Creating resource group '$resourceGroupName' in location '$resourceGroupLocation'";
    New-AzureRmResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation
}
else{
    Write-Host "Using existing resource group '$resourceGroupName'";
}

# Start the deployment
Write-Host "Starting deployment...";
New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath -TemplateParameterFile $parametersFilePath;
# if(Test-Path $parametersFilePath) {
#    New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath -TemplateParameterFile $parametersFilePath;
#} else {
#    New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath;
#}