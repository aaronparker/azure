<#
    .SYNOPSIS
    A script used to export all NSGs rules in all your Azure subscriptions

    .DESCRIPTION
    A script is used to get the list of all Network Security Groups (NSGs) in all your Azure subscriptions.

    .NOTES
    Created : 04-January-2021
    Updated : 15-June-2023
    Version : 3.4
    Author : Charbel Nemnom
    Twitter : @CharbelNemnom
    Blog : https://charbelnemnom.com
    Disclaimer: This script is provided "AS IS" with no warranties.

    Updates: Aaron Parker
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ if ([System.Guid]::TryParse($_, [System.Management.Automation.PSReference]$([System.Guid]::Empty))) { $true } else { throw "Not a GUID." } })]
    [System.String[]] $Subscription = "3fc4c8ac-a2b8-4b39-9729-f1a5eeacbab5",

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [System.String[]] $NetworkSecurityGroupName,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [System.String[]] $Path = $PWD
)

begin {
    try {
        # Connect to the tenant
        Connect-AzAccount -DeviceCode -ErrorAction "Stop"
    }
    catch {
        throw $_
    }
}

process {
    foreach ($Sub in $Subscription) {
        try {
            $AzSubscription = Set-AzContext -Subscription $Sub
        }
        catch {
            throw $_
        }

        foreach ($AzSub in $AzSubscription) {
            # Create output file name
            $SubscriptionName = $($($AzSub.Name -split "\(")[0]).Trim()
            $OutputFile = "$Path\$SubscriptionName-nsg-rules.csv"

            if ($PSBoundParameters.ContainsKey('Nsg')) {
                # Get network security groups listed in -NetworkSecurityGroupName
                $NetworkSecurityGroups = Get-AzNetworkSecurityGroup | Where-Object { $_.Name -in $NetworkSecurityGroupName -and $_.Id -ne $null }
            }
            else {
                # Get all network security groups
                $NetworkSecurityGroups = Get-AzNetworkSecurityGroup | Where-Object { $_.Id -ne $null }
            }

            foreach ($Nsg in $NetworkSecurityGroups) {
                # Export custom rules
                Get-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $Nsg | `
                    Select-Object @{label = 'NSG Name'; Expression = { $Nsg.Name } }, `
                @{label = 'NSG Location'; Expression = { $Nsg.Location } }, `
                @{label = 'Rule Name'; Expression = { $_.Name } }, `
                @{label = 'Source'; Expression = { $_.SourceAddressPrefix -join "; " } }, `
                @{label = 'Source Application Security Group'; Expression = { foreach ($Asg in $_.SourceApplicationSecurityGroups) { $Asg.id.Split('/')[-1] } } }, `
                @{label = 'Source Port Range'; Expression = { $_.SourcePortRange } }, "Access", "Priority", "Direction", `
                @{label = 'Destination'; Expression = { $_.DestinationAddressPrefix -join "; " } }, `
                @{label = 'Destination Application Security Group'; Expression = { foreach ($Asg in $_.DestinationApplicationSecurityGroups) { $Asg.id.Split('/')[-1] } } }, `
                @{label = 'Destination Port Range'; Expression = { $_.DestinationPortRange -join "; " } }, `
                @{label = 'Resource Group Name'; Expression = { $Nsg.ResourceGroupName } } | `
                    Export-Csv -Path $OutputFile -NoTypeInformation -Append -Force

                # Export default rules
                Get-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $Nsg -DefaultRules | `
                    Select-Object @{label = 'NSG Name'; Expression = { $Nsg.Name } }, `
                @{label = 'NSG Location'; Expression = { $Nsg.Location } }, `
                @{label = 'Rule Name'; Expression = { $_.Name } }, `
                @{label = 'Source'; Expression = { $_.SourceAddressPrefix -join "; " } }, `
                @{label = 'Source Port Range'; Expression = { $_.SourcePortRange } }, "Access", "Priority", "Direction", `
                @{label = 'Destination'; Expression = { $_.DestinationAddressPrefix -join "; " } }, `
                @{label = 'Destination Port Range'; Expression = { $_.DestinationPortRange -join "; " } }, `
                @{label = 'Resource Group Name'; Expression = { $Nsg.ResourceGroupName } } | `
                    Export-Csv -Path $OutputFile -NoTypeInformation -Append -Force
            }

            # Output the output file name
            Write-Output -InputObject (Get-ChildItem -Path $OutputFile)
        }
    }
}
