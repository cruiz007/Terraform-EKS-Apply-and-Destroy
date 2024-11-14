# Specify the Terraform provider for AWS
provider "aws" {
  region = "us-west-2"  # Change the region as needed
}

# Create a VPC for the EKS cluster
resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create subnets for the EKS cluster
resource "aws_subnet" "eks_subnets" {
  count                   = 2  # Two subnets are recommended for high availability
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.eks_vpc.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
}

# Retrieve the list of availability zones
data "aws_availability_zones" "available" {}

# IAM Role for the EKS Node Group
resource "aws_iam_role" "node_group_role" {
  name = "eks-node-group-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach necessary policies to the node group role
resource "aws_iam_role_policy_attachment" "node_group_policy_eks_worker" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group_role.name
}

resource "aws_iam_role_policy_attachment" "node_group_policy_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSCNIPolicy"
  role       = aws_iam_role.node_group_role.name
}

resource "aws_iam_role_policy_attachment" "node_group_policy_ec2_container" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group_role.name
}

# EKS Cluster Module
module "eks_cluster" {
  source          = "terraform-aws-modules/eks/aws"
  version 		  = "~> 20.0"
  cluster_name    = "SoloTest"
  cluster_version = "1.31"  # Adjust for the latest EKS version
  subnet_ids      = aws_subnet.eks_subnets[*].id
  vpc_id          = aws_vpc.eks_vpc.id
  
  cluster_endpoint_public_access  = true

  # Specify node group details with the IAM role applied
  eks_managed_node_groups = {
    solo_nodes = {
      desired_size   = 1
      max_size       = 1
      min_size       = 1
      instance_type  = "t3.medium"  # Adjust instance type as needed
      iam_role_arn   = aws_iam_role.node_group_role.arn  # Reference to the IAM role created above
    }
  }

  # Cluster access entry
  # To add the current caller identity as an administrator
  enable_cluster_creator_admin_permissions = true
  
  access_entries = {
    # Optional: Add additional IAM roles or users with specific access levels
    example = {
      kubernetes_groups = []
      principal_arn     = "arn:aws:iam::123456789012:role/something"

      policy_associations = {
        example = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
          access_scope = {
            namespaces = ["default"]
            type       = "namespace"
          }
        }
      }
    }
  }
}
