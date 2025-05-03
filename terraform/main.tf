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

resource "aws_eks_cluster" "sre" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = aws_subnet.public[*].id
  }
}

data "aws_eks_cluster" "sre" {
  name = aws_eks_cluster.sre.name
}

data "aws_eks_cluster_auth" "sre" {
  name = aws_eks_cluster.sre.name
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

resource "null_resource" "update_aws_auth" {
  depends_on = [aws_eks_node_group.sre_nodes]

  provisioner "local-exec" {
    command = <<EOT
      aws eks update-kubeconfig --region ${var.region} --name ${var.cluster_name}
      kubectl get configmap aws-auth -n kube-system || true

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
#Applying our app manifests
kubectl apply -f ./k8s/deployment.yaml
kubectl apply -f ./k8s/service.yaml
 
# Port forward to local machine for Grafana and Prometheus
kubectl port-forward -n monitoring svc/monitoring-grafana 32000:80 &
kubectl port-forward -n monitoring svc/monitoring-prometheus 32001:9090 &
kubectl port-forward -n application svc/sre-app 30001:80 &
EOT
  }
}

resource "aws_eks_node_group" "sre_nodes" {
  cluster_name    = aws_eks_cluster.sre.name
  node_group_name = "sre-nodes"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = aws_subnet.public[*].id
  instance_types  = [var.node_instance_type]

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 2
  }
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

resource "helm_release" "prom_stack" {
  name             = "monitoring"
  namespace        = kubernetes_namespace.monitoring.metadata[0].name
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "47.3.0"
  create_namespace = false
  timeout          = 600

  depends_on  = [aws_eks_node_group.sre_nodes]

  values = [<<EOF
grafana:
  adminPassword: "${var.grafana_admin_password}"
  service:
    type: NodePort
    nodePort: 32000
prometheus:
  service:
    type: NodePort
    nodePort: 32001
EOF
  ]
}
