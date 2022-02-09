# Required GitHub Actions Secrets for Workflows

1. `ACR_REGISTRY_NAME`: This is the name of the ACR resource deployed (do not include `.azurecr.io`, only the resource name itself)
2. `AZURE_CREDENTIALS`: This is the service principal that the agent uses to authenticate to Azure. Contributor on ACR
    > You will need to create the service principal with the following command and copy and paste the full json to the secret:

    ```bash
    export SUBSCRIPTION_ID=$(az account show --query 'id')
    export RESOURCE_GROUP=app-innovation-landing-zone #update as needed
    export ACR_RESOURCE_ID=$(az acr list -g $RESOURCE_GROUP -o tsv --query '[0].id') #assumes only one ACR in the resource group
    az ad sp create-for-rbac --name "githubActionServicePrincipal" \
                            --role Contributor \
                            --scopes $ACR_RESOURCE_ID \
                            --sdk-auth
                            
    # The command should output a JSON object similar to this which you should copy and paste
    {
        "clientId": "<GUID>",
        "clientSecret": "<GUID>",
        "subscriptionId": "<GUID>",
        "tenantId": "<GUID>",
        (...)
    }
    ```