variable "region" {
  default = "ap-south-1"
}

variable "cluster_name" {
  default = "sre-cluster"
}

variable "node_instance_type" {
  default = "t3.micro"
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
}
