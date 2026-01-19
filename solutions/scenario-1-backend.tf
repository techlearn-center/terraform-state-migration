# Solution: Scenario 1 - Backend Configuration
# =============================================

terraform {
  backend "s3" {
    bucket = "terraform-state-migration-demo"
    key    = "scenario-1/terraform.tfstate"
    region = "us-east-1"

    # For LocalStack only - remove for real AWS
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
