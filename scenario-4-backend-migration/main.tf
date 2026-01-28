# Scenario 4: Backend Migration
# Migrate state from one S3 bucket to another

# =====================================================
# CHOOSE YOUR MODE: LocalStack or Real AWS
# =====================================================
#
# LOCALSTACK (Default - Free, no AWS account needed):
#   - Uses: provider-localstack.tf + backend-a.tf
#   - Start LocalStack: docker-compose up -d
#   - Create buckets: ./create-buckets.sh
#
# REAL AWS (Requires AWS account):
#   - Switch provider:
#       mv provider-localstack.tf provider-localstack.tf.bak
#       mv provider-aws.tf.example provider-aws.tf
#   - Switch backend:
#       mv backend-a.tf backend-a-localstack.tf.bak
#       mv backend-a-aws.tf.example backend-a.tf
#   - Create buckets: ./create-buckets.sh aws
#   - Update backend-a.tf with your bucket name
#
# =====================================================

# =====================================================
# TASK: Migrate state from bucket-a to bucket-b
# =====================================================
#
# This simulates a common real-world scenario:
# - Company restructuring storage
# - Moving to a different region
# - Consolidating state files
# - Changing naming conventions
#
# Steps:
# 1. Run create-buckets.sh to create both S3 buckets
# 2. terraform init (uses backend-a.tf - bucket A)
# 3. terraform apply (creates resources, state in bucket A)
# 4. Verify state is in bucket A
# 5. Switch to backend-b.tf configuration
# 6. terraform init -migrate-state (moves state to bucket B)
# 7. Verify state is now in bucket B
# 8. Verify: terraform plan shows "No changes"
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
  default     = "ami-12345678"  # LocalStack default; override for Real AWS
}

variable "use_localstack" {
  description = "Set to false when using Real AWS"
  type        = bool
  default     = true
}

# =====================================================
# Resources to track in state
# =====================================================

resource "aws_instance" "app" {
  ami           = var.ami_id
  instance_type = "t2.micro"

  tags = {
    Name        = "backend-migration-demo"
    Environment = "learning"
    Scenario    = "4-backend-migration"
  }
}

resource "aws_security_group" "app" {
  name        = "scenario4-app-sg"
  description = "Security group for backend migration demo"

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
    Name = "scenario4-app-sg"
  }
}

# =====================================================
# Outputs
# =====================================================

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.app.id
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.app.id
}
