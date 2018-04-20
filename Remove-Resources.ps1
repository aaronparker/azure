<#
    Simple approach to removing resources in Azure
#>
[CmdletBinding()]
Param()

Get-AzureRmVM |  Remove-AzureRmVM -Verbose -Force
Get-AzureRmNetworkInterface | Remove-AzureRmNetworkInterface -Verbose -Force
Get-AzureRmPublicIpAddress | Remove-AzureRmPublicIpAddress -Verbose -Force
Get-AzureRmStorageAccount | Remove-AzureRmStorageAccount -Verbose -Force
Get-AzureRmDisk | Remove-AzureRmDisk -Verbose -Force
Get-AzureRmVirtualNetwork | Remove-AzureRmVirtualNetwork -Verbose -Force
Get-AzureRmNetworkSecurityGroup | Remove-AzureRmNetworkSecurityGroup -Verbose -Force
