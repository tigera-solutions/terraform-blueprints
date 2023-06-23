# Calico CNI with eBPF Dataplane

This example demonstrates how to provision an EKS cluster using the Calico CNI with eBPF dataplane.

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

1. Run `update-kubeconfig` command:

```sh
aws eks --region <REGION> update-kubeconfig --name <CLUSTER_NAME> --alias <CLUSTER_NAME>
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

### Destroy

To teardown and remove the resources created in this example:

```sh
terraform state rm helm_release.calico
terraform destroy --auto-approve
```
