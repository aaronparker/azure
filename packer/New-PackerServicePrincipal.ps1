<#
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $False)]
    [System.String] $AppName = "HashicorpPackerServicePrincipal"
)

$Context = Get-AzContext

# Find an existing service principal
$params = @{
    DisplayName = $AppName
    #TenantId    = $Context.Tenant
    ErrorAction = "SilentlyContinue"
}
$sp = Get-AzADServicePrincipal @params
If ($Null -eq $sp) {
    # Create the service principal
    $params = @{
        DisplayName = $AppName
        #TenantId    = $Context.Tenant
    }
    $sp = New-AzADServicePrincipal @params

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
}
