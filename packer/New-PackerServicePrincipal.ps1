#Requires -Module Az
<#
    .SYNOPSIS
        Creates a service principal for use with Hashicorp Packer
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $False)]
    [System.String] $AppName = "HashicorpPackerServicePrincipal",

    [Parameter(Mandatory = $False)]
    [System.String] $SubscriptionName = "Visual Studio Enterprise Subscription"
)

# Set Az context
$Subscription = Get-AzSubscription | Where-Object { $_.Name -eq $SubscriptionName }
Set-AzContext -SubscriptionId $Subscription.Id

# Find an existing service principal
$params = @{
    SearchString = $AppName
    ErrorAction  = "SilentlyContinue"
}
$existingSp = Get-AzADServicePrincipal @params

If ($Null -eq $existingSp) {

    # Create the service principal
    $params = @{
        DisplayName = $AppName
        Role        = "Contributor"
        Scope       = "/subscriptions/$($Subscription.Id)"
    }
    $sp = New-AzADServicePrincipal @params

    # Set the owner of the service principal
    $Owner = Get-AzureADUser -SearchString $Subscription.ExtendedProperties.Account
    Add-AzureADServicePrincipalOwner -ObjectId $sp.Id -RefObjectId $Owner.ObjectId

    # Get details
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sp.Secret)
    $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    <## Assign roles
    $role = Get-AzRoleAssignment -ServicePrincipalName $sp.ApplicationId
    If ($role.RoleDefinitionName -notcontains "Contributor") {
        New-AzRoleAssignment -RoleDefinitionName Contributor -ServicePrincipalName $sp.ApplicationId
    }#>

    # TODO: Password here outputs a GUID instead of the password.
    $output = @{
        "Password" = $plainPassword
        "AppId"    = $sp.ApplicationId
    }
    Write-Output $output
}
