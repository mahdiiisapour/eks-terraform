provider "aws" {
  region = var.region
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.17.0"
  name               = "${var.cluster_name}-vpc"
  cidr               = var.vpc_cidr
  azs                = var.availability_zones
  public_subnets     = var.public_subnet_cidrs
  private_subnets    = var.private_subnet_cidrs
  enable_nat_gateway = true
  single_nat_gateway = true

  map_public_ip_on_launch = true


  public_subnet_tags = {
    "kubernetes.io/role/elb"                = "1"                         
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"                
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"       = "1"                         
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"               
  }
}




module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.33.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.public_subnets

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = false

  eks_managed_node_groups = {
    workers = {
      desired_capacity = var.node_desired_capacity
      max_size         = var.node_max_size
      min_size         = var.node_min_size
      instance_type    = var.node_instance_type

      tags = {
        "Name" = "${var.cluster_name}-workers"
      }


      iam_role_name = module.iam.eks_node_group_role_name
    }
  }
}





# Add-ons
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "vpc-cni"
  depends_on = [module.eks]
  # resolve_conflicts_on_create = "OVERWRITE"
  # resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_eks_addon" "coredns" {
  cluster_name = module.eks.cluster_name
  addon_name   = "coredns"

  depends_on = [module.eks]

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}



resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "kube-proxy"
  depends_on = [module.eks]
  # resolve_conflicts_on_create = "OVERWRITE"
  # resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# resource "aws_eks_addon" "aws_lb_controller" {
#   cluster_name                = module.eks.cluster_name
#   addon_name                  = "aws-load-balancer-controller"
  # depends_on = [module.eks]
#   # resolve_conflicts_on_create = "OVERWRITE"
#   # resolve_conflicts_on_update = "OVERWRITE"

#   tags = {
#     Environment = var.environment
#     ManagedBy   = "Terraform"
#   }
# }

# Data Source for Availability Zones
# data "aws_availability_zones" "available" {}
