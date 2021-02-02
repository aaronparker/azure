# Build Azure

Scripts and Azure Resource Manager templates used to build various IaaS components in Azure. The goal being to build a virtual network with subnets and other resources, and deploy VMs for specific roles.

Used to learn ARM templates and Azure PowerShell etc.

## Azure Scripts

Scripts for various Azure management tasks

### Get-Subscription.ps1

`Get-Subscription.ps1` is used to ensure the `AzureRM` PowerShell module is installed and simpify authentication to the Azure tenant. Outputs details of the subscription.

### Remove-Resources.ps1

`Remove-Resources.ps1` will enumerate and destroy specific resources within a subscription. Use with care.
