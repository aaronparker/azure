<#
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $False)]
    [string] $Location = 'AustraliaSoutheast',

    [Parameter(Mandatory = $False)]
    [string] $KeyVault = "AusSE-keyvault",

    [Parameter(Mandatory = $False)]
    [string] $AppName = "Packer",

    [Parameter(Mandatory = $False)]
    [string] $Secret = "packerServicePrincipalPassword",

    [Parameter(Mandatory = $False)]
    [string] $SubscriptionID = (Get-AzureRmSubscription).Id
)

$securePassword = (Get-AzureKeyVaultSecret -VaultName $KeyVault -Name $Secret).SecretValue

$app = New-AzureRmADApplication -DisplayName $appName `
    -HomePage "https://packer.home.stealthpuppy.com" `
    -IdentifierUris "https://home.stealthpuppy.com/packer" `
    -Password $securePassword
$servicePrincipal = New-AzureRmADServicePrincipal -ApplicationId $app.ApplicationId

$roleAssignment = New-AzureRmRoleAssignment -ApplicationId $servicePrincipal.ApplicationId -RoleDefinitionName Owner -Scope ("/subscriptions/$SubscriptionID") -Verbose

Write-Output $servicePrincipal, $roleAssignment
