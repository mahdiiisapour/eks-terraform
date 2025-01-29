variable "region" {
  default     = "eu-central-1"
}

variable "availability_zones" {
  default     = ["eu-central-1a", "eu-central-1b"] 
}


variable "vpc_cidr" {
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "cluster_name" {
  default     = "my-eks-cluster"
}

variable "cluster_version" {
  default     = "1.31"
}

variable "node_desired_capacity" {
  description = "Desired number of worker nodes"
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  default     = 1
}

variable "node_instance_type" {
  default     = "t3.micro"
}

variable "environment" {
  type        = string
  default     = "poc"
}


