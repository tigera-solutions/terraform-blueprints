# AWS EKS Calico Cluster Mesh

This example demonstrates how to provision two AWS EKS clusters, each within its own Virtual Private Cloud (VPC), peered together to enable direct network communication between the clusters. The clusters utilize the Calico Container Network Interface (CNI) plugin for network policy enforcement and pod networking, with custom networking configurations to facilitate inter-cluster communication. This setup allows for seamless connectivity between pods across the two peered VPCs, making it ideal for scenarios requiring cross-cluster communication, such as distributed applications or disaster recovery setups. Routing rules are configured to ensure that traffic between the clusters flows through the VPC peering connection, leveraging Calico's network policies for enhanced security and control over inter-cluster traffic.

## Solution Overview

## Walk Through

We'll use Terraform, an infrastructure-as-code tool, to deploy this reference architecture automatically. We'll walk you through the deployment process and then demonstrate how to utilize [Calico Cluster Mesh on AWS](https://docs.tigera.io/calico-enterprise/latest/multicluster/federation/overview)

### Prerequisites:

First, ensure that you have installed the following tools locally.

1. [aws cli](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
2. [kubectl](https://Kubernetes.io/docs/tasks/tools/)
3. [terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
3. [jq](https://jqlang.github.io/jq/download/)

### Step 1: Checkout and Deploy the Terraform Blueprint

#### 1. Clone the Terraform Blueprint
Make sure you have completed the prerequisites and then clone the Terraform blueprint:
```sh
git clone git@github.com:tigera-solutions/terraform-blueprints.git
```

#### 2. Navigate to the AWS Directory
Switch to the `aws` subdirectory:
```sh
cd eks-calico-cni-calico-cluster-mesh/aws
```

#### 3. Customize Terraform Configuration
Optional: Edit the [terraform.tfvars](terraform.tfvars) file to customize the configuration.

Examine [terraform.tfvars](terraform.tfvars)`.

```sh
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

#### 4. Deploy the Infrastructure
Initialize and apply the Terraform configurations:
```sh
terraform init
terraform apply
```

Enter `yes` at command prompt to apply

To provision this example on ARM based compute:

```sh
terraform init
terraform apply --auto-approve --var instance_type="m7g.2xlarge" --var ami_type="AL2_ARM_64"
```

Enter `yes` at command prompt to apply

#### 5. Update Kubernetes Configuration
Update your kubeconfig with the EKS cluster credentials as indicated in the Terraform output:

```sh
aws eks --region <REGION1> update-kubeconfig --name <CLUSTER_NAME1> --alias <CLUSTER_NAME1>
aws eks --region <REGION2> update-kubeconfig --name <CLUSTER_NAME2> --alias <CLUSTER_NAME2>
```

#### 6. Verify Calico Installation
Check the status of Calico in your EKS cluster:
```sh
kubectl get tigerastatus
```

### Step 2: Link Your EKS Cluster to Calico Cloud

#### 1. Join the EKS Cluster to Calico Cloud
Join your EKS cluster to [Calico Cloud](https://www.calicocloud.io/home) as illustrated:

<INSERT IMAGE>

#### 2. Verify the Cluster Status
Check the cluster status:
```sh
kubectl get tigerastatus
```

## Step 3: Configure Cluster Mesh for AWS Elastic Kubernetes Service

#### 1. Update the Felix Configuration
Set the flow logs flush interval:
```sh
kubectl patch felixconfiguration default --type='merge' -p '{
  "spec": {
    "dnsLogsFlushInterval": "15s",
    "l7LogsFlushInterval": "15s",
    "flowLogsFlushInterval": "15s",
    "flowLogsFileAggregationKindForAllowed": 1
  }
}'
```

#### 2. Create the Cluster Mesh
Run the `setup-mesh.sh` script:
```sh
cd ..
sh setup-mesh.sh
```

```sh
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

## Validate the Deployment and Review the Results

#### 1. Confirm Calico Cluster Mesh enabled clusters are in-sync
Check logs for remote cluster connection status:
```sh
kubectl --context iad logs deployment/calico-typha -n calico-system | grep "Sending in-sync update"
kubectl --context pdx logs deployment/calico-typha -n calico-system | grep "Sending in-sync update"
```

```
2024-02-27 01:51:06.156 [INFO][13] wrappedcallbacks.go 487: Sending in-sync update for RemoteClusterConfiguration(pdx)
2024-02-27 01:51:03.300 [INFO][13] wrappedcallbacks.go 487: Sending in-sync update for RemoteClusterConfiguration(iad)
```

You should see similar messages for each of the clusters in your cluster mesh.

#### 2. Deploy Statefulsets and Headless Services
Return to the project root and apply the manifests:
```sh
cd ..
kubectl apply -f manifests
```

#### 2. Implement Calico Federated Services for Calico Cluster Mesh
Test the configuration of each Service:

```sh
kubectl --context pdx get svc
```

```sh
NAME                TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
kubernetes          ClusterIP   172.20.0.1   <none>        443/TCP   20h
web-iad-federated   ClusterIP   None         <none>        80/TCP    46m
web-pdx             ClusterIP   None         <none>        80/TCP    179m
```

Test connectivity to the `local` headless service in `PDX`
```sh
kubectl --context pdx exec -it netshoot -- ping -c 1 web-pdx
```

```sh
PING web-pdx.default.svc.cluster.local (192.168.2.138) 56(84) bytes of data.
64 bytes from web-pdx-0.web-pdx.default.svc.cluster.local (192.168.2.138): icmp_seq=1 ttl=125 time=0.863 ms

--- web-pdx.default.svc.cluster.local ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.863/0.863/0.863/0.000 ms
```

Test connectivity to the `federated` headless service in `IAD`
```sh
kubectl --context pdx exec -it netshoot -- ping -c 1 web-iad-federated
```

```sh
PING web-iad-federated.default.svc.cluster.local (192.168.1.141) 56(84) bytes of data.
64 bytes from web-iad-0.web-iad-federated.default.svc.cluster.local (192.168.1.141): icmp_seq=1 ttl=125 time=58.7 ms

--- web-iad-federated.default.svc.cluster.local ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 58.659/58.659/58.659/0.000 ms
```

Test connectivity to the `local` headless service in `IAD`
```sh
kubectl --context iad get svc
```

```sh
NAME                TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
kubernetes          ClusterIP   172.20.0.1   <none>        443/TCP   20h
web-iad             ClusterIP   None         <none>        80/TCP    179m
web-pdx-federated   ClusterIP   None         <none>        80/TCP    30m
```

Test connectivity to the `federated` headless service in `IAD`
```sh
kubectl --context iad exec -it netshoot -- ping -c 1 web-pdx-federated
```

```sh
PING web-pdx-federated.default.svc.cluster.local (192.168.2.138) 56(84) bytes of data.
64 bytes from web-pdx-0.web-pdx-federated.default.svc.cluster.local (192.168.2.138): icmp_seq=1 ttl=125 time=65.1 ms

--- web-pdx-federated.default.svc.cluster.local ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 65.090/65.090/65.090/0.000 ms
```

```sh
kubectl --context iad exec -it netshoot -- ping -c 1 web-iad
```

```sh
PING web-iad.default.svc.cluster.local (192.168.1.141) 56(84) bytes of data.
64 bytes from web-iad-0.web-iad.default.svc.cluster.local (192.168.1.141): icmp_seq=1 ttl=125 time=0.569 ms

--- web-iad.default.svc.cluster.local ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.569/0.569/0.569/0.000 ms
```

#### 6. Cleanup

To teardown and remove the resources created in this example:

```sh
terraform state rm helm_release.calico_cluster1
terraform state rm helm_release.calico_cluster2
terraform destroy --auto-approve
```
