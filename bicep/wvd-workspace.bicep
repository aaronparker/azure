param metadataLocation string = 'westus'
param location string = 'AustraliaEast'
param wvd1cfg object = {
  workspaceName: 'Workspace-${location}'
  workspaceNameFriendlyName: '${location}'
  workspaceDescription: '${location}'
}
param hp1cfg object = {
  hostPoolName: 'Windows10-20H2-Evd-Pooled-${location}'
  hostPoolFriendlyName: 'Windows10-20H2-Evd-Pooled-${location}'
  hostPoolDescription: 'Windows 10 Enterprise multi-session 20H2 pooled desktops'
  hostPoolType: 'pooled'
  loadBalancerType: 'BreadthFirst'
  maxSessionLimit: 2
  appGroupName: 'Windows10-20H2-Pooled-${location}-DAG'
  appGroupNameFriendlyName: 'Windows10-20H2-Evd-Pooled-${location}-DAG'
  appGroupType: 'Desktop'
}
param hp2cfg object = {
  hostPoolName: 'Windows10-20H2-Ent-Personal-${location}'
  hostPoolFriendlyName: 'Windows10-20H2-Ent-Personal-${location}'
  hostPoolDescription: 'Windows 10 Enterprise 20H2 Personal desktops'
  hostPoolType: 'Personal'
  appGroupName: 'Windows10-20H2-Ent-Personal-${location}-DAG'
  appGroupNameFriendlyName: 'Windows10-20H2-Ent-Personal-${location}-DAG'
  appGroupType: 'Desktop'
}
param tags object = {
  Function: 'WindowsVirtualDesktop'
  Environment: 'Development'
  Owner: 'aaron@example.com'
  CostCenter: 'Lab'
}

resource hp1 'Microsoft.DesktopVirtualization/hostPools@2020-11-02-preview' = {
  name: wvd1cfg.hostPoolName
  location: metadataLocation
  properties: {
    friendlyName: hp1cfg.hostPoolFriendlyName
    hostPoolType: hp1cfg.hostPoolType
    loadBalancerType: hp1cfg.loadBalancerType
    preferredAppGroupType: hp1cfg.appGroupType
    description: hp1cfg.hostPoolDescription
    ring: 0
    startVMOnConnect: true
    validationEnvironment: true
    maxSessionLimit: hp1cfg.maxSessionLimit
    vmTemplate: ''
  }
}

resource ag1 'Microsoft.DesktopVirtualization/applicationGroups@2020-11-02-preview' = {
  name: hp1cfg.appGroupName
  location: metadataLocation
  properties: {
    friendlyName: hp1cfg.appGroupNameFriendlyName
    applicationGroupType: hp1cfg.appGroupType
    hostPoolArmPath: hp1.id
    description: hp1cfg.hostPoolDescription
  }
}

resource hp2 'Microsoft.DesktopVirtualization/hostPools@2020-11-02-preview' = {
  name: wvd1cfg.hostPoolName
  location: metadataLocation
  properties: {
    friendlyName: hp2cfg.hostPoolFriendlyName
    hostPoolType: hp2cfg.hostPoolType
    loadBalancerType: hp2cfg.loadBalancerType
    preferredAppGroupType: hp2cfg.appGroupType
    description: hp2cfg.hostPoolDescription
    ring: 0
    startVMOnConnect: true
    validationEnvironment: true
    maxSessionLimit: hp2cfg.maxSessionLimit
    vmTemplate: ''
  }
}

resource ag2 'Microsoft.DesktopVirtualization/applicationGroups@2020-11-02-preview' = {
  name: hp2cfg.appGroupName
  location: metadataLocation
  properties: {
    friendlyName: hp2cfg.appGroupNameFriendlyName
    applicationGroupType: hp2cfg.appGroupType
    hostPoolArmPath: hp2.id
    description: hp2cfg.hostPoolDescription
  }
}

resource ws 'Microsoft.DesktopVirtualization/workspaces@2020-11-02-preview' = {
  name: wvd1cfg.workspaceName
  location: metadataLocation
  properties: {
    friendlyName: wvd1cfg.workspaceNameFriendlyName
    applicationGroupReferences: [
      ag1.id
      ag2.id
    ]
    description: wvd1cfg.workspaceDescription
  }
}

output workspaceId string = ws.id
