param location string = 'AustraliaEast'
param suffix string = 'WindowsVirtualDesktop'
param vnetPrefix string = '10.1.0.0/16'
/* param subnetGatewayName string = 'GatewaySubnet'
param subnetGatewayPrefix string = '10.1.0.0/27' */
param subnetInfrastructure string = 'Infrastructure'
param subnetInfrastructurePrefix string = '10.1.1.0/24'
param subnetPooled string = 'PooledDesktops'
param subnetPooledPrefix string = '10.1.2.0/24'
param subnetPersonal string = 'PersonalDesktops'
param subnetPersonalPrefix string = '10.1.3.0/24'
param tags object = {
  Function: 'WindowsVirtualDesktop'
  Environment: 'Development'
}
var subnetInfrastructureName = concat('subnet-', subnetInfrastructure)
var subnetPooledName = concat('subnet-', subnetPooled)
var subnetPersonalName = concat('subnet-', subnetPersonal)
var nsgInfrastructureName = concat('nsg-', subnetInfrastructure)
var nsgPooledName = concat('nsg-', subnetPooled)
var nsgPersonalName = concat('nsg-', subnetPersonal)
var vnetName = 'vnet-${suffix}-${location}'
var rdpRule = {
  name: 'default-allow-rdp'
  properties: {
    priority: 1000
    sourceAddressPrefix: '*'
    protocol: 'Tcp'
    destinationPortRange: '3389'
    access: 'Allow'
    direction: 'Inbound'
    sourcePortRange: '*'
    destinationAddressPrefix: '*'
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2018-10-01' = {
  name: vnetName
  location: resourceGroup().location
  tags: tags
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
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
      {
        name: subnetPooledName
        properties: {
          addressPrefix: subnetPooledPrefix
          networkSecurityGroup: {
            id: nsg1.id
          }          
        }
      }
      {
        name: subnetPersonalName
        properties: {
          addressPrefix: subnetPersonalPrefix
          networkSecurityGroup: {
            id: nsg2.id
          }
        }
      }
    ]
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2020-05-01' = {
  name: nsgInfrastructureName
  location: location
  tags: tags
  properties: {
    securityRules: [
      rdpRule
    ]
  }
}

resource nsg1 'Microsoft.Network/networkSecurityGroups@2020-05-01' = {
  name: nsgPooledName
  location: location
  tags: tags
  properties: {
    securityRules: [
      rdpRule
    ]
  }
}

resource nsg2 'Microsoft.Network/networkSecurityGroups@2020-05-01' = {
  name: nsgPersonalName
  location: location
  tags: tags
  properties: {
    securityRules: [
      rdpRule
    ]
  }
}

output networkid string = vnet.id