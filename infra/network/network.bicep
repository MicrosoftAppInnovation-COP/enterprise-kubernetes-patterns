@description('Location of the resources')
param location string

param vnetHubConfig object = {
  name: 'hub'
  addressSpacePrefix: '10.0.0.0/16'
  subnets: [
    {
      name: 'DefaultSubnet'
      properties: {
        addressPrefix: '10.0.0.0/24'
      }
    }
    {
      name: 'AzureFirewallSubnet'
      properties: {
        addressPrefix: '10.0.1.0/24'
      }
    }
    {
      name: 'CloudShellSubnet'
      properties: {
        addressPrefix: '10.0.2.0/24'
        serviceEndpoints: [
          {
            service: 'Microsoft.Storage'
            locations: [
              location
            ]
          }
        ]
        delegations: [
          {
            name: 'CloudShellDelegation'
            properties: {
              serviceName: 'Microsoft.ContainerInstance/containerGroups'
            }
          }
        ]
      }
    }
    {
      name: 'RelaySubnet'
      properties: {
        addressPrefix: '10.0.3.0/28'
        privateEndpointNetworkPolicies: 'Disabled'
        privateLinkServiceNetworkPolicies: 'Enabled'
      }
    }
  ]
}

param vnetSpokeConfig object = {
  name: 'spoke'
  addressSpacePrefix: '10.1.0.0/16'
  subnets: [
    {
      name: 'DefaultSubnet'
      properties: {
        addressPrefix: '10.1.0.0/24'
      }
    }
    {
      name: 'AksSubnet'
      properties: {
        addressPrefix: '10.1.1.0/24'
      }
    }
    {
      name: 'GithubRunnerSubnet'
      properties: {
        addressPrefix: '10.1.2.0/24'
      }
    }
    {
      name: 'ServicesSubnet'
      properties: {
        addressPrefix: '10.1.3.0/24'
      }
    }
  ]
}

resource vnetHub 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: vnetHubConfig.name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetHubConfig.addressSpacePrefix
      ]
    }
    subnets: [for subnet in vnetHubConfig.subnets: {
      name: subnet.name
      properties: subnet.properties
    }]
  }
}

resource vnetSpoke 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: vnetSpokeConfig.name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetSpokeConfig.addressSpacePrefix
      ]
    }
    subnets: [for subnet in vnetSpokeConfig.subnets: {
      name: subnet.name
      properties: subnet.properties
    }]
  }
}


resource VnetHubPeeringToSpoke 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-05-01' = {
  parent: vnetHub
  name: '${vnetHub.name}-${vnetSpoke.name}'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: false
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: vnetSpoke.id
    }
  }
}

resource vnetPeering2 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-05-01' = {
  parent: vnetSpoke
  name: '${vnetSpoke.name}-${vnetHub.name}'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: false
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: vnetHub.id
    }
  }
}
