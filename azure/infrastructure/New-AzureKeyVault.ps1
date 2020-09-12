#Requires -Module Az
# Dot source Export-Variables.ps1 first

#region Key Vault
$TenantId = (Get-AzTenant).Id
$params = @{
    Name                         = ("$OrgName$ShortName").ToLower()
    ResourceGroupName            = $ResourceGroups.Infrastructure
    Location                     = $Location
    Sku                          = "Standard"
    EnabledForDeployment         = $True
    EnabledForDiskEncryption     = $True
    EnabledForTemplateDeployment = $True
    Tag                          = $Tags
    TenantId                     = $TenantId
}
$KeyVault = New-AzKeyVault @params

# Add secrets (update values)
Add-Type -AssemblyName 'System.Web'
$minLength = 22 ## characters
$maxLength = 42 ## characters
$length = Get-Random -Minimum $minLength -Maximum $maxLength
$nonAlphaChars = 7
$password = [System.Web.Security.Membership]::GeneratePassword($length, $nonAlphaChars)
$Secrets = @{
    GatewaySecret = $password
}
$Secrets = @{
    GatewaySecret = ""
}

# WVD key vault
$Secrets = @{
    DomainJoinSecret = ""
    DomainJoinUpn    = ""
    PackerAppId      = "9e85bbe3-8389-4c58-9e83-3cd2b6894b62"
    PackerSecret     = ""
    WvdAppId         = "931bb657-3126-48b5-b9f4-ce9ad9fc3d0b"
    WvdSecret        = ""
}
ForEach ($item in $Secrets.GetEnumerator()) {
    $secretvalue = ConvertTo-SecureString $item.Value -AsPlainText -Force
    Set-AzKeyVaultSecret -VaultName $KeyVault.Name -Name $item.Name -SecretValue $secretvalue
}
#endregion

$secretvalue = ConvertTo-SecureString "" -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName stealthpuppyhub -Name GatewaySecret -SecretValue $secretvalue
