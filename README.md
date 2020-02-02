# Build Azure

Azure Resource Manager templates used to build various IaaS components in Azure.

The end goal is to be able to build a virtual network with subnets and deploy VMs including automatically building a hosted Active Directory environment.

Used to learn ARM templates and Azure PowerShell etc.

## Get-Subscription.ps1

`Get-Subscription.ps1` is used to ensure the `AzureRM` PowerShell module is installed and simpify authentication to the Azure tenant. Outputs details of the subscription.

## Remove-Resources.ps1

`Remove-Resources.ps1` will enumerate and destroy specific resources within a subscription. Use with care.
