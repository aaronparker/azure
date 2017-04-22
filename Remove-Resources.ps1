# Simple approach to removing resources in Azure

Get-AzureRmVM |  Remove-AzureRmVM -Verbose -Force
Get-AzureRmNetworkInterface | Remove-AzureRmNetworkInterface -Verbose -Force
Get-AzureRmPublicIpAddress | Remove-AzureRmPublicIpAddress -Verbose -Force
Get-AzureRmStorageAccount | Remove-AzureRmStorageAccount -Verbose -Force
