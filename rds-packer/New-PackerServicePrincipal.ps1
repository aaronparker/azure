<#
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $False)]
    [System.String] $AppName = "HashicorpPackerServicePrincipal"
)

# Find an existing service principal
$sp = Get-AzADServicePrincipal -DisplayName $AppName -ErrorAction SilentlyContinue
If ($Null -eq $sp) {
    # Create the service principal
    $sp = New-AzADServicePrincipal -DisplayName $AppName
}

# Get details
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sp.Secret)
$plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

# Assign roles
$role = Get-AzRoleAssignment -ServicePrincipalName $sp.ApplicationId
If ($role.RoleDefinitionName -notcontains "Contributor") {
    New-AzRoleAssignment -RoleDefinitionName Contributor -ServicePrincipalName $sp.ApplicationId
}

# TODO: Password here outputs a GUID instead of the password.
$output = @{
    "Password" = $plainPassword
    "AppId"    = $sp.ApplicationId
}

# Return output
Write-Output $output
