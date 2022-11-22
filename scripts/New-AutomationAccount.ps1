param(
    [string]$AutomationAccountName,
    [string]$ResourceGroupName,
    [string]$SubscriptionId,
    [string]$KeyVaultName,
    [string]$Location,
    [string]$servicePrincipalId
)

Get-AzSubscription -SubscriptionId $SubscriptionId | Select-AzSubscription

$GetKeyVault = Get-AzKeyVault -VaultName $KeyVaultName
if (!$GetKeyVault) {

    Write-Warning -Message "Key Vault not found. Creating the Key Vault $keyVaultName"

    $KeyVault = New-AzKeyVault -VaultName $keyVaultName -ResourceGroupName $ResourceGroupName -Location $Location

    if (!$KeyVault) {
        Write-Error -Message "Key Vault $keyVaultName creation failed. Please fix and continue"
        return
    }
    Start-Sleep -s 15
}

#### granting SP access to KeyVault
Set-AzKeyVaultAccessPolicy -ResourceGroupName $GetKeyVault.ResourceGroupName -VaultName $keyVaultName -ObjectId $servicePrincipalId -PermissionsToCertificates ("list", "get", "create") -PermissionsToKeys ("list", "get", "create") -PermissionsToSecrets ("list", "get", "set") -PermissionsToStorage ("list", "get", "set")


[String] $ApplicationDisplayName = "$AutomationAccountName"
[String] $SelfSignedCertPlainPassword = [Guid]::NewGuid().ToString().Substring(0, 8) + "!"
[int] $NoOfMonthsUntilExpired = 36

$CertifcateAssetName = "AzureRunAsCertificate"
$CertificateName = $AutomationAccountName + $CertifcateAssetName
$PfxCertPathForRunAsAccount = Join-Path $env:TEMP ($CertificateName + ".pfx")
$PfxCertPlainPasswordForRunAsAccount = $SelfSignedCertPlainPassword
$CerCertPathForRunAsAccount = Join-Path $env:TEMP ($CertificateName + ".cer")

Write-Output "Generating the cert using Keyvault..."

$certSubjectName = "cn=" + $certificateName

$Policy = New-AzKeyVaultCertificatePolicy -SecretContentType "application/x-pkcs12" -SubjectName $certSubjectName -IssuerName "Self" -ValidityInMonths $noOfMonthsUntilExpired -ReuseKeyOnRenewal
$AddAzureKeyVaultCertificateStatus = Add-AzKeyVaultCertificate -VaultName $KeyVaultName -Name $certificateName -CertificatePolicy $Policy

While ($AddAzureKeyVaultCertificateStatus.Status -eq "inProgress") {
    Start-Sleep -s 10
    $AddAzureKeyVaultCertificateStatus = Get-AzKeyVaultCertificateOperation -VaultName $keyVaultName -Name $certificateName
}

if ($AddAzureKeyVaultCertificateStatus.Status -ne "completed") {
    Write-Error -Message "Key vault cert creation is not successful and its status is: $($status.Status)"
}

$secretRetrieved = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $certificateName
$pfxBytes = [System.Convert]::FromBase64String($secretRetrieved.SecretValueText)
$certCollection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
$certCollection.Import($pfxBytes, $null, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)

#Export the .pfx file
$protectedCertificateBytes = $certCollection.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pkcs12, $PfxCertPlainPasswordForRunAsAccount)
[System.IO.File]::WriteAllBytes($PfxCertPathForRunAsAccount, $protectedCertificateBytes)

#Export the .cer file
$cert = Get-AzKeyVaultCertificate -VaultName $keyVaultName -Name $certificateName
$certBytes = $cert.Certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
[System.IO.File]::WriteAllBytes($CerCertPathForRunAsAccount, $certBytes)

Write-Output "Creating service principal..."
# Create Service Principal
$PfxCert = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList @($PfxCertPathForRunAsAccount, $PfxCertPlainPasswordForRunAsAccount)

$keyValue = [System.Convert]::ToBase64String($PfxCert.GetRawCertData())
$KeyId = [Guid]::NewGuid()

$startDate = Get-Date
$endDate = (Get-Date $PfxCert.GetExpirationDateString()).AddDays(-1)

# Use Key credentials and create AAD Application
$Application = New-AzADApplication -DisplayName $ApplicationDisplayName -Homepage ("http://" + $applicationDisplayName) -IdentifierUris ("http://" + $KeyId)
New-AzADAppCredential -ApplicationId $Application.ApplicationId -CertValue $keyValue -StartDate $startDate -EndDate $endDate
New-AzADServicePrincipal -ApplicationId $Application.ApplicationId

# Sleep here for a few seconds to allow the service principal application to become active (should only take a couple of seconds normally)
Start-Sleep -s 15

$NewRole = $null
$Retries = 0;
While ($null -eq $NewRole -and $Retries -le 6) {
    New-AzRoleAssignment -RoleDefinitionName Contributor -ServicePrincipalName $Application.ApplicationId -Scope ("/subscriptions/" + $subscriptionId) -ErrorAction SilentlyContinue
    Start-Sleep -s 10
    $NewRole = Get-AzRoleAssignment -ServicePrincipalName $Application.ApplicationId -ErrorAction SilentlyContinue
    $Retries++;
}

Write-Output "Creating Automation account"
New-AzAutomationAccount -ResourceGroupName $ResourceGroupName -Name $AutomationAccountName -Location "westeurope"

Write-Output "Creating Certificate in the Asset..."
# Create the automation certificate asset
$CertPassword = ConvertTo-SecureString $PfxCertPlainPasswordForRunAsAccount -AsPlainText -Force
Remove-AzAutomationCertificate -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $certifcateAssetName -ErrorAction SilentlyContinue
New-AzAutomationCertificate -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Path $PfxCertPathForRunAsAccount -Name $certifcateAssetName -Password $CertPassword -Exportable | Write-Verbose

# Populate the ConnectionFieldValues
$ConnectionTypeName = "AzureServicePrincipal"
$ConnectionAssetName = "AzureRunAsConnection"
$ApplicationId = $Application.ApplicationId
$SubscriptionInfo = Get-AzSubscription -SubscriptionId $SubscriptionId
$TenantID = $SubscriptionInfo | Select-Object TenantId -First 1
$Thumbprint = $PfxCert.Thumbprint
$ConnectionFieldValues = @{"ApplicationId" = $ApplicationID; "TenantId" = $TenantID.TenantId; "CertificateThumbprint" = $Thumbprint; "SubscriptionId" = $SubscriptionId }
# Create a Automation connection asset named AzureRunAsConnection in the Automation account. This connection uses the service principal.

Write-Output "Creating Connection in the Asset..."
Remove-AzAutomationConnection -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $connectionAssetName -Force -ErrorAction SilentlyContinue
New-AzAutomationConnection -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $connectionAssetName -ConnectionTypeName $connectionTypeName -ConnectionFieldValues $connectionFieldValues

Write-Output "RunAsAccount Creation Completed..."
