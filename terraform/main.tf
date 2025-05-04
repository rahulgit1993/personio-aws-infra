resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_attach" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

## EKS Cluster creation
resource "aws_eks_cluster" "personio" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids          = aws_subnet.public[*].id
    security_group_ids  = [aws_security_group.eks_cluster_sg.id]
  }
}
data "aws_eks_cluster" "personio" {
  name = aws_eks_cluster.personio.name
}

data "aws_eks_cluster_auth" "personio" {
  name = aws_eks_cluster.personio.name
}

resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_attach" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "cni_attach" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}



# Port Forwarding Setup and AWS Auth Update
resource "null_resource" "update_aws_auth" {
  depends_on = [
    aws_eks_node_group.personio_nodes
  ]

  triggers = {
    docker_username       = var.DOCKER_USERNAME
    image_tag             = var.IMAGE_TAG
    deployment_checksum   = filesha256("${path.module}/../k8s/deployment.yaml")
    service_checksum      = filesha256("${path.module}/../k8s/service.yaml")
  }

  provisioner "local-exec" {
    command = <<EOT
      aws eks update-kubeconfig --region ${var.region} --name ${var.cluster_name}

      export DOCKER_USERNAME="${var.DOCKER_USERNAME}"
      export IMAGE_TAG="${var.IMAGE_TAG}"

      cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${aws_iam_role.eks_node_role.arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
EOF

      envsubst < ../k8s/deployment.yaml | kubectl apply -f -
      kubectl apply -f ../k8s/service.yaml
      echo "✅ Deployment and service applied successfully."
      echo "👉 You can run this locally to access the app:"
      echo "   kubectl port-forward -n application svc/personio-app 8080:80"
EOT
  }
}
#

resource "aws_eks_node_group" "personio_nodes" {
  cluster_name    = aws_eks_cluster.personio.name
  node_group_name = "personio-nodes"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = aws_subnet.public[*].id

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 1
  }

  instance_types = ["t3.micro"]

  tags = {
    Name = "personio-nodes"
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_attach,
    aws_iam_role_policy_attachment.cni_attach,
    aws_iam_role_policy_attachment.ecr_readonly
  ]
}




resource "kubernetes_namespace" "application" {
  metadata {
    name = "application"
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}
