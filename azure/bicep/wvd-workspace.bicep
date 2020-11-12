param metadataLocation string = 'westus'
param location string = 'AustraliaEast'
param wvd1cfg object = {
  workspaceName: 'Workspace-${location}'
  workspaceNameFriendlyName: '${location}'
  hostpoolName: 'Windows10-2004-Pooled-${location}'
  hostpoolFriendlyName: 'Windows10-2004-Pooled-${location}'
  appgroupName: 'Windows10-2004-Pooled-${location}-DAG'
  appgroupNameFriendlyName: 'Windows10-2004-Pooled-${location}-DAG'
  hostpooltype: 'pooled'
  loadbalancertype: 'BreadthFirst'
  appgroupType: 'Desktop'
}
param tags object = {
  Function: 'WindowsVirtualDesktop'
  Environment: 'Development'
  Owner: 'aaron@example.com'
  CostCenter: 'Lab'
}

resource hp 'Microsoft.DesktopVirtualization/hostpools@2019-12-10-preview' = {
  name: wvd1cfg.hostpoolName
  location: metadataLocation
  properties: {
    friendlyname: wvd1cfg.hostpoolFriendlyName
    tags: tags
    hostpooltype : wvd1cfg.hostpooltype
    loadbalancertype : wvd1cfg.loadbalancertype
  }
}

resource ag 'Microsoft.DesktopVirtualization/applicationgroups@2019-12-10-preview' = {
  name: wvd1cfg.appgroupName
  location: metadataLocation
  properties: {
    friendlyname: wvd1cfg.appgroupNameFriendlyName
    tags: tags
    applicationgrouptype: wvd1cfg.appgroupType
    hostpoolarmpath: hp.id
  }
}

resource ws 'Microsoft.DesktopVirtualization/workspaces@2019-12-10-preview' = {
  name: wvd1cfg.workspaceName
  location: metadataLocation
  properties: {
    friendlyname: wvd1cfg.workspaceNameFriendlyName
    tags: tags
    applicationGroupReferences: []
  }
}

output workspaceid string = ws.id