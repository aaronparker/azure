<#
    .SYNOPSIS
    A script used to export all NSGs rules in all your Azure Subscriptions

    .DESCRIPTION
    A script is used to get the list of all Network Security Groups (NSGs) in all your Azure Subscriptions.
    Finally, it will export the report into a CSV file in your Azure Cloud Shell storage.

    .NOTES
    Created : 04-January-2021
    Updated : 15-June-2023
    Version : 3.4
    Author : Charbel Nemnom
    Twitter : @CharbelNemnom
    Blog : https://charbelnemnom.com
    Disclaimer: This script is provided "AS IS" with no warranties.
#>

$Path = "$($home)\clouddrive"
$Path = $PWD

#! Check Azure Connection
try {
    Connect-AzAccount -ErrorAction "Stop" -WarningAction "SilentlyContinue" | Out-Null
    $AzSubscription = Set-AzContext -Subscription "6c67f21a-c7fc-4098-8bff-b6f8b4da92ac"
}
catch {
    throw $_
}

#! Use the following if you want to select a specific Azure Subscription
# $AzSubscription = Get-AzSubscription | Out-GridView -PassThru -Title 'Select Azure Subscription'

foreach ($Subscription in $AzSubscription) {
    #Set-AzContext -Subscription $Subscription | Out-Null
    $NetworkSecurityGroups = Get-AzNetworkSecurityGroup | Where-Object { $_.Id -ne $null }

    foreach ($Nsg in $NetworkSecurityGroups) {
        # Export custom rules
        Get-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $Nsg | `
            Select-Object @{label = 'NSG Name'; Expression = { $Nsg.Name } }, `
        @{label = 'NSG Location'; Expression = { $Nsg.Location } }, `
        @{label = 'Rule Name'; Expression = { $_.Name } }, `
        @{label = 'Source'; Expression = { $_.SourceAddressPrefix -join "; " } }, `
        @{label = 'Source Application Security Group'; Expression = { foreach ($Asg in $_.SourceApplicationSecurityGroups) { $Asg.id.Split('/')[-1] } } }, `
        @{label = 'Source Port Range'; Expression = { $_.SourcePortRange } }, Access, Priority, Direction, `
        @{label = 'Destination'; Expression = { $_.DestinationAddressPrefix -join "; "} }, `
        @{label = 'Destination Application Security Group'; Expression = { foreach ($Asg in $_.DestinationApplicationSecurityGroups) { $Asg.id.Split('/')[-1] } } }, `
        @{label = 'Destination Port Range'; Expression = { $_.DestinationPortRange -join "; " } }, `
        @{label = 'Resource Group Name'; Expression = { $Nsg.ResourceGroupName } } | `
            Export-Csv -Path "$Path\$($Subscription.Name)-nsg-rules.csv" -NoTypeInformation -Append -Force
        # Or you can use the following syntax to export to a single CSV file and to a local folder on your machine
        # Export-Csv -Path ".\Azure-nsg-rules.csv" -NoTypeInformation -Append -force

        # Export default rules
        Get-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $Nsg -DefaultRules | `
            Select-Object @{label = 'NSG Name'; Expression = { $Nsg.Name } }, `
        @{label = 'NSG Location'; Expression = { $Nsg.Location } }, `
        @{label = 'Rule Name'; Expression = { $_.Name } }, `
        @{label = 'Source'; Expression = { $_.SourceAddressPrefix -join "; " } }, `
        @{label = 'Source Port Range'; Expression = { $_.SourcePortRange } }, Access, Priority, Direction, `
        @{label = 'Destination'; Expression = { $_.DestinationAddressPrefix -join "; "} }, `
        @{label = 'Destination Port Range'; Expression = { $_.DestinationPortRange -join "; " } }, `
        @{label = 'Resource Group Name'; Expression = { $Nsg.ResourceGroupName } } | `
            Export-Csv -Path "$Path\$($Subscription.Name)-nsg-rules.csv" -NoTypeInformation -Append -Force

        # Or you can use the following syntax to export to a single CSV file and to a local folder on your machine
        # Export-Csv -Path ".\Azure-nsg-rules.csv" -NoTypeInformation -Append -force
    }
}
