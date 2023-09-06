output "tigera_manager_lb_url" {
  value = "https://${kubernetes_service.tigera-manager-lb.status[0].load_balancer[0].ingress[0].hostname}"
}

output "get_tigera_admin_team_token" {
  value    = "kubectl get secret tigera-admin-team -o go-template='{{.data.token | base64decode}}'" 
}

output "get_kibana_elastic_token" {
  value    = "kubectl get -n tigera-elasticsearch secret tigera-secure-es-elastic-user -o go-template='{{.data.elastic | base64decode}}'"
}
