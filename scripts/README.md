# Deploy Azure Infrastructure

These scripts will deploy the required infrastructure to support Windows Virtual Desktop workloads. Scripts should be dot sourced so that variables are exported into the current session for use with other scripts.

* `Export-Variables.ps1` - This script contains common variables used across all scripts.
* `Get-Subscription.ps1` - used to ensure the `AzureRM` PowerShell module is installed and simplify authentication to the Azure tenant. Outputs details of the subscription.
* `Remove-Resources.ps1` will enumerate and destroy specific resources within a subscription. Use with care.
