param location string

@description('kubelet managed identity')
param kubeletManagedIdentityPrincipalId string

@allowed([
  'Premium'
])
@description('Tier of your Azure Container Registry.')
param acrSku string = 'Premium'

@description('Enable an admin user that has push/pull permission to the registry.')
param acrAdminUserEnabled bool = false

param hubVirtualNetworkName string = 'hub'
param spokeVirtualNetworkName string = 'spoke'
param spokeSubnetName string = 'ServicesSubnet'
var acrSubnetId = resourceId('Microsoft.Network/virtualNetworks/subnets', spokeVirtualNetworkName, spokeSubnetName)

var acrName  = 'acr${uniqueString(resourceGroup().id)}'
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-06-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: acrSku
  }
  properties: {
    adminUserEnabled: acrAdminUserEnabled
    networkRuleBypassOptions: 'AzureServices'
    publicNetworkAccess: 'Disabled'
  }
}

var acrPullRoleAssignmentName = guid(kubeletManagedIdentityPrincipalId, resourceGroup().id, 'acr')
resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: acrPullRoleAssignmentName
  scope: containerRegistry
  properties: {
    principalId: kubeletManagedIdentityPrincipalId
    roleDefinitionId: '${subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')}'
    principalType: 'ServicePrincipal'
  }
}

resource acrPrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: 'acrpe${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    subnet: {
      id: acrSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'acrpe${uniqueString(resourceGroup().id)}'
        properties: {
          privateLinkServiceId: containerRegistry.id
          groupIds: [
            'registry'
          ]
        }
      }
    ]
  }

  resource privateDnsZoneGroup 'privateDnsZoneGroups' = {
    name: 'acrDnsZoneGroup'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'config'
          properties: {
            privateDnsZoneId: acrDnsZone.id
          }
        }
      ]
    }
  }
}

var acrDnsZoneName = 'privatelink.azurecr.io'
resource acrDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: acrDnsZoneName
  location: 'global'
  resource  hubVnetLink 'virtualNetworkLinks' = {
    name: 'acrHubVnetLink'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: resourceId('Microsoft.Network/virtualNetworks', hubVirtualNetworkName)
      }
    }
  }

  resource  spokeVnetLink 'virtualNetworkLinks' = {
    name: 'acrSpokeVnetLink'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: resourceId('Microsoft.Network/virtualNetworks', spokeVirtualNetworkName)
      }
    }
  }
}

