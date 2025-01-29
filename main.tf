
provider "aws" {
  region = var.region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.eks.token
}

data "aws_eks_cluster_auth" "eks" {
  name = module.eks.cluster_name
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

  map_public_ip_on_launch = false

  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}



module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets

  cluster_endpoint_public_access  = true  
  cluster_endpoint_private_access = false

  enable_irsa = true  

  eks_managed_node_groups = {
    workers = {
      desired_capacity = var.node_desired_capacity
      max_size         = var.node_max_size
      min_size         = var.node_min_size
      instance_types   = [var.node_instance_type]

      tags = {
        Name = "${var.cluster_name}-workers"
      }
    }
  }
}



resource "aws_iam_role" "eks_admin_role" {
  name = "EKSAdminRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "eks_admin_policy" {
  name        = "EKSAdminPolicy"
  description = "Admin policy for EKS access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:ListClusters",
          "eks:DescribeCluster",
          "eks:GetToken",
          "eks:AccessKubernetesApi"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_admin_role_attachment" {
  role       = aws_iam_role.eks_admin_role.name
  policy_arn = aws_iam_policy.eks_admin_policy.arn
}



resource "aws_iam_role" "eks_irsa_role" {
  name = "eks-irsa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${module.eks.oidc_provider}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${module.eks.oidc_provider}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "eks_irsa_policy_attachment" {
  name       = "eks-irsa-policy-attachment"
  roles      = [aws_iam_role.eks_irsa_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}



resource "kubernetes_cluster_role" "eks_admin_role" {
  metadata {
    name = "eks-admin-role"
  }

  rule {
    api_groups = [""]
    resources  = ["*"]
    verbs      = ["*"]
  }
}

resource "kubernetes_cluster_role_binding" "eks_admin_binding" {
  metadata {
    name = "eks-admin-role-binding"
  }

  subject {
    kind      = "User"
    name      = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/EKSAdminRole"
    api_group = "rbac.authorization.k8s.io"
  }

  role_ref {
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.eks_admin_role.metadata[0].name
    api_group = "rbac.authorization.k8s.io"
  }
}




resource "aws_eks_addon" "vpc_cni" {
  cluster_name = module.eks.cluster_name
  addon_name   = "vpc-cni"
  depends_on   = [module.eks]

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_eks_addon" "coredns" {
  cluster_name = module.eks.cluster_name
  addon_name   = "coredns"
  depends_on   = [module.eks]

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = module.eks.cluster_name
  addon_name   = "kube-proxy"
  depends_on   = [module.eks]

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}


data "aws_caller_identity" "current" {}



output "eks_admin_role_arn" {
  value = aws_iam_role.eks_admin_role.arn
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_oidc_provider" {
  value = module.eks.oidc_provider
}
