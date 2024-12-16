provider "aws" {
  region = "ap-south-1"
}

resource "aws_vpc" "default_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "default-vpc"
  }
}

resource "aws_subnet" "default_subnet" {
  count = 2
  vpc_id                  = aws_vpc.default_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.default_vpc.cidr_block, 8, count.index)
  availability_zone       = element(["ap-south-1a", "ap-south-1b"], count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "default-subnet-${count.index}"
  }
}

resource "aws_internet_gateway" "default_igw" {
  vpc_id = aws_vpc.default_vpc.id

  tags = {
    Name = "default-igw"
  }
}

resource "aws_route_table" "default_route_table" {
  vpc_id = aws_vpc.default_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.default_igw.id
  }

  tags = {
    Name = "default-route-table"
  }
}

resource "aws_route_table_association" "a" {
  count          = 2
  subnet_id      = aws_subnet.default_subnet[count.index].id
  route_table_id = aws_route_table.default_route_table.id
}

resource "aws_security_group" "default_cluster_sg" {
  vpc_id = aws_vpc.default_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "default-cluster-sg"
  }
}

resource "aws_security_group" "default_node_sg" {
  vpc_id = aws_vpc.default_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "default-node-sg"
  }
}

resource "aws_eks_cluster" "default" {
  name     = "default-cluster"
  role_arn = aws_iam_role.default_cluster_role.arn

  vpc_config {
    subnet_ids         = aws_subnet.default_subnet[*].id
    security_group_ids = [aws_security_group.default_cluster_sg.id]
  }
}

resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.default.name
  node_group_name = "default-node-group"
  node_role_arn   = aws_iam_role.default_node_group_role.arn
  subnet_ids      = aws_subnet.default_subnet[*].id

  scaling_config {
    desired_size = 3
    max_size     = 3
    min_size     = 3
  }

  instance_types = ["t2.medium"]

  remote_access {
    ec2_ssh_key = var.ssh_key_name
    source_security_group_ids = [aws_security_group.default_node_sg.id]
  }
}

resource "aws_iam_role" "default_cluster_role" {
  name = "default-cluster-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "default_cluster_role_policy" {
  role       = aws_iam_role.default_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "default_node_group_role" {
  name = "default-node-group-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "default_node_group_role_policy" {
  role       = aws_iam_role.default_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "default_node_group_cni_policy" {
  role       = aws_iam_role.Primary_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "default_node_group_registry_policy" {
  role       = aws_iam_role.default_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
