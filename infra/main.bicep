targetScope = 'subscription'

param location string = 'eastus'
param resourceGroupName string = 'app-innovation-landing-zone'

@description('Obtain your local client IP to use for secure Cloud Shell Access')
param clientIp string

@description('Obtain the Azure Container Instance Object ID')
param azureContainerInstanceOID string

@description('Pass in your public SSH Key for node ssh access to aks')
param aksPublicKeySSH string

@description('AKS Cluster Name')
param aksClusterName string = 'akscluster'

@description('GitHub Repository')
param githubRepository string = 'https://github.com/haithamshahin333/enterprise-kubernetes-patterns'

@description('GitHub Branch for gitops config')
param githubBranch string = 'main'

@secure()
@description('GitHub PAT Token for GitHub Self-Hosted Runners')
param githubToken string

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
    aksClusterName: aksClusterName
  }
  dependsOn: [
    vnets
  ]
}

module arcDeploymentScript 'arcDeploymentScript.bicep' = {
  scope: resourceGroup
  name: 'arcDeploymentScript'
  params: {
    location: location
    aksClusterName: aksClusterName
    githubToken: githubToken
    githubRepository: githubRepository
    githubBranch: githubBranch
  }
  dependsOn: [
    containerServices
  ]
}
