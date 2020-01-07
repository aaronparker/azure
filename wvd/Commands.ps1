Install-Module Microsoft.RDInfra.RDPowershell

Add-RdsAccount -DeploymentUrl "https://rdbroker.wvd.microsoft.com"
New-RdsTenant -Name "" -AadTenantId "" -AzureSubscriptionId ""
New-RdsRoleAssignment -TenantName "" -SignInName "" -RoleDefinitionName "RDS Owner"

Import-Module AzureAD
$aadContext = Connect-AzureAD
$svcPrincipal = New-AzureADApplication -AvailableToOtherTenants $true -DisplayName "Windows Virtual Desktop Svc Principal"
$svcPrincipalCreds = New-AzureADApplicationPasswordCredential -ObjectId $svcPrincipal.ObjectId

$rdsTenant = Get-RdsTenant
New-RdsRoleAssignment -RoleDefinitionName "RDS Owner" -ApplicationId $svcPrincipal.AppId -TenantName $rdsTenant.TenantName

$creds = New-Object System.Management.Automation.PSCredential($svcPrincipal.AppId, (ConvertTo-SecureString $svcPrincipalCreds.Value -AsPlainText -Force))
Add-RdsAccount -DeploymentUrl "https://rdbroker.wvd.microsoft.com" -Credential $creds -ServicePrincipal -AadTenantId $aadContext.TenantId.Guid
