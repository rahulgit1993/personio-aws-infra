output "grafana_url" {
  value = "http://${aws_instance.eks_worker_node[0].public_ip}:32000"
  description = "URL to access Grafana dashboard"
}
