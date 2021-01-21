#Requires -Module Az
# Dot source Export-Variables.ps1 first

# Use $ManagementGroups
ForEach ($group in $ManagementGroups.GetEnumerator()) {
    $params = @{
        GroupId     = (New-Guid)
        DisplayName = $group.Value
        Verbose     = $true
    }
    New-AzManagementGroup @params
}
