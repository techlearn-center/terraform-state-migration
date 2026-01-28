# Scenario 5: State Recovery
# Recover from lost or corrupted state file

# =====================================================
# CHOOSE YOUR MODE: LocalStack or Real AWS
# =====================================================
#
# LOCALSTACK (Default - Free, no AWS account needed):
#   - Uses: provider-localstack.tf
#   - Start LocalStack: docker-compose up -d (from repo root)
#   - Run disaster: ./simulate-disaster.sh
#
# REAL AWS (Requires AWS account):
#   - Switch provider:
#       mv provider-localstack.tf provider-localstack.tf.bak
#       mv provider-aws.tf.example provider-aws.tf
#   - Copy tfvars:
#       mv terraform.tfvars.aws.example terraform.tfvars
#   - Update terraform.tfvars with correct AMI ID
#   - Run disaster: ./simulate-disaster.sh aws
#
# =====================================================

# =====================================================
# TASK: Rebuild state from existing resources
# =====================================================
#
# This simulates a disaster recovery scenario:
# - State file was accidentally deleted
# - State file became corrupted
# - State was lost during migration
# - Need to "adopt" orphaned resources
#
# Steps:
# 1. Run simulate-disaster.sh to create resources and "lose" state
# 2. terraform init
# 3. terraform plan shows it wants to CREATE resources
#    (but they already exist!)
# 4. Import each existing resource:
#    terraform import aws_instance.web <INSTANCE_ID>
#    terraform import aws_security_group.web <SG_ID>
#    terraform import aws_ebs_volume.data <VOLUME_ID>
# 5. terraform plan shows "No changes" (state recovered!)
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

# =====================================================
# Variables for flexibility between LocalStack and Real AWS
# =====================================================

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
  default     = "ami-recovery-test"  # LocalStack default; override for Real AWS
}

variable "availability_zone" {
  description = "Availability zone for EBS volume"
  type        = string
  default     = "us-east-1a"
}

# =====================================================
# Resources to recover
# These definitions must match the existing resources
# =====================================================

resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = "t2.micro"

  tags = {
    Name        = "recovery-web-server"
    Environment = "production"
    Scenario    = "5-state-recovery"
  }
}

resource "aws_security_group" "web" {
  name        = "recovery-web-sg"
  description = "Security group for recovered web server"

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
    Name = "recovery-web-sg"
  }
}

resource "aws_ebs_volume" "data" {
  availability_zone = var.availability_zone
  size              = 100
  type              = "gp3"

  tags = {
    Name        = "recovery-data-volume"
    Environment = "production"
  }
}

# =====================================================
# Outputs
# =====================================================

output "instance_id" {
  description = "ID of the recovered web instance"
  value       = aws_instance.web.id
}

output "security_group_id" {
  description = "ID of the recovered security group"
  value       = aws_security_group.web.id
}

output "volume_id" {
  description = "ID of the recovered EBS volume"
  value       = aws_ebs_volume.data.id
}
