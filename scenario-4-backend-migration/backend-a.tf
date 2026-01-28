# Backend A Configuration - LOCALSTACK
# =====================================
# This is the INITIAL backend for LocalStack - state starts here
#
# FOR REAL AWS: Use backend-a-aws.tf.example instead
#   mv backend-a.tf backend-a-localstack.tf.bak
#   mv backend-a-aws.tf.example backend-a.tf
#
# =====================================

terraform {
  backend "s3" {
    bucket = "tfstate-bucket-a"
    key    = "scenario-4/terraform.tfstate"
    region = "us-east-1"

    # LocalStack-specific settings
    endpoints = {
      s3 = "http://localhost:4566"
    }
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    use_path_style              = true
    access_key                  = "test"
    secret_key                  = "test"
  }
}

# =====================================================
# LOCALSTACK INSTRUCTIONS:
# =====================================================
#
# SETUP:
#   1. Start LocalStack: docker-compose up -d
#   2. Create buckets: ./create-buckets.sh
#
# INITIAL STATE IN BUCKET A:
#   terraform init
#   terraform apply -auto-approve
#   aws s3 ls s3://tfstate-bucket-a/ --recursive --endpoint-url http://localhost:4566
#
# MIGRATE TO BUCKET B:
#   mv backend-a.tf backend-a.tf.bak
#   mv backend-b.tf.example backend-b.tf
#   terraform init -migrate-state
#   (Answer "yes" when prompted)
#
# VERIFY MIGRATION:
#   terraform plan  # Should show "No changes"
#   aws s3 ls s3://tfstate-bucket-b/ --recursive --endpoint-url http://localhost:4566
#
# =====================================================
