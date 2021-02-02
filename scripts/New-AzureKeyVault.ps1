#Requires -Module Az
# Dot source Export-Variables.ps1 first

#region Key Vault
$TenantId = (Get-AzTenant).Id
$params = @{
    Name                         = ("$ShortOrgName$ShortName$ShortLocation").ToLower()
    ResourceGroupName            = $ResourceGroups.Infrastructure
    Location                     = $Location
    Sku                          = "Standard"
    EnabledForDeployment         = $True
    EnabledForDiskEncryption     = $True
    EnabledForTemplateDeployment = $True
    Tag                          = $Tags
}
$KeyVault = New-AzKeyVault @params

# Add secrets (update values)
Add-Type -AssemblyName 'System.Web'
$minLength = 32 ## characters
$maxLength = 42 ## characters
$length = Get-Random -Minimum $minLength -Maximum $maxLength
$nonAlphaChars = 7
$password = [System.Web.Security.Membership]::GeneratePassword($length, $nonAlphaChars)

# WVD key vault
$Secrets = @{
    DomainJoinSecret = ""
    DomainJoinUpn    = ""
    PackerAppId      = $sp.ApplicationId
    PackerSecret     = $password
}
ForEach ($item in $Secrets.GetEnumerator()) {
    $secretvalue = ConvertTo-SecureString $item.Value -AsPlainText -Force
    Set-AzKeyVaultSecret -VaultName $KeyVault.VaultName -Name $item.Name -SecretValue $secretvalue
}
#endregion

$secretvalue = ConvertTo-SecureString "" -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName $KeyVault.VaultName -Name GatewaySecret -SecretValue $secretvalue
