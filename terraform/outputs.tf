output "app_port_forward_command" {
  value       = "kubectl port-forward -n application svc/personio-app 8080:80"
  description = "Use this command to access your app at http://localhost:8080"
}
