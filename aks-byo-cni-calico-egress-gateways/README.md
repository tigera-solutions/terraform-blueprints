# AKS BYO CNI Cluster With Custom Networking and Egress Gateways

Manage a "Fully" private AKS infrastructure with Terraform.

Explanation in details in this [medium article](https://medium.com/@paveltuzov/create-a-fully-private-aks-infrastructure-with-terraform-e92358f0bf65?source=friends_link&sk=124faab1bb557c25c0ed536ae09af0a3).

## Running the script

After you configure authentication with Azure, just init and apply (no inputs are required):

`terraform init`

`terraform apply`

## SSH into jump host

The terraform apply output will provide you with a command to ssh into the jump host.  Once you're on the jump host.  Authenticate to Azure and then add update the aks credentials.

```
az login
```

```
az aks get-credentials --name spoke1-private-aks --resource-group private-aks
az aks get-credentials --name spoke2-private-aks --resource-group private-aks
```

## Deploy Calico Enterprise and Egress Gateways
