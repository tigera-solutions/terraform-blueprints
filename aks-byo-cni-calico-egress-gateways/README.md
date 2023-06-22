# AKS BYO CNI Cluster With Custom Networking and Egress Gateways

In this repository, we enhance the architecture described in the medium article titled [Create a "Fully private” AKS infrastructure with Terraform](https://medium.com/@paveltuzov/create-a-fully-private-aks-infrastructure-with-terraform-e92358f0bf65?source=friends_link&sk=124faab1bb557c25c0ed536ae09af0a3). Our goal is to incorporate Egress Gateways, enabling us to identify the Kubernetes workloads that pass through the Azure Firewall.

## SSH into jump host

The terraform apply output will provide you with a command to ssh into the jump host.  Once you're on the jump host.  Authenticate to Azure and then add update the aks credentials.

```
az login
```

```
az aks get-credentials --name spoke1-private-aks --resource-group private-aks
az aks get-credentials --name spoke2-private-aks --resource-group private-aks
```

## Prerequisites:

First, ensure that you have installed the following tools locally.

1. [aws cli](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
2. [kubectl](https://Kubernetes.io/docs/tasks/tools/)
3. [terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)

### Deploy

To provision this example:

```sh
terraform init
terraform apply
```

Enter `yes` at command prompt to apply

### Validate

1. SSH to the jump-host


2. Authenticate to Azure. Open the URL in a browser and enter the code.

```sh
az login
```

3. Update the kubeconfig on the jump-host

```sh
az aks get-credentials --name <SPOKE1 CLUSTER_NAME> --resource-group <SPOKE RESOURCE GROUP>
az aks get-credentials --name <SPOKE2 CLUSTER_NAME> --resource-group <SPOKE RESOURCE GROUP>
```

2. View the pods that were created:

```sh
kubectl get pods -A

# Output should show some pods running
```

3. View the nodes that were created:

```sh
kubectl get nodes

# Output should show some nodes running
```

### Destroy

To teardown and remove the resources created in this example:

```sh
terraform destroy --auto-approve
```
