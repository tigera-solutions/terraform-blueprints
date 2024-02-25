# Outputs for EKS Cluster 1

output "configure_kubectl_cluster1" {
  description = "Command to configure kubectl for Cluster 1"
  value       = "aws eks --region ${var.region1} update-kubeconfig --name ${module.eks_cluster1.cluster_name} --alias ${module.eks_cluster1.cluster_name}"
}

output "cluster1_name" {
  description = "Kubernetes Cluster 1 Name"
  value       = module.eks_cluster1.cluster_name
}

output "cluster1_endpoint" {
  description = "Endpoint for EKS Cluster 1 control plane"
  value       = module.eks_cluster1.cluster_endpoint
}

output "cluster1_version" {
  description = "The Kubernetes version for Cluster 1"
  value       = module.eks_cluster1.cluster_version
}

output "cluster1_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with Cluster 1"
  value       = module.eks_cluster1.cluster_certificate_authority_data
}

output "oidc_provider_arn_cluster1" {
  description = "The ARN of the OIDC Provider for Cluster 1 if `enable_irsa = true`"
  value       = module.eks_cluster1.oidc_provider_arn
}

# Outputs for EKS Cluster 2

output "configure_kubectl_cluster2" {
  description = "Command to configure kubectl for Cluster 2"
  value       = "aws eks --region ${var.region2} update-kubeconfig --name ${module.eks_cluster2.cluster_name} --alias ${module.eks_cluster2.cluster_name}"
}

output "cluster2_name" {
  description = "Kubernetes Cluster 2 Name"
  value       = module.eks_cluster2.cluster_name
}

output "cluster2_endpoint" {
  description = "Endpoint for EKS Cluster 2 control plane"
  value       = module.eks_cluster2.cluster_endpoint
}

output "cluster2_version" {
  description = "The Kubernetes version for Cluster 2"
  value       = module.eks_cluster2.cluster_version
}

output "cluster2_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with Cluster 2"
  value       = module.eks_cluster2.cluster_certificate_authority_data
}

output "oidc_provider_arn_cluster2" {
  description = "The ARN of the OIDC Provider for Cluster 2 if `enable_irsa = true`"
  value       = module.eks_cluster2.oidc_provider_arn
}

