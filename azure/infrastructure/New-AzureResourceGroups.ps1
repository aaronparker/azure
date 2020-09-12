#Requires -Module Az
# Dot source Export-Variables.ps1 first

#region Create resource groups
ForEach ($item in $ResourceGroups.GetEnumerator()) {
    $params = @{
        Name           = $item.Value
        Location       = $Location
        Tag            = $Tags
        SubscriptionId = $SubscriptionId
    }
    New-AzResourceGroup @params
}
#endregion
