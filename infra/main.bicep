targetScope = 'subscription'

param location string = 'eastus'
param resourceGroupName string = 'app-innovation-landing-zone'

@description('Obtain your local client IP to use for secure Cloud Shell Access')
param clientIp string

@description('Obtain the Azure Container Instance Object ID')
param azureContainerInstanceOID string

@description('Pass in your public SSH Key for node ssh access to aks')
param aksPublicKeySSH string

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
}

module vnets 'network/network.bicep' = {
  scope: resourceGroup
  name: 'vnetDeployment'
  params: {
    location: resourceGroup.location
  }
}

module cloudShell 'jumpbox/cloud-shell.bicep' = {
  scope: resourceGroup
  name: 'cloudShellDeployment'
  params: {
    azureContainerInstanceOID: azureContainerInstanceOID
    clientIp: clientIp
    location: resourceGroup.location
  }
  dependsOn: [
    vnets
  ]
}

module containerServices 'aks/aks.bicep' = {
  scope: resourceGroup
  name: 'containerServicesDeployment'
  params: {
    aksClusterSshPublicKey: aksPublicKeySSH
    location: resourceGroup.location
  }
  dependsOn: [
    vnets
  ]
}
