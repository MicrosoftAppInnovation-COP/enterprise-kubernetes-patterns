# App Innovation Landing Zone with Kubernetes, GitHub, and Java

## Overview of Landing Zone and Applied Patterns

1. [Infrastructure-as-Code](https://docs.microsoft.com/en-us/devops/deliver/what-is-infrastructure-as-code) with [Azure Bicep](https://github.com/Azure/bicep)

2. [Private Azure Kubernetes Service](https://docs.microsoft.com/en-us/azure/aks/private-clusters)

3. [GitOps with Flux v2](https://docs.microsoft.com/en-us/azure/azure-arc/kubernetes/conceptual-gitops-flux2)

4. [GitHub Self-Hosted Runners in Containers](https://github.com/actions-runner-controller/actions-runner-controller)

    - To further show patterns here, we are leveraging a [custom image](./gitops/github-runner/Dockerfile) since there are certains tools needed in the runner that are not pre-installed by the actions-runner-controller base image.

5. [Private-Endpoint Enabled ACR with ACR Build Tasks](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-tasks-overview)

    - To support our private, enterprise deployment we create ACR with a Private Endpoint within the VNET.

    - ACR Tasks can be used for your custom builds and can also run import jobs so that upstream images/artifacts/helm charts are pulled locally to your secure ACR instance.
    
    - Since ACR is exposed only through a private endpoint, we need to find a way to enable ACR Tasks to communicate with ACR. There are a few different ways to accomplish this:

        1. Use a managed identity for the ACR Task and ensure that your ACR instance enables access from [Trusted Services](https://docs.microsoft.com/en-us/azure/container-registry/allow-access-trusted-services#trusted-services).

            > Currently this repo demonstrates this approach with a managed identity on the ACR Task

        2. Use Azure Container Instances with a managed identity and ensure that your ACR instance enables access from [Trusted Services](https://docs.microsoft.com/en-us/azure/container-registry/allow-access-trusted-services#trusted-services).

        3. Run jobs from within AKS to communicate to ACR through the az cli (could levage Pod Identities to provide permissions to the job based on it's desired functionality).

## Getting Started

1. Run the commands specified in the [infra deployment instructions](./infra/README.md) to deploy the following with Bicep:

![app-innovation-landing-zone-architecture](./assets/app-innovation-landing-zone-architecture.png)