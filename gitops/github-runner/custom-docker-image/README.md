# GitHub Self-Hosted Agent in Container

1. The `ghrdocker/Dockerfile` has been updated to include the following tools:
    - kubectl
    - helm
    - az cli

# Steps to Deploy (Occurs After Bicep Deployment Completes)

1. From cloud shell, clone the repo, and call ACR to build and store github runner image:

```bash
git clone https://github.com/haithamshahin333/enterprise-kubernetes-patterns.git

# clone the repo and navigate to github-runner/ghrdocker
cd github-runner/ghrdocker

# call a build task in ACR
export ACR_NAME=
az acr build -t runner/ghagent:latest -r $ACR_NAME .
```

2. Navigate to the `./github-runner/ghrhelm` repo and open `values.yaml`:

```bash
# assuming you're coming from github-runner/ghrdocker
cd ../ghrhelm

# open values.yaml
code values.yaml

3. Update `values.yaml` with the following:

```yaml
# update the repository value to your ACR registry where the runner is located
image:
  repository: "<ACR_REGISTRY_NAME>.azurecr.io/runner/ghagent"
  pullPolicy: IfNotPresent
  tag: latest

(...)

# update the following so that the runner can connect to your repo
# repo_owner > your username or org
# repo_name > your repo's name
# repo_url > will be something like https://github.com/$REPO_OWNER/$REPO_NAME
# github_token > generate a PAT for the runner with repo scope to authenticate
    # https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token
    # The agent token will require repo (full control) scopes if using a repository runner
    # More scopes will be required for organization runers
ghr:
  repo_owner: ""
  repo_name: ""
  repo_url: ""
  github_token: ""
```

4. Once `values.yaml` is setup, run the following to deploy:

```bash
export AKS_NAME=
export RESOURCE_GROUP=
az aks get-credentials -n $AKS_NAME -g $RESOURCE_GROUP

kubectl create ns devops
helm install ghrunner . --namespace devops
```

## Improvements

Currently there is no way to run github actions that are docker containers within this runner. Ideally those are run as other jobs or we leverage other approaches to run those.

## Reference
- https://github.com/Azure/aks-github-runner