variable "region" {
  default = "ap-south-1"
}

variable "cluster_name" {
  default = "personio-cluster"
}

variable "node_instance_type" {
  default = "t3.micro"
}

variable "DOCKER_USERNAME" {
  description = "Docker Username"
  type        = string
}
variable "IMAGE_TAG" {
  description = "Image tag used for container"
  type        = string
}