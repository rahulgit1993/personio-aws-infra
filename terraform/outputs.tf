output "grafana_port_forward_command" {
  value       = "kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80"
  description = "Use this command to access Grafana at http://localhost:3000"
}
