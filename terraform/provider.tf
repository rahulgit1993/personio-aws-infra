provider "aws" {
  region = var.region
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
