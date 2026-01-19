# Backend Configuration for S3
# ============================
# TODO: Configure the S3 backend to migrate state from local to remote.
#
# Steps:
# 1. First, create the S3 bucket (run create-bucket.sh)
# 2. Uncomment and configure the backend block below
# 3. Run: terraform init -migrate-state
# 4. Answer "yes" when asked to copy state
# 5. Verify: terraform plan (should show no changes)

# TODO: Uncomment and configure this backend block
#
# terraform {
#   backend "s3" {
#     bucket = "terraform-state-migration-demo"  # Your bucket name
#     key    = "scenario-1/terraform.tfstate"    # State file path in bucket
#     region = "us-east-1"
#
#     # For LocalStack only - remove for real AWS
#     endpoints = {
#       s3 = "http://localhost:4566"
#     }
#     skip_credentials_validation = true
#     skip_metadata_api_check     = true
#     skip_requesting_account_id  = true
#     use_path_style              = true
#     access_key                  = "test"
#     secret_key                  = "test"
#   }
# }
