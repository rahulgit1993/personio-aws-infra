#output "grafana_port_forward_command" {
#  value       = "kubectl port-forward -n monitoring svc/monitoring-grafana 32000:80"
##  description = "Use this command to access Grafana at http://localhost:32000"
#}

#output "prometheus_port_forward_command" {
#  value       = "kubectl port-forward -n monitoring svc/monitoring-prometheus 32001:9090"
#  description = "Use this command to access Prometheus at http://localhost:32001"
#}

output "app_port_forward_command" {
  value       = "kubectl port-forward -n application svc/personio-app 30001:80"
  description = "Use this command to access your app at http://localhost:30001"
}
