#Requires -Module Az
# Dot source Export-Variables.ps1 first

#region Test if logged in and get the subscription
If ((Get-AzContext).SubscriptionName -ne $SubscriptionName) {
    Connect-AzAccount
    $Subscription = Get-AzSubscription
}
Else {
    $Subscription = Get-AzSubscription
}
#endregion


# Check Azure AD Access token
<#
If ($Null -eq [Microsoft.Open.Azure.AD.CommonLibrary.AzureSession]::AccessTokens) {
    $aadContext = Connect-AzureAD
}
Else {
    $token = [Microsoft.Open.Azure.AD.CommonLibrary.AzureSession]::AccessTokens
    Write-Verbose -Message "Connected to tenant: $($token.AccessToken.TenantId) with user: $($token.AccessToken.UserId)"
}
#>
