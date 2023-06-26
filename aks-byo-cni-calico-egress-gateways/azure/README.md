# AKS BYO CNI Cluster With Custom Networking and Egress Gateways


## Prerequisites:

First, ensure that you have installed the following tools locally.

1. [azure cli](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
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

You should see similar terraform outputs.

```
Apply complete! Resources: 0 added, 1 changed, 0 destroyed.

Outputs:

ssh_command = "ssh azureuser@<PUBLIC IPADDRESS >"
```

2. Authenticate to Azure. Open the URL in a browser and enter the code.

```sh
az login
```

3. Update the kubeconfig on the jump-host

```sh
az aks get-credentials --name <SPOKE1 CLUSTER_NAME> --resource-group <SPOKE RESOURCE GROUP>
az aks get-credentials --name <SPOKE2 CLUSTER_NAME> --resource-group <SPOKE RESOURCE GROUP>
```

4. View the pods that were created:

```sh
kubectl get pods -A

# Output should show some pods running
```

5. View the nodes that were created:

```sh
kubectl get nodes

# Output should show some nodes running
```

### Destroy

To teardown and remove the resources created in this example:

```sh
terraform destroy --auto-approve
```
