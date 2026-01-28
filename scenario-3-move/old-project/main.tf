# Scenario 3: Old Project (Source)
# =================================
# This project has grown too large.
# Your task: Move database resources to new-project.

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
# WEB RESOURCES (Keep in this project)
# ============================================

resource "aws_security_group" "web" {
  name        = "scenario3-web-sg"
  description = "Security group for web servers"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "scenario3-web-sg"
  }
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.web.id]

  tags = {
    Name = "scenario3-web-server"
  }
}

# ============================================
# DATABASE RESOURCES (Move to new-project)
# ============================================
# After moving with terraform state mv:
#   1. Comment out these resources
#   2. Comment out the db outputs below
#   3. Run terraform plan (should show no changes)

resource "aws_security_group" "db" {
  name        = "scenario3-db-sg"
  description = "Security group for database"

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "scenario3-db-sg"
  }
}

resource "aws_instance" "db" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.small"

  vpc_security_group_ids = [aws_security_group.db.id]

  tags = {
    Name = "scenario3-db-server"
    Type = "database"
  }
}

# ============================================
# OUTPUTS
# ============================================

output "web_instance_id" {
  description = "ID of the web server instance"
  value       = aws_instance.web.id
}

output "web_sg_id" {
  description = "ID of the web security group"
  value       = aws_security_group.web.id
}

# Comment these out after moving db resources:
output "db_instance_id" {
  description = "ID of the database instance"
  value       = aws_instance.db.id
}

output "db_sg_id" {
  description = "ID of the database security group"
  value       = aws_security_group.db.id
}
