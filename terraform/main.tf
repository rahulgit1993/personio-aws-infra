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

resource "helm_release" "prometheus" {
  name       = "prometheus"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  version    = "15.1.0"

  values = [<<EOF
server:
  resources:
    requests:
      memory: "100Mi"
      cpu: "100m"
    limits:
      memory: "200Mi"
      cpu: "200m"

alertmanager:
  resources:
    requests:
      memory: "50Mi"
      cpu: "50m"
    limits:
      memory: "100Mi"
      cpu: "100m"

pushgateway:
  resources:
    requests:
      memory: "20Mi"
      cpu: "20m"
    limits:
      memory: "50Mi"
      cpu: "50m"

kubeStateMetrics:
  resources:
    requests:
      memory: "30Mi"
      cpu: "30m"
    limits:
      memory: "60Mi"
      cpu: "60m"

nodeExporter:
  resources:
    requests:
      memory: "20Mi"
      cpu: "20m"
    limits:
      memory: "40Mi"
      cpu: "40m"

service:
  type: NodePort
  nodePort: 32001
  replicaCount: 1
EOF
  ]

  depends_on = [aws_eks_node_group.personio_nodes]
}


resource "helm_release" "grafana" {
  name       = "grafana"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  version    = "6.16.2"

  values = [<<EOF
adminPassword: "${var.grafana_admin_password}"

resources:
  requests:
    memory: "100Mi"
    cpu: "100m"
  limits:
    memory: "200Mi"
    cpu: "200m"

service:
  type: NodePort
  nodePort: 32000
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

  scaling_config {
    desired_size = 3
    max_size     = 3
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

resource "helm_release" "kube_state_metrics" {
  name       = "kube-state-metrics"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  repository = "https://kubernetes.github.io/kube-state-metrics"
  chart      = "kube-state-metrics"
  version    = "2.0.0"

  values = [<<EOF
replicaCount: 1
resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 100m
    memory: 128Mi

service:
  type: ClusterIP
EOF
  ]

  depends_on = [aws_eks_node_group.personio_nodes]
}

