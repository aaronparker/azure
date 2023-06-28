targetScope = 'subscription'

// Location to create the resource groups
param location string = 'australiaeast'

// Update the value of the Application tag post-deployment
param tags object = {
  Application: 'Azure Arc'
  CreatedBy: 'stealthpuppy'
  CreatedDate: utcNow()
  Criticality: 'High'
  Environment: 'Lab'
  Function: 'Infrastructure'
}

// List of resource groups to create
param resourceGroupNames array = [
  'rg-AzureArc-${location}'
]

resource resourceGroups 'Microsoft.Resources/resourceGroups@2022-09-01' = [for name in resourceGroupNames: {
  name: name
  location: location
  tags: tags
}]
