<#
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $False)]
    [string] $KeyVault = "AusSE-keyvault",

    [Parameter(Mandatory = $False)]
    [string] $Secret = "packerServicePrincipalPassword",

    [Parameter(Mandatory = $False)]
    [string] $AppName = "Packer"
)

# Get subscription
$Subscription = (Get-AzureRmSubscription)

# Retreive password from the Key Vault
$securePassword = (Get-AzureKeyVaultSecret -VaultName $KeyVault -Name $Secret).SecretValueText

# Retreive the service principal
$app = Get-AzureRmADServicePrincipal | Where-Object { $_.DisplayName -like "Packer" }

$result = @{subscription_id = $Subscription.Id; tenant_id = $Subscription.TenantId; `
    client_id = $app.ApplicationId; client_secret = $securePassword; }

Write-Output $result
