data "aws_availability_zones" "available" {}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "sre-vpc"
  }
}

resource "aws_subnet" "public" {
  count                   = 2
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  vpc_id                  = aws_vpc.main.id
  map_public_ip_on_launch = true
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name                                    = "sre-public-subnet-${count.index}"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "sre-igw"
  }
}

# Create a Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "sre-public-rt"
  }
}

# Associate the route table with each public subnet
resource "aws_route_table_association" "a" {
  for_each = { for idx, subnet in aws_subnet.public : idx => subnet.id }

  subnet_id      = each.value
  route_table_id = aws_route_table.public_rt.id
}


# Security Group for EKS Node Group, Prometheus, Grafana, and App Access
resource "aws_security_group" "eks_node_sg" {
  name_prefix = "eks-node-sg"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow HTTP traffic for app"
    from_port   = 30001
    to_port     = 30001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow Prometheus traffic"
    from_port   = 32001
    to_port     = 32001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow Grafana traffic"
    from_port   = 32000
    to_port     = 32000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SSH for diagnostics (optional)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS for future use (optional)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "eks-node-sg"
  }
}

# Security Group for EKS Cluster (Control Plane Access)
resource "aws_security_group" "eks_cluster_sg" {
  name_prefix = "eks-cluster-sg"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow traffic from EKS nodes to EKS control plane"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = aws_subnet.public[*].cidr_block
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "eks-cluster-sg"
  }
}