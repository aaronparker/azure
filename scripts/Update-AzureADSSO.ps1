Import-Module -Name "$env:programfiles\Microsoft Azure Active Directory Connect\AzureADSSO.psd1"
New-AzureADSSOAuthenticationContext
$creds = Get-Credential -UserName home\administrator -Message "Enter password"
Update-AzureADSSOForest -OnPremCredentials $Creds
