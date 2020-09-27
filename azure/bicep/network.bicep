param location string = resourceGroup().location
param suffix string = 'WindowsVirtualDesktop'
param tags object = {
  Function: 'WindowsVirtualDesktop'
  Environment: 'Development'
  Owner: 'aaron@example.com'
  CostCenter: 'Lab'
}
param vnet1cfg object = {
  name: 'vnet-${suffix}-${location}'
  addressSpacePrefix: '10.1.0.0/16'
  /* subnet0Name: 'GatewaySubnet'
  subnet0Prefix: '10.1.0.0/27' */
  subnet1Name: 'subnet-Infrastructure'
  subnet1Prefix: '10.1.2.0/24'
  nsg1: 'nsg-Infrastructure'
  subnet2Name: 'subnet-Pooled'
  subnet2Prefix: '10.1.3.0/24'
  nsg2: 'nsg-Pooled'
  subnet3Name: 'subnet-Personal'
  subnet3Prefix: '10.1.4.0/24'
  nsg3: 'nsg-Personal'
}
var rdpRule = {
  name: 'default-allow-rdp' // don't use this rule in production
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

resource vnet1 'Microsoft.Network/virtualNetworks@2018-10-01' = {
  name: vnet1cfg.Name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnet1cfg.addressSpacePrefix
      ]
    }
    enableVmProtection: false
    enableDdosProtection: false
    subnets: [
      /* {
        name: vnet1cfg.subnet0Name
        properties: {
          addressPrefix: vnet1cfg.subnet0Prefix
        }
      } */
      {
        name: vnet1cfg.subnet1Name
        properties: {
          addressPrefix: vnet1cfg.subnet1Prefix
          networkSecurityGroup: {
            id: nsg1.id
          }
        }
      }
      {
        name: vnet1cfg.subnet2Name
        properties: {
          addressPrefix: vnet1cfg.subnet2Prefix
          networkSecurityGroup: {
            id: nsg2.id
          }          
        }
      }
      {
        name: vnet1cfg.subnet3Name
        properties: {
          addressPrefix: vnet1cfg.subnet3Prefix
          networkSecurityGroup: {
            id: nsg3.id
          }
        }
      }
    ]
  }
}

resource nsg1 'Microsoft.Network/networkSecurityGroups@2020-05-01' = {
  name: vnet1cfg.nsg1
  location: location
  tags: tags
  properties: {
    securityRules: [
      rdpRule
    ]
  }
}

resource nsg2 'Microsoft.Network/networkSecurityGroups@2020-05-01' = {
  name: vnet1cfg.nsg2
  location: location
  tags: tags
  properties: {
    securityRules: [
      rdpRule
    ]
  }
}

resource nsg3 'Microsoft.Network/networkSecurityGroups@2020-05-01' = {
  name: vnet1cfg.nsg3
  location: location
  tags: tags
  properties: {
    securityRules: [
      rdpRule
    ]
  }
}

output networkId string = vnet1.id