# Scenario 3: New Project (Destination)
# ======================================
# Database resources will be moved here from old-project.

# =====================================================
# CHOOSE YOUR MODE: LocalStack or Real AWS
# =====================================================
#
# LOCALSTACK (Default):
#   - Uses: provider-localstack.tf
#
# REAL AWS:
#   - Switch provider in BOTH projects:
#       mv provider-localstack.tf provider-localstack.tf.bak
#       mv provider-aws.tf.example provider-aws.tf
#
# =====================================================

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# =====================================================
# Provider configuration is in separate files:
#   - provider-localstack.tf  (for LocalStack)
#   - provider-aws.tf.example (for Real AWS - rename to use)
# =====================================================

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
# DATABASE RESOURCES
# ============================================
# After moving state from old-project:
#   1. Uncomment these resources
#   2. Uncomment the outputs below
#   3. Run terraform plan (should show no changes)
#
# Move commands (run from old-project directory):
#   terraform state mv -state-out=../new-project/terraform.tfstate \
#     aws_security_group.db aws_security_group.db
#   terraform state mv -state-out=../new-project/terraform.tfstate \
#     aws_instance.db aws_instance.db

# TODO: Uncomment after moving state from old-project

# resource "aws_security_group" "db" {
#   name        = "scenario3-db-sg"
#   description = "Security group for database"
#
#   ingress {
#     from_port   = 3306
#     to_port     = 3306
#     protocol    = "tcp"
#     cidr_blocks = ["10.0.0.0/8"]  # Update as needed
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
#     Name = "scenario3-db-sg"
#   }
# }

# resource "aws_instance" "db" {
#   ami           = data.aws_ami.amazon_linux.id
#   instance_type = "t2.small"
#
#   vpc_security_group_ids = [aws_security_group.db.id]
#
#   tags = {
#     Name = "scenario3-db-server"
#     Type = "database"
#   }
# }

# ============================================
# OUTPUTS
# ============================================

# TODO: Uncomment after moving resources

# output "db_instance_id" {
#   description = "ID of the database instance"
#   value       = aws_instance.db.id
# }

# output "db_sg_id" {
#   description = "ID of the database security group"
#   value       = aws_security_group.db.id
# }
