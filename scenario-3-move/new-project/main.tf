# Scenario 3: New Project (Destination)
# ======================================
# Database resources will be moved here from old-project.

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# AWS Provider - LocalStack
provider "aws" {
  region = "us-east-1"

  access_key = "test"
  secret_key = "test"

  endpoints {
    ec2 = "http://localhost:4566"
    rds = "http://localhost:4566"
    sts = "http://localhost:4566"
  }

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

# Data source for AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# ============================================
# DATABASE RESOURCES (TODO: Add after moving from old-project)
# ============================================
#
# After moving state, add these resource blocks:
#
# resource "aws_security_group" "db" {
#   name        = "db-sg"
#   description = "Security group for database"
#
#   ingress {
#     from_port       = 3306
#     to_port         = 3306
#     protocol        = "tcp"
#     security_groups = ["<web-sg-id>"]  # Reference the web SG from old-project
#   }
#
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#
#   tags = {
#     Name = "db-sg"
#   }
# }
#
# resource "aws_instance" "db" {
#   ami           = data.aws_ami.amazon_linux.id
#   instance_type = "t2.small"
#
#   vpc_security_group_ids = [aws_security_group.db.id]
#
#   tags = {
#     Name = "db-server"
#     Type = "database"
#   }
# }

# ============================================
# OUTPUTS
# ============================================

# TODO: Uncomment after moving resources
# output "db_instance_id" {
#   value = aws_instance.db.id
# }
#
# output "db_sg_id" {
#   value = aws_security_group.db.id
# }
