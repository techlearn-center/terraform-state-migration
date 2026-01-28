# Scenario 1: Local to Remote State Migration
# ============================================
# This project currently uses local state.
# Your task: Migrate it to S3 remote state.

# =====================================================
# CHOOSE YOUR MODE: LocalStack or Real AWS
# =====================================================
#
# LOCALSTACK (Default - Free, no AWS account needed):
#   - Uses: provider-localstack.tf
#   - Start LocalStack: docker-compose up -d
#
# REAL AWS (Requires AWS account):
#   - Switch provider:
#       mv provider-localstack.tf provider-localstack.tf.bak
#       mv provider-aws.tf.example provider-aws.tf
#   - Create bucket: ./create-bucket.sh aws
#   - Use backend-aws.tf.example for the S3 backend config
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

# =====================================================
# Resources
# =====================================================

resource "aws_security_group" "web" {
  name        = "scenario1-web-sg"
  description = "Security group for migration demo"

  ingress {
    from_port   = 80
    to_port     = 80
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
    Name    = "scenario1-web-sg"
    Project = "state-migration"
  }
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.web.id]

  tags = {
    Name    = "scenario1-web-server"
    Project = "state-migration"
  }
}

# =====================================================
# Outputs
# =====================================================

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.web.id
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.web.id
}
