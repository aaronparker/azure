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

# Retreive password from the Key Vault
$securePassword = (Get-AzureKeyVaultSecret -VaultName $KeyVault -Name $Secret).SecretValue

# Create the enterprise application and service principal for Packer
$app = New-AzureRmADApplication -DisplayName $appName `
    -HomePage "https://packer.home.stealthpuppy.com" `
    -IdentifierUris "https://home.stealthpuppy.com/packer" `
    -Password $securePassword
$servicePrincipal = New-AzureRmADServicePrincipal -ApplicationId $app.ApplicationId

# Wait while the service principal is created; wait after service principal has been created to be sure
While (!(Get-AzureRmADServicePrincipal | Where-Object { $_.DisplayName -like "Packer" })) {
    Start-Sleep 10
}
Start-Sleep 30

# Assign subscription owner to the service principal [! Fix with rights actually needed by Packer]
$roleAssignment = New-AzureRmRoleAssignment -ApplicationId $servicePrincipal.ApplicationId -RoleDefinitionName Owner -Scope ("/subscriptions/$SubscriptionID") -Verbose

# Return output
Write-Output $servicePrincipal, $roleAssignment
