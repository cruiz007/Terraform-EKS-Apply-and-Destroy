# Terraform-EKS-Apply-and-Destroy
Setting Up an Amazon EKS Cluster with Terraform: A Step-by-Step Guide

This guide walks you through using Terraform to set up an Amazon Elastic Kubernetes Service (EKS) cluster. You’ll learn how to configure EKS with node groups, set up IAM roles, and troubleshoot common issues. The configuration uses Terraform’s terraform-aws-modules/eks/aws module to simplify the setup.

Prerequisites

Before starting, ensure you have the following installed:
	•	Terraform: Download the latest version from Terraform’s website.
	•	AWS CLI: Install and configure AWS CLI with your credentials. Refer to the AWS CLI documentation for setup.

Step 1: Write Your Terraform Configuration

Here’s a sample main.tf configuration to create an EKS cluster with managed node groups. This configuration will:
	•	Define an AWS provider.
	•	Create a VPC and subnets for the EKS cluster.
	•	Set up an EKS cluster using the Terraform EKS module.
	•	Add IAM permissions to allow the node group to interact with the EKS cluster.

# Specify the AWS provider
provider "aws" {
  region = "us-west-2"  # Adjust this as needed
}

# Create a VPC for the EKS cluster
resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create subnets for the EKS cluster
resource "aws_subnet" "eks_subnets" {
  count                   = 2  # Two subnets for high availability
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.eks_vpc.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
}

# Retrieve availability zones
data "aws_availability_zones" "available" {}

# EKS Cluster Module
module "eks_cluster" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 20.0"
  cluster_name    = "SoloTest"
  cluster_version = "1.31"
  subnet_ids      = aws_subnet.eks_subnets[*].id
  vpc_id          = aws_vpc.eks_vpc.id
  
  # Publicly accessible cluster endpoint
  cluster_endpoint_public_access  = true

  # Managed Node Group configuration
  eks_managed_node_groups = {
    solo_nodes = {
      desired_size   = 1
      max_size       = 1
      min_size       = 1
      instance_type  = "t3.medium"  # Adjust as needed
    }
  }

  # Grant admin permissions to the cluster creator
  enable_cluster_creator_admin_permissions = true
}

Step 2: Initialize and Apply the Configuration

Once you’ve saved your configuration to main.tf, follow these steps to deploy your EKS cluster.
	1.	Initialize Terraform: Run terraform init to download necessary provider and module files.

terraform init


	2.	Plan the Configuration: Use terraform plan to see what resources will be created. This helps verify that your configuration is correct.

terraform plan


	3.	Apply the Configuration: Run terraform apply to create the EKS cluster and associated resources. You’ll be prompted to confirm the action.

terraform apply



Step 3: Debugging Common Issues

Here are some common errors you might encounter during the setup and solutions to resolve them.

Duplicate Resource Error

If you see an error like:

Error: Duplicate resource "aws_vpc" configuration

This indicates that a VPC resource with the same name already exists in your project. You can fix this by:
	•	Removing duplicate files: Ensure only necessary .tf files are in your project directory. For example, if you have old backup files like main.bak4.tf, delete or move them.
	•	Renaming duplicate resources: If another file needs the existing VPC, you could reference it in main.tf rather than redefining it.

Stale Resource in State File

If Terraform tries to manage a resource that’s been modified or deleted outside of Terraform, you may see errors related to “stale state.” To fix this:
	1.	Remove the resource from the Terraform state:

terraform state rm <resource-name>


	2.	Re-run terraform apply to refresh the state and recreate resources if necessary.

IAM Role and Policy Issues

If you’re using IAM roles for the node group and see permission errors, ensure the necessary policies are attached:
	•	AmazonEKSWorkerNodePolicy
	•	AmazonEKSCNIPolicy
	•	AmazonEC2ContainerRegistryReadOnly

These policies allow nodes to interact with the EKS control plane and retrieve container images. Refer to the AWS IAM documentation for more details on policy configurations.

Cluster Access and Authentication

If you have issues accessing the cluster or configuring Kubernetes permissions, ensure that:
	•	enable_cluster_creator_admin_permissions is set to true in the EKS module configuration. This grants admin access to the creator.
	•	Verify that your AWS CLI is configured with the correct credentials to access the cluster.

Additional Resources

For further details on Terraform and EKS, refer to:
	•	HashiCorp’s Terraform EKS module documentation for module options and examples.
	•	AWS EKS User Guide for additional configuration and management instructions.
	•	AWS IAM Best Practices to ensure secure access control in your EKS cluster.

Following these steps should provide you with a fully functional EKS cluster managed via Terraform, as well as troubleshooting techniques for any common issues.