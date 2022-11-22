Get-AzResource | Where-Object { $_.ResourceGroupName -eq "rg-WindowsVirtualDesktopInfrastructure-AustraliaEast" }

$params = @{
    Name                        = "KeyVault-Diagnostics"
    ResourceId                  = "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/myresourcegroup/providers/Microsoft.KeyVault/vaults/mykeyvault"
    Category                    = "AuditEvent"
    MetricCategory              = "AllMetrics"
    Enabled                     = $true
    WorkspaceId                 = "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourcegroups/oi-default-east-us/providers/microsoft.operationalinsights/workspaces/myworkspace"
    EventHubAuthorizationRuleId = "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/myresourcegroup/providers/Microsoft.EventHub/namespaces/myeventhub/authorizationrules/RootManageSharedAccessKey"
}
Set-AzDiagnosticSetting @params
