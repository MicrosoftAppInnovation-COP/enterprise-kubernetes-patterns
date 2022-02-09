# GitHub Self-Hosted Agent in Container

1. The `ghrdocker/Dockerfile` has been updated to include the following tools:
    - kubectl
    - helm
    - az cli

## Improvements

Currently there is no way to run github actions that are docker containers within this runner. Ideally those are run as other jobs or we leverage other approaches to run those.

## Reference
- https://github.com/Azure/aks-github-runner