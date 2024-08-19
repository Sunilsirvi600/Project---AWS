Creating an EKS cluster in a production environment with a new VPC and setting up a Terraform workspace involves several steps. Below is a detailed guide on how to set this up, including the `variables.tf`, `output.tf`, `main.tf`, `module.tf`, and `backend.tf` files, as well as enabling CloudWatch logging.

### 1. **Directory Structure**

Here's a suggested directory structure for your Terraform project:

```plaintext
terraform-eks/
├── environments/
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── backend.tf
│       └── terraform.tfvars
├── modules/
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── eks/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── terraform.tf
```

### 2. **Create Terraform Workspace**

First, create a new workspace for the production environment:

```bash
terraform workspace new prod
```

### 3. **VPC Module (`modules/vpc`)**

In `modules/vpc/main.tf`:

```hcl
provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = var.tags
}

resource "aws_subnet" "public" {
  count = 3

  vpc_id     = aws_vpc.this.id
  cidr_block = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true
  tags = var.tags
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = var.tags
}

output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}
```

In `modules/vpc/variables.tf`:

```hcl
variable "aws_region" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "tags" {
  type = map(string)
}
```

In `modules/vpc/outputs.tf`:

```hcl
output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}
```

### 4. **EKS Module (`modules/eks`)**

In `modules/eks/main.tf`:

```hcl
provider "aws" {
  region = var.aws_region
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  subnets         = var.subnet_ids
  vpc_id          = var.vpc_id
  enable_irsa     = true

  node_groups = {
    eks_nodes = {
      desired_capacity = 3
      max_capacity     = 5
      min_capacity     = 1
      instance_type    = "t3.medium"
    }
  }

  cloudwatch_log_group_name = var.cloudwatch_log_group_name
  cloudwatch_log_retention  = var.cloudwatch_log_retention

  tags = var.tags
}

output "eks_cluster_id" {
  value = module.eks.cluster_id
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_cluster_security_group_id" {
  value = module.eks.cluster_security_group_id
}
```

In `modules/eks/variables.tf`:

```hcl
variable "aws_region" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "cluster_version" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "cloudwatch_log_group_name" {
  type = string
}

variable "cloudwatch_log_retention" {
  type = number
}

variable "tags" {
  type = map(string)
}
```

In `modules/eks/outputs.tf`:

```hcl
output "eks_cluster_id" {
  value = module.eks.cluster_id
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_cluster_security_group_id" {
  value = module.eks.cluster_security_group_id
}
```

### 5. **Production Environment Configuration (`environments/prod`)**

In `environments/prod/main.tf`:

```hcl
provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source      = "../../modules/vpc"
  vpc_cidr    = "10.0.0.0/16"
  aws_region  = var.aws_region
  tags = {
    Name = "prod-vpc"
    Environment = "prod"
  }
}

module "eks" {
  source       = "../../modules/eks"
  aws_region   = var.aws_region
  cluster_name = "prod-eks-cluster"
  cluster_version = "1.21"
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.public_subnet_ids
  cloudwatch_log_group_name = "/aws/eks/prod-eks-cluster"
  cloudwatch_log_retention  = 7

  tags = {
    Name = "prod-eks-cluster"
    Environment = "prod"
  }
}
```

In `environments/prod/variables.tf`:

```hcl
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}
```

In `environments/prod/outputs.tf`:

```hcl
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "eks_cluster_id" {
  value = module.eks.eks_cluster_id
}

output "eks_cluster_endpoint" {
  value = module.eks.eks_cluster_endpoint
}
```

In `environments/prod/backend.tf` (optional, for remote state storage):

```hcl
terraform {
  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "prod/terraform.tfstate"
    region = "us-west-2"
    dynamodb_table = "your-lock-table"
  }
}
```

In `environments/prod/terraform.tfvars`:

```hcl
aws_region = "us-west-2"
```

### 6. **Initialize and Apply**

Navigate to the `environments/prod` directory:

```bash
cd environments/prod
```

Initialize Terraform:

```bash
terraform init
```

Review the execution plan:

```bash
terraform plan
```

Apply the configuration:

```bash
terraform apply
```

### 7. **CloudWatch Integration**

The EKS module setup includes CloudWatch integration by specifying `cloudwatch_log_group_name` and `cloudwatch_log_retention`. This ensures that EKS logs (like API server logs, audit logs, etc.) are sent to CloudWatch, where they can be monitored and retained according to your configuration.

### Summary

This guide walks through setting up a new EKS cluster in a production environment using Terraform. It includes creating separate modules for VPC and EKS, enabling CloudWatch logging, and organizing the infrastructure into a dedicated workspace and directory structure. By following these steps, you can manage your production environment more effectively while maintaining best practices for infrastructure as code.
