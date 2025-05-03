terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 4.0"  # Specify the desired version
    }
    helm = {
      source = "hashicorp/helm"
      version = "~> 2.10.0"  # Specify the desired version
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "~> 2.17.0"  # Specify the desired version
    }
  }
}

provider "aws" {
  region = "ap-south-1"  # Mumbai region
}
provider "kubernetes" {
  host                   = aws_eks_cluster.sre.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.sre.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.sre.token
}

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.sre.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.sre.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.sre.token
  }
}

