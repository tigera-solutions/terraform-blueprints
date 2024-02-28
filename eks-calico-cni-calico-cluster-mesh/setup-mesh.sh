#!/bin/bash

# Define Calico and Kubernetes configurations
CALICO_VERSION="v3.27.0"
CALICO_EE_VERSION="v3.18.0-2.0"
NAMESPACE="kube-system"
SECRET_NAMESPACE="calico-system"
SA_NAME="tigera-federation-remote-cluster"

# Function to configure mesh for a pair of clusters
create_mesh_pair() {
    local source_cluster="$1"
    local destination_cluster="$2"

    echo "Setting up mesh between $source_cluster and $destination_cluster..."

    # Set the context to the source cluster
    kubectl config use-context "$source_cluster"

    # Apply Calico resources for federation
    kubectl apply -f "https://downloads.tigera.io/ee/$CALICO_EE_VERSION/manifests/federation-remote-sa.yaml"
    kubectl apply -f "https://downloads.tigera.io/ee/$CALICO_EE_VERSION/manifests/federation-rem-rbac-kdd.yaml"

    # Retrieve the ServiceAccount token
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
type: kubernetes.io/service-account-token
metadata:
  name: tigera-federation-remote-cluster
  namespace: kube-system
  annotations:
    kubernetes.io/service-account.name: "tigera-federation-remote-cluster"
EOF

    # Get necessary information for kubeconfig
    local sa_token=$(kubectl get secret $SA_NAME -n $NAMESPACE -o jsonpath='{.data.token}' | base64 --decode)
    local cluster_server=$(kubectl config view -o json | jq -r --arg name "$source_cluster" '.clusters[] | select(.name | endswith("/" + $name)) | .cluster.server')
    local cluster_ca=$(kubectl config view --flatten -o json | jq -r --arg name "$source_cluster" '.clusters[] | select(.name | endswith("/" + $name)) | .cluster."certificate-authority-data"')

    # Create kubeconfig for the source cluster
    local kubeconfig=$(mktemp)
    cat > $kubeconfig <<EOF
apiVersion: v1
kind: Config
users:
- name: $SA_NAME
  user:
    token: $sa_token
clusters:
- name: $source_cluster
  cluster:
    certificate-authority-data: $cluster_ca
    server: $cluster_server
contexts:
- name: $source_cluster-ctx
  context:
    cluster: $source_cluster
    user: $SA_NAME
current-context: $source_cluster-ctx
EOF

    # Set the context to the destination cluster
    kubectl config use-context "$destination_cluster"

    # Create secret in the destination cluster
    kubectl delete secret $destination_cluster-secret -n $SECRET_NAMESPACE --ignore-not-found=true
    kubectl create secret generic $destination_cluster-secret -n $SECRET_NAMESPACE --from-literal=datastoreType=kubernetes --from-file=kubeconfig=$kubeconfig

    # Apply RemoteClusterConfiguration
    cat <<EOF | kubectl apply -f -
apiVersion: projectcalico.org/v3
kind: RemoteClusterConfiguration
metadata:
  name: $destination_cluster
spec:
  clusterAccessSecret:
    name: $destination_cluster-secret
    namespace: $SECRET_NAMESPACE
  syncOptions:
    overlayRoutingMode: Enabled
EOF

    # Apply RBAC resources for accessing secret if they haven't already been applied to this cluster
    local rbac_applied=$(kubectl get rolebindings.rbac.authorization.k8s.io -n $SECRET_NAMESPACE | grep remote-cluster-secret-access | wc -l)
    if [ "$rbac_applied" -eq 0 ]; then
        kubectl apply -f - <<EOFRBAC
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: remote-cluster-secret-access
  namespace: $SECRET_NAMESPACE
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["watch", "list", "get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: remote-cluster-secret-access
  namespace: $SECRET_NAMESPACE
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: remote-cluster-secret-access
subjects:
- kind: ServiceAccount
  name: calico-typha
  namespace: calico-system
EOFRBAC
    fi

    # Cleanup
    rm $kubeconfig

    echo "Mesh setup from $source_cluster to $destination_cluster completed"
}

# Define static list of cluster names
clusters=("iad" "pdx")

# Iterate over each unique pair of clusters to set up the mesh
for src_cluster in "${clusters[@]}"; do
    for dst_cluster in "${clusters[@]}"; do
        if [ "$src_cluster" != "$dst_cluster" ]; then
            create_mesh_pair "$src_cluster" "$dst_cluster"
        fi
    done
done

