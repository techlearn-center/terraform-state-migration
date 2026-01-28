# AWS Provider - LOCALSTACK Configuration
# ========================================
# Use this for local development with LocalStack (FREE, no AWS account needed)
#
# To switch to Real AWS:
#   mv provider-localstack.tf provider-localstack.tf.bak
#   mv provider-aws.tf.example provider-aws.tf
#
# ========================================

provider "aws" {
  region     = "us-east-1"
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
  s3_use_path_style           = true
}
