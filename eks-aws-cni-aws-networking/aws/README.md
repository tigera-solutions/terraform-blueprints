# AWS CNI with Calico Security Policy

This example demonstrates how to provision an EKS cluster using the AWS CNI with Calico security policies.

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
NAMESPACE          NAME                                       READY   STATUS    RESTARTS   AGE
calico-apiserver   calico-apiserver-dbf6d64dc-7f9rp           1/1     Running   0          110s
calico-apiserver   calico-apiserver-dbf6d64dc-q44r7           1/1     Running   0          110s
calico-system      calico-kube-controllers-5fc6cb9c78-mwkk5   1/1     Running   0          2m12s
calico-system      calico-node-5645l                          1/1     Running   0          2m12s
calico-system      calico-node-cx868                          1/1     Running   0          2m12s
calico-system      calico-typha-76677b656b-zffsp              1/1     Running   0          2m12s
calico-system      csi-node-driver-k4dzn                      2/2     Running   0          2m12s
calico-system      csi-node-driver-vsrlq                      2/2     Running   0          2m12s
kube-system        aws-node-l5sq6                             1/1     Running   0          3m11s
kube-system        aws-node-n4xf9                             1/1     Running   0          3m9s
kube-system        coredns-55fb5d545d-w2tq8                   1/1     Running   0          10m
kube-system        coredns-55fb5d545d-x5np4                   1/1     Running   0          10m
kube-system        kube-proxy-lnlc4                           1/1     Running   0          3m11s
kube-system        kube-proxy-xjhfk                           1/1     Running   0          3m9s
tigera-operator    tigera-operator-5d6845b496-fghhn           1/1     Running   0          2m18s
```

3. View the nodes that were created:

```sh
kubectl get nodes

# Output should show some nodes running
NAME                           STATUS   ROLES    AGE   VERSION
ip-10-0-163-151.ec2.internal   Ready    <none>   11m   v1.24.10-eks-48e63af
ip-10-0-163-9.ec2.internal     Ready    <none>   10m   v1.24.10-eks-48e63af
```

### Destroy

To teardown and remove the resources created in this example:

```sh
terraform state rm helm_release.calico
terraform destroy --auto-approve
```
