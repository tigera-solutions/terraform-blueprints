# AWS EKS Calico Cluster Mesh

This example demonstrates how to provision two AWS EKS clusters, each within its own Virtual Private Cloud (VPC), peered together to enable direct network communication between the clusters. The clusters utilize the Calico Container Network Interface (CNI) plugin for network policy enforcement and pod networking, with custom networking configurations to facilitate inter-cluster communication. This setup allows for seamless connectivity between pods across the two peered VPCs, making it ideal for scenarios requiring cross-cluster communication, such as distributed applications or disaster recovery setups. Routing rules are configured to ensure that traffic between the clusters flows through the VPC peering connection, leveraging Calico's network policies for enhanced security and control over inter-cluster traffic.

## Prerequisites:

First, ensure that you have installed the following tools locally.

1. [aws cli](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
2. [kubectl](https://Kubernetes.io/docs/tasks/tools/)
3. [terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)

### Deploy

Examine [terraform.tfvars](terraform.tfvars)`.

```
region1         = "us-east-1"
region2         = "us-west-2"
vpc1_cidr       = "10.0.0.0/16"
vpc2_cidr       = "10.1.0.0/16"
cluster1_name   = "iad"
cluster2_name   = "pdx"
cluster_version = "1.27"
instance_type   = "m5.xlarge"
desired_size    = 3
ssh_keyname     = "your-ssh-keyname"
pod_cidr1       = "192.168.1.0/24"
pod_cidr2       = "192.168.2.0/24"
calico_version  = "v3.26.4"
calico_encap    = "VXLAN"
```

To provision this example:

```sh
terraform init
terraform apply
```

Enter `yes` at command prompt to apply

To provision this example on ARM based compute:

```
terraform init
terraform apply --auto-approve --var instance_type="m7g.2xlarge" --var ami_type="AL2_ARM_64"
```

Enter `yes` at command prompt to apply

### Validate

1. Run `update-kubeconfig` command:

```sh
aws eks --region <REGION1> update-kubeconfig --name <CLUSTER_NAME1> --alias <CLUSTER_NAME1>
aws eks --region <REGION2> update-kubeconfig --name <CLUSTER_NAME2> --alias <CLUSTER_NAME2>
```

2. View the pods that were created:

```sh
kubectl get pods -A

# Output should show some pods running
NAMESPACE              NAME                                          READY   STATUS    RESTARTS   AGE
calico-apiserver   calico-apiserver-c5d849cb9-4vqwt                1/1     Running   0             21h
calico-apiserver   calico-apiserver-c5d849cb9-lz26w                1/1     Running   0             21h
calico-system      calico-kube-controllers-79dd9b4447-89pf4        1/1     Running   0             21h
calico-system      calico-node-5g4zl                               1/1     Running   0             21h
calico-system      calico-node-84kxs                               1/1     Running   0             21h
calico-system      calico-node-dkrh9                               1/1     Running   0             21h
calico-system      calico-node-t74c9                               1/1     Running   0             21h
calico-system      calico-typha-79d6fdd6df-49pdq                   1/1     Running   0             21h
calico-system      calico-typha-79d6fdd6df-7wcbc                   1/1     Running   0             21h
calico-system      csi-node-driver-bcdvq                           2/2     Running   0             21h
calico-system      csi-node-driver-qptz8                           2/2     Running   0             21h
calico-system      csi-node-driver-snqhh                           2/2     Running   0             21h
calico-system      csi-node-driver-zl2k5                           2/2     Running   0             21h
kube-system        aws-load-balancer-controller-7c69bf8547-2snn2   1/1     Running   0             3h30m
kube-system        aws-load-balancer-controller-7c69bf8547-d7jwv   1/1     Running   0             3h30m
kube-system        coredns-79989457d9-9db9q                        1/1     Running   0             24h
kube-system        coredns-79989457d9-9dkcx                        1/1     Running   0             24h
kube-system        kube-proxy-9kcxj                                1/1     Running   0             21h
kube-system        kube-proxy-n5mks                                1/1     Running   0             21h
kube-system        kube-proxy-xb9r4                                1/1     Running   0             21h
kube-system        kube-proxy-xmsvk                                1/1     Running   0             21h
kube-system        metrics-server-7ccc978454-6r79c                 1/1     Running   0             21h
tigera-operator    tigera-operator-6bb888d6fc-wzl48                1/1     Running   1 (21h ago)   21h
```

3. View the nodes that were created:

```sh
kubectl get nodes

# Output should show some nodes running
NAME                           STATUS   ROLES    AGE   VERSION
ip-10-0-163-151.ec2.internal   Ready    <none>   11m   v1.24.10-eks-48e63af
ip-10-0-163-9.ec2.internal     Ready    <none>   10m   v1.24.10-eks-48e63af
ip-10-0-182-227.ec2.internal   Ready    <none>   11m   v1.24.10-eks-48e63af
ip-10-0-191-7.ec2.internal     Ready    <none>   10m   v1.24.10-eks-48e63af
```

### Join Clusters to Calico Cloud

### Setup Calico Cluster Mesh

```
sh setup-mesh.sh
```

```
Setting up mesh between iad and pdx...
Switched to context "iad".
serviceaccount/tigera-federation-remote-cluster created
clusterrole.rbac.authorization.k8s.io/tigera-federation-remote-cluster created
clusterrolebinding.rbac.authorization.k8s.io/tigera-federation-remote-cluster created
secret/tigera-federation-remote-cluster created
secret/pdx-secret created
remoteclusterconfiguration.projectcalico.org/pdx created
Switched to context "pdx".
role.rbac.authorization.k8s.io/remote-cluster-secret-access created
rolebinding.rbac.authorization.k8s.io/remote-cluster-secret-access created
Mesh setup from iad to pdx completed
Setting up mesh between pdx and iad...
Switched to context "pdx".
serviceaccount/tigera-federation-remote-cluster created
clusterrole.rbac.authorization.k8s.io/tigera-federation-remote-cluster created
clusterrolebinding.rbac.authorization.k8s.io/tigera-federation-remote-cluster created
secret/tigera-federation-remote-cluster created
secret/iad-secret created
remoteclusterconfiguration.projectcalico.org/iad created
Switched to context "iad".
role.rbac.authorization.k8s.io/remote-cluster-secret-access created
rolebinding.rbac.authorization.k8s.io/remote-cluster-secret-access created
Mesh setup from pdx to iad completed
```

```
kubectl --context iad logs deployment/calico-typha -n calico-system | grep "Sending in-sync update"
kubectl --context pdx logs deployment/calico-typha -n calico-system | grep "Sending in-sync update"
```

```
2024-02-27 01:51:06.156 [INFO][13] wrappedcallbacks.go 487: Sending in-sync update for RemoteClusterConfiguration(pdx)
2024-02-27 01:51:03.300 [INFO][13] wrappedcallbacks.go 487: Sending in-sync update for RemoteClusterConfiguration(iad)
```

### Destroy

To teardown and remove the resources created in this example:

```sh
terraform state rm helm_release.calico_cluster1
terraform state rm helm_release.calico_cluster2
terraform destroy --auto-approve
```
