# Prereq

1. Register the `Microsoft.Network/AllowMultipleAddressPrefixesOnSubnet` resource type to your subscription:

    ```bash
    az feature show --namespace Microsoft.Network --name AllowMultipleAddressPrefixesOnSubnet
    az feature register --namespace Microsoft.Network --name AllowMultipleAddressPrefixesOnSubnet
    ```