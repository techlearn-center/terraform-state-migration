# Scenario 2: Import Existing Resources
# ======================================
# A resource was created manually (via setup.sh).
# Your task: Import it into Terraform management.

# =====================================================
# CHOOSE YOUR MODE: LocalStack or Real AWS
# =====================================================
#
# LOCALSTACK (Default - Free, no AWS account needed):
#   - Uses: provider-localstack.tf
#   - Start LocalStack: docker-compose up -d
#   - Run setup: ./setup.sh
#
# REAL AWS (Requires AWS account):
#   - Switch provider:
#       mv provider-localstack.tf provider-localstack.tf.bak
#       mv provider-aws.tf.example provider-aws.tf
#   - Copy tfvars:
#       mv terraform.tfvars.aws.example terraform.tfvars
#   - Run setup: ./setup.sh aws
#   - Update terraform.tfvars with AMI ID from setup output
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
# Variables
# =====================================================

variable "ami_id" {
  description = "AMI ID for the EC2 instance (must match what setup.sh created)"
  type        = string
  default     = "ami-12345678"  # LocalStack default; override for Real AWS
}

# =====================================================
# IMPORT WORKFLOW:
# =====================================================
#
# 1. Run setup.sh to create a "manually" created resource
#    ./setup.sh           (LocalStack)
#    ./setup.sh aws       (Real AWS)
#
# 2. Note the Instance ID from the output
#
# 3. The resource block below is ready for import
#    (For Real AWS, update terraform.tfvars with correct AMI)
#
# 4. Run: terraform init
#
# 5. Run: terraform import aws_instance.imported <INSTANCE_ID>
#
# 6. Run: terraform state show aws_instance.imported
#    to see all attributes
#
# 7. If terraform plan shows changes, update this config
#    to match the imported state
#
# 8. Run: terraform plan (should show "No changes")
#
# =====================================================

# =====================================================
# Resource to Import
# =====================================================
# This resource block is ready for the import command.
# The configuration matches what setup.sh creates.

resource "aws_instance" "imported" {
  ami           = var.ami_id
  instance_type = "t2.micro"

  tags = {
    Name      = "manually-created-instance"
    CreatedBy = "console"
  }
}

# =====================================================
# Output
# =====================================================

output "instance_id" {
  description = "ID of the imported instance"
  value       = aws_instance.imported.id
}
