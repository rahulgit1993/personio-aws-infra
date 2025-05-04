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

# Lightweight Prometheus setup via Helm
resource "helm_release" "prometheus" {
  name       = "prometheus"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  version    = "15.1.0"

  values = [<<EOF
service:
  type: NodePort
  nodePort: 32001  # Expose Prometheus on port 32001
  replicaCount: 1
EOF
  ]

  depends_on = [aws_eks_node_group.personio_nodes]
}

# Lightweight Grafana setup via Helm
resource "helm_release" "grafana" {
  name       = "grafana"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  version    = "6.16.2"

  values = [<<EOF
adminPassword: "${var.grafana_admin_password}"
service:
  type: NodePort
  nodePort: 32000  # Expose Grafana on port 32000
  replicaCount: 1
EOF
  ]

  depends_on = [aws_eks_node_group.personio_nodes]
}

# Port Forwarding Setup and AWS Auth Update
resource "null_resource" "update_aws_auth" {
  depends_on = [
    aws_eks_node_group.personio_nodes,
    helm_release.prometheus,
    helm_release.grafana
  ]

  triggers = {
    aws_auth_role_arn  = aws_iam_role.eks_node_role.arn
    deployment_checksum = filesha256("${path.module}/../k8s/deployment.yaml")
    service_checksum = filesha256("${path.module}/../k8s/service.yaml")
  }

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

# Applying application manifests
kubectl apply -f ../k8s/deployment.yaml
kubectl apply -f ../k8s/service.yaml
sleep 20
# Port forward to local machine for Grafana and Prometheus
kubectl port-forward -n monitoring svc/prometheus-server 32001:80 &
kubectl port-forward -n monitoring svc/grafana 32000:80 &
kubectl port-forward -n application svc/personio-app 30001:80 &
EOT
  }
}


resource "aws_eks_node_group" "personio_nodes" {
  cluster_name    = aws_eks_cluster.personio.name
  node_group_name = "personio-nodes"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = aws_subnet.public[*].id
  instance_types  = [var.node_instance_type]

  scaling_config {
    desired_size = 3
    max_size     = 3
    min_size     = 3
  }

  launch_template {
    id      = aws_launch_template.eks_node_template.id
    version = "$Latest"
  }
}

resource "aws_launch_template" "eks_node_template" {
  name = "eks-node-launch-template"

  security_group_names = [aws_security_group.eks_node_sg.name]

  ## Here you can also add other configurations like instance types, AMIs, etc.
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

resource "helm_release" "kube_state_metrics" {
  name       = "kube-state-metrics"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  repository = "https://kubernetes.github.io/kube-state-metrics"
  chart      = "kube-state-metrics"
  version    = "2.0.0"

  values = [<<EOF
service:
  type: ClusterIP  # Expose internally only
  replicaCount: 1    # Single replica by default
EOF
  ]

  depends_on = [aws_eks_node_group.personio_nodes]
}
