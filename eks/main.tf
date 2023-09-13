terraform {

  cloud {
    organization = "Nazhan_Telur"

    workspaces {
      name = "airflow-eks-cluster"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.28.0"
    }
  }

  required_version = ">= 1.1.0"
}

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.region
}


data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "controlplane" {
  name               = "eks-cluster"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "controlplane_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.controlplane.name
}

resource "aws_default_subnet" "subnet1" {
  availability_zone = "ap-southeast-1a"
}

resource "aws_default_subnet" "subnet2" {
  availability_zone = "ap-southeast-1b"
}

resource "aws_default_subnet" "subnet3" {
  availability_zone = "ap-southeast-1c"
}


resource "aws_eks_cluster" "airflow-eks-cluster" {
  name     = "airflow-eks-cluster"
  role_arn = aws_iam_role.controlplane.arn

  vpc_config {
    subnet_ids = [aws_default_subnet.subnet1.id, aws_default_subnet.subnet2.id, aws_default_subnet.subnet3.id]
  }
}


resource "aws_iam_role" "nodegroup" {
  name = "eks-nodegroup"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "nodegroup_attachment-worker" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.nodegroup.name
}

resource "aws_iam_role_policy_attachment" "nodegroup_attachment-cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.nodegroup.name
}

resource "aws_iam_role_policy_attachment" "nodegroup_attachment-ecr" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.nodegroup.name
}

resource "aws_eks_node_group" "node1" {
  cluster_name    = aws_eks_cluster.test.name
  node_group_name = "node1"
  node_role_arn   = aws_iam_role.nodegroup.arn
  subnet_ids      = [aws_default_subnet.subnet1.id, aws_default_subnet.subnet2.id, aws_default_subnet.subnet3.id]

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  capacity_type = "SPOT"

}

resource "aws_acm_certificate" "cert" {
  domain_name       = "gpu.peacehotel.my"
  subject_alternative_names = ["*.gpu.peacehotel.my"]
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# https://github.com/bootlabstech/terraform-aws-fully-loaded-eks-cluster/tree/v1.0.7/modules/kubernetes-addons/airflow