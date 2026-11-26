terraform {
  required_version = ">= 1.5"
  required_providers { aws = { source = "hashicorp/aws", version = "~> 5.0" } random = { source = "hashicorp/random" } }
}
provider "aws" { region = var.region }

data "aws_availability_zones" "available" { state = "available" }

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  name    = "${var.name}-vpc"
  cidr    = "10.0.0.0/16"
  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  database_subnets = ["10.0.201.0/24", "10.0.202.0/24", "10.0.203.0/24"]
  enable_nat_gateway = true
  single_nat_gateway = true
  public_subnet_tags  = { "kubernetes.io/role/elb" = 1 }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = 1 }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"
  cluster_name    = var.name
  cluster_version = "1.30"
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  cluster_endpoint_public_access = true
  enable_cluster_creator_admin_permissions = true
  eks_managed_node_groups = {
    on_demand = { instance_types = ["t3.medium"], min_size = 2, max_size = 4, desired_size = 2 }
    spot = {
      capacity_type  = "SPOT"
      instance_types = ["t3.medium", "t3a.medium"]
      min_size = 0, max_size = 4, desired_size = 1
      labels = { workload = "spot" }
    }
  }
}

resource "aws_ecr_repository" "svc" {
  for_each             = toset(["users", "orders"])
  name                 = "${var.name}/${each.key}"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }
}

resource "random_password" "db" { length = 24 special = false }

resource "aws_security_group" "rds" {
  name   = "${var.name}-rds"
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }
}

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"
  identifier = "${var.name}-pg"
  engine = "postgres"
  engine_version = "16"
  family = "postgres16"
  major_engine_version = "16"
  instance_class = "db.t4g.micro"
  allocated_storage = 20
  db_name  = "appdb"
  username = "appuser"
  password = random_password.db.result
  manage_master_user_password = false
  create_db_subnet_group = true
  subnet_ids = module.vpc.database_subnets
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot = true
  deletion_protection = false
}

resource "aws_secretsmanager_secret" "db" { name = "${var.name}/db" }
resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    DATABASE_URL = "postgresql://appuser:${random_password.db.result}@${module.rds.db_instance_address}:5432/appdb"
  })
}
