#Requires -Module Az
# Dot source Export-Variables.ps1 first

# Create the workspace
$params = @{
    Name              = "LogAnalytics-$LongName-$Location"
    Sku               = "Free"
    Location          = $Location
    ResourceGroupName = $ResourceGroups.Infrastructure
    Tag               = $Tags
}
New-AzOperationalInsightsWorkspace @params


# Create the automation account
$params = @{
    Name              = "LogAnalytics-$LongName-$Location"
    Plan              = "Free"
    Location          = $Location
    ResourceGroupName = $ResourceGroups.Infrastructure
    Tag               = $Tags
}
New-AzAutomationAccount
