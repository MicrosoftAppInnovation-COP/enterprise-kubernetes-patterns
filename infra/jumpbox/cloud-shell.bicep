@description('Object Id of Azure Container Instance Service Principal. We have to grant this permission to create hybrid connections in the Azure Relay you specify. To get it: Get-AzADServicePrincipal -DisplayNameBeginsWith \'Azure Container Instance\'')
param azureContainerInstanceOID string

@description('Name of Private Endpoint for Azure Relay.')
param privateEndpointName string = 'cloudshellRelayEndpoint'

@description('Location for all resources.')
param location string

@description('Your client IP to access cloud shell')
param clientIp string

param cloudShellSubnetName string = 'CloudShellSubnet'
var cloudShellSubnetId = resourceId('Microsoft.Network/virtualNetworks/subnets', hubVnetName, cloudShellSubnetName)

param relaySubnetName string = 'RelaySubnet'
var relaySubnetId = resourceId('Microsoft.Network/virtualNetworks/subnets', hubVnetName, relaySubnetName)

param hubVnetName string = 'hub'

var networkProfileName = 'aci-networkProfile-${location}'
var contributorRoleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
var networkRoleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', '4d97b98b-1d4f-4787-a291-c67834d212e7')
var privateDnsZoneName = ((toLower(environment().name) == 'azureusgovernment') ? 'privatelink.servicebus.usgovcloudapi.net' : 'privatelink.servicebus.windows.net')
var vnetResourceId = resourceId('Microsoft.Network/virtualNetworks', hubVnetName)

resource networkProfile 'Microsoft.Network/networkProfiles@2019-11-01' = {
  name: networkProfileName
  location: location
  properties: {
    containerNetworkInterfaceConfigurations: [
      {
        name: 'eth-${cloudShellSubnetName}'
        properties: {
          ipConfigurations: [
            {
              name: 'ipconfig-${cloudShellSubnetName}'
              properties: {
                subnet: {
                  id: cloudShellSubnetId
                }
              }
            }
          ]
        }
      }
    ]
  }
}

resource networkProfile_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: networkProfile
  name: guid(networkRoleDefinitionId, azureContainerInstanceOID, networkProfile.name)
  properties: {
    roleDefinitionId: networkRoleDefinitionId
    principalId: azureContainerInstanceOID
  }
}

var relayNamespaceName  = 'relay${uniqueString(resourceGroup().id)}'
resource relayNamespace 'Microsoft.Relay/namespaces@2018-01-01-preview' = {
  name: relayNamespaceName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }

  resource networkRule 'networkRuleSets@2018-01-01-preview' = {
    name: 'default'
    properties: {
      defaultAction: 'Deny'
      ipRules: [
        {
          action: 'Allow'
          ipMask: clientIp
        }
      ]
    }
  }
}

resource relayNamespace_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: relayNamespace
  name: guid(contributorRoleDefinitionId, azureContainerInstanceOID, relayNamespace.name)
  properties: {
    roleDefinitionId: contributorRoleDefinitionId
    principalId: azureContainerInstanceOID
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2020-04-01' = {
  name: privateEndpointName
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: privateEndpointName
        properties: {
          privateLinkServiceId: relayNamespace.id
          groupIds: [
            'namespace'
          ]
        }
      }
    ]
    subnet: {
      id: relaySubnetId
    }
  }
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-01-01' = {
  name: privateDnsZoneName
  location: 'global'
}

resource privateDnsZoneARecord 'Microsoft.Network/privateDnsZones/A@2020-01-01' = {
  parent: privateDnsZone
  name: relayNamespaceName
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: first(first(privateEndpoint.properties.customDnsConfigs).ipAddresses)
      }
    ]
  }
}

resource privateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-01-01' = {
  parent: privateDnsZone
  name: relayNamespaceName
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetResourceId
    }
  }
}

var storageAccountName  = 'cs${uniqueString(resourceGroup().id)}'
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    networkAcls: {
      defaultAction: 'Deny'
      virtualNetworkRules: [
        {
          id: cloudShellSubnetId
          action: 'Allow'
        }
      ]
    }
  }
  
  resource blob 'blobServices' = {
    name: 'default'
    properties: {
      deleteRetentionPolicy: {
        enabled: false
      }
    }
  }

  resource fileShare 'fileServices' = {
    name: 'default'

    resource fileShare 'shares' = {
      name: 'cloudshell'
      properties: {
        shareQuota: 6
      }
    }
  }
}
