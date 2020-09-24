param location string = 'westus'
param workspaceName string = 'Workspace-AustraliaEast1'
param workspaceNameFriendlyName string = 'Australia East1'
param hostpoolName string = 'Windows10-2004-Pooled-AustraliaEast1'
param hostpoolFriendlyName string = 'Windows10-2004-Pooled-AustraliaEast1'
param appgroupName string = 'Windows10-2004-Pooled-AustraliaEast-DAG1'
param appgroupNameFriendlyName string = 'Windows10-2004-Pooled-AustraliaEast-DAG1'
var function = 'WindowsVirtualDesktop'
var environment = 'Development'
var hostpooltype = 'pooled'
var loadbalancertype = 'BreadthFirst'
var appgroupType = 'Desktop'

resource hp 'Microsoft.DesktopVirtualization/hostpools@2019-12-10-preview' = {
  name: hostpoolName
  location: location
  properties: {
    friendlyname: hostpoolFriendlyName
    tags: {
      Function: function
      Environment: environment
    }
    hostpooltype : hostpooltype
    loadbalancertype : loadbalancertype
  }
}

resource ag 'Microsoft.DesktopVirtualization/applicationgroups@2019-12-10-preview' = {
  name: appgroupName
  location: location
  properties: {
    friendlyname: appgroupNameFriendlyName
    tags: {
      Function: function
      Environment: environment
    }
    applicationgrouptype: appgroupType
    hostpoolarmpath: hp.id
  }
}

resource ws 'Microsoft.DesktopVirtualization/workspaces@2019-12-10-preview' = {
  name: workspaceName
  location: location
  properties: {
    friendlyname: workspaceNameFriendlyName
    tags: {
      Function: function
      Environment: environment
    }
    applicationGroupReferences: []
  }
}

output workspaceid string = ws.id
