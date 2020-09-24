param location string = 'AustraliaEast'
param suffix string = 'WindowsVirtualDesktop'
param vnetPrefix string = '10.1.0.0/16'
param subnetInfrastructureName string = 'subnet-Infrastructure'
param subnetInfrastructurePrefix string = '10.1.1.0/24'
param subnetPooledName string = 'subnet-PooledDesktops'
param subnetPooledPrefix string = '10.1.2.0/24'
param subnetPersonalName string = 'subnet-PersonalDesktops'
param subnetPersonalPrefix string = '10.1.3.0/24'
var vnetName = 'vnet-${suffix}-${location}'
var function = 'WindowsVirtualDesktop'
var environment = 'Development'

resource vnet 'Microsoft.Network/virtualNetworks@2018-10-01' = {
  name: vnetName
  location: resourceGroup().location
  tags: {
    Function: function
    Environment: environment
  }
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetPrefix
      ]
    }
    enableVmProtection: false
    enableDdosProtection: false
    subnets: [
      {
        name: subnetInfrastructureName
        properties: {
          addressPrefix: subnetInfrastructurePrefix
        }
      }
      {
        name: subnetPooledName
        properties: {
          addressPrefix: subnetPooledPrefix
        }
      }
      {
        name: subnetPersonalName
        properties: {
          addressPrefix: subnetPersonalPrefix
        }
      }
    ]
  }
}
