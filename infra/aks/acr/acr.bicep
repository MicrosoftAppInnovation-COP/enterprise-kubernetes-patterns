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


param githubRepository string
var acrName  = 'acr${uniqueString(resourceGroup().id)}'
var dockerfileContextPath = 'gitops/github-runner/Dockerfile'
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

  resource runnerBuildTask 'tasks@2019-06-01-preview' = {
    name: 'githubRunnerBuildTask'
    location: location
    identity: {
      type: 'SystemAssigned'
    }
    properties: {
      platform: {
        os: 'Linux'
      }
      credentials: {
        customRegistries: {
          '${containerRegistry.properties.loginServer}': {
            'identity': '[system]'
          }
        }
        sourceRegistry: {
          loginMode: 'Default'
        }
      }
      status: 'Enabled'
      step: {
        type: 'Docker'
        dockerFilePath: dockerfileContextPath
        contextPath: '${githubRepository}.git'
        imageNames: [
          'custom-gh-runner:latest'
        ]
        isPushEnabled: true
      }
    }
  }
}


resource acrTaskPushRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid(containerRegistry::runnerBuildTask.id, 'acrTask')
  scope: containerRegistry
  properties: {
    principalId: containerRegistry::runnerBuildTask.identity.principalId
    roleDefinitionId: '${subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8311e382-0749-4cb8-b61a-304f252e45ec')}'
    principalType: 'ServicePrincipal'
  }
}

resource acrTaskRun 'Microsoft.ContainerRegistry/registries/taskRuns@2019-06-01-preview' = {
  name: 'acrTaskRunGitHubRunner'
  parent: containerRegistry
  location: location
  dependsOn: [
    acrTaskPushRoleAssignment
  ]
  properties: {
    runRequest: {
      type: 'TaskRunRequest'
      taskId: containerRegistry::runnerBuildTask.id
    }
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

