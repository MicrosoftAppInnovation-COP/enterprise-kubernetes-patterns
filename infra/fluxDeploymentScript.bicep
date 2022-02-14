param location string
param aksClusterName string

@secure()
param githubToken string
param githubRepository string
param githubBranch string = 'main'

@description('This should align to gitops deployments for cluster services')
param gitopsNamespace string = 'ghrunner-namespace'

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'postDeploymentMI'
  location: location
}

//34e09817-6cbe-4d01-b1a2-e0eac5743d41
//Azure Arc Onboarding Role https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#kubernetes-cluster---azure-arc-onboarding
resource deploymentScriptRoleAssignment_Arc 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid(managedIdentity.id, resourceGroup().id, 'arc')
  properties: {
    principalId: managedIdentity.properties.principalId
    roleDefinitionId: '${subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '34e09817-6cbe-4d01-b1a2-e0eac5743d41')}'
    principalType: 'ServicePrincipal'
  }
}

//0ab0b1a8-8aac-4efd-b8c2-3ee1fb270be8
//AKS Cluster User Role https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#azure-kubernetes-service-cluster-admin-role
resource deploymentScriptRoleAssignment_AKS 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid(managedIdentity.id, resourceGroup().id, 'aks')
  properties: {
    principalId: managedIdentity.properties.principalId
    roleDefinitionId: '${subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4abbcc35-e782-43d8-92c5-2d3f1bd2253f')}'
    principalType: 'ServicePrincipal'
  }
}

resource aksCluster 'Microsoft.ContainerService/managedClusters@2021-10-01' existing = {
  name: aksClusterName
}

//contributor on AKS
var roleAssignmentName = guid(managedIdentity.id, resourceGroup().id, 'aks-contributor')
resource aksRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: roleAssignmentName
  scope: aksCluster
  properties: {
    principalId: managedIdentity.properties.principalId
    roleDefinitionId: '${subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')}'
    principalType: 'ServicePrincipal'
  }
}

resource azureArcDeploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'azureArcDeploymentScript'
  location: location
  kind: 'AzureCLI'
  dependsOn: [
    aksRoleAssignment
    deploymentScriptRoleAssignment_AKS
    deploymentScriptRoleAssignment_Arc
  ]
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
     '${managedIdentity.id}': {} 
    }
  }
  properties: {
    azCliVersion: '2.32.0'
    retentionInterval: 'P1D'
    environmentVariables: [
      {
        name: 'CLUSTER_NAME'
        value: aksClusterName
      }
      {
        name: 'RESOURCE_GROUP'
        value: resourceGroup().name
      }
      {
        name: 'LOCATION'
        value: location
      }
      {
        name: 'GITHUB_TOKEN'
        secureValue: githubToken
      }
      {
        name: 'GITHUB_REPOSITORY'
        value: githubRepository
      }
      {
        name: 'GITHUB_BRANCH'
        value: githubBranch
      }
      {
        name: 'GITOPS_NAMESPACE'
        value: gitopsNamespace
      }
    ]
    scriptContent: '''
      az extension add -n k8s-configuration
      az extension add -n k8s-extension

      az aks command invoke \
        --resource-group $RESOURCE_GROUP \
        --name $CLUSTER_NAME \
        --command "kubectl create ns ${GITOPS_NAMESPACE}"

      az aks command invoke \
        --resource-group $RESOURCE_GROUP \
        --name $CLUSTER_NAME \
        --command "kubectl create secret generic controller-manager -n ${GITOPS_NAMESPACE} --from-literal=github_token=${GITHUB_TOKEN}"

      az k8s-configuration flux create \
        -g $RESOURCE_GROUP \
        -c $CLUSTER_NAME \
        -n gitops-setup \
        --namespace $GITOPS_NAMESPACE \
        -t managedClusters \
        --scope cluster \
        -u $GITHUB_REPOSITORY \
        --branch $GITHUB_BRANCH \
        --kustomization name=clusterservices path=./gitops/cluster-services prune=true \
        --kustomization name=githubrunners path=./gitops/github-runner/github-runner-deployment prune=true dependsOn=["clusterservices"] interval=3m
    '''
  }
}


