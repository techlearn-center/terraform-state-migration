# Scenario 2: Import Existing Resources
# ======================================
# A resource was created manually (via setup.sh).
# Your task: Import it into Terraform management.

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

  # LocalStack configuration (remove for real AWS)
  access_key = "test"
  secret_key = "test"

  endpoints {
    ec2 = "http://localhost:4566"
    s3  = "http://localhost:4566"
    sts = "http://localhost:4566"
  }

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

# TODO: Write the resource configuration for the manually-created instance
#
# Steps:
# 1. Run setup.sh to create a resource "manually"
# 2. Note the instance ID from the output
# 3. Write the resource block below
# 4. Run: terraform import aws_instance.imported <instance-id>
# 5. Run: terraform state show aws_instance.imported
# 6. Update this config to match the imported state
# 7. Run: terraform plan (should show no changes)
#
# Hint: Start with a minimal resource block:
#
# resource "aws_instance" "imported" {
#   # After import, run 'terraform state show aws_instance.imported'
#   # to see all attributes, then add them here
# }

# TODO: Add your resource block here after running setup.sh
# Example:
# resource "aws_instance" "imported" {
#   ami           = "ami-12345678"
#   instance_type = "t2.micro"
#   tags = {
#     Name      = "manually-created-instance"
#     CreatedBy = "console"
#   }
# }
