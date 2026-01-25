#!/bin/bash
# ============================================================================
# Create S3 Bucket for Terraform State Storage
# ============================================================================
#
# This script creates an S3 bucket for storing Terraform state files.
# It works with both LocalStack (free) and Real AWS.
#
# USAGE:
#   ./create-bucket.sh              # Uses LocalStack (default)
#   ./create-bucket.sh localstack   # Explicitly use LocalStack
#   ./create-bucket.sh aws          # Use Real AWS
#
# ============================================================================

set -e

# Determine mode from argument (default: localstack)
MODE="${1:-localstack}"

echo "=============================================="
echo "  Create S3 Bucket for Terraform State"
echo "=============================================="
echo ""

if [ "$MODE" = "aws" ]; then
    # ========================================
    # REAL AWS MODE
    # ========================================
    echo "Mode: REAL AWS"
    echo ""

    # Check AWS credentials
    if ! aws sts get-caller-identity &>/dev/null; then
        echo "❌ AWS credentials not configured!"
        echo ""
        echo "Run: aws configure"
        echo "Then try again."
        exit 1
    fi

    # Get account ID for unique bucket name
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    BUCKET_NAME="tfstate-${ACCOUNT_ID}"
    REGION="${AWS_DEFAULT_REGION:-us-east-1}"

    echo "Account ID: $ACCOUNT_ID"
    echo "Bucket Name: $BUCKET_NAME"
    echo "Region: $REGION"
    echo ""

    # Create bucket
    echo "Creating S3 bucket..."
    if [ "$REGION" = "us-east-1" ]; then
        aws s3 mb "s3://$BUCKET_NAME" --region "$REGION" 2>/dev/null || echo "Bucket may already exist"
    else
        aws s3 mb "s3://$BUCKET_NAME" --region "$REGION" \
            --create-bucket-configuration LocationConstraint="$REGION" 2>/dev/null || echo "Bucket may already exist"
    fi

    # Enable versioning
    echo "Enabling versioning..."
    aws s3api put-bucket-versioning \
        --bucket "$BUCKET_NAME" \
        --versioning-configuration Status=Enabled

    # Enable encryption
    echo "Enabling encryption..."
    aws s3api put-bucket-encryption \
        --bucket "$BUCKET_NAME" \
        --server-side-encryption-configuration '{
            "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
        }'

    # Block public access
    echo "Blocking public access..."
    aws s3api put-public-access-block \
        --bucket "$BUCKET_NAME" \
        --public-access-block-configuration \
            "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

    echo ""
    echo "=============================================="
    echo "  ✅ Bucket Created Successfully!"
    echo "=============================================="
    echo ""
    echo "Bucket: s3://$BUCKET_NAME"
    echo ""
    echo "IMPORTANT: Update backend.tf with:"
    echo ""
    echo '  terraform {'
    echo '    backend "s3" {'
    echo "      bucket = \"$BUCKET_NAME\""
    echo '      key    = "scenario-1/terraform.tfstate"'
    echo "      region = \"$REGION\""
    echo '      encrypt = true'
    echo '    }'
    echo '  }'
    echo ""
    echo "Then run:"
    echo "  terraform init -migrate-state"
    echo ""

else
    # ========================================
    # LOCALSTACK MODE (Default)
    # ========================================
    echo "Mode: LOCALSTACK (Free)"
    echo ""

    BUCKET_NAME="terraform-state-migration-demo"
    ENDPOINT="http://localhost:4566"

    # Check if LocalStack is running
    if ! curl -s "$ENDPOINT/_localstack/health" &>/dev/null; then
        echo "❌ LocalStack not running!"
        echo ""
        echo "Start it with:"
        echo "  docker-compose up -d"
        echo ""
        echo "Then try again."
        exit 1
    fi

    echo "LocalStack endpoint: $ENDPOINT"
    echo "Bucket Name: $BUCKET_NAME"
    echo ""

    # Create bucket
    echo "Creating S3 bucket..."
    aws s3 mb "s3://$BUCKET_NAME" \
        --endpoint-url "$ENDPOINT" \
        2>/dev/null || echo "Bucket may already exist"

    # Enable versioning
    echo "Enabling versioning..."
    aws s3api put-bucket-versioning \
        --bucket "$BUCKET_NAME" \
        --versioning-configuration Status=Enabled \
        --endpoint-url "$ENDPOINT"

    echo ""
    echo "=============================================="
    echo "  ✅ Bucket Created Successfully!"
    echo "=============================================="
    echo ""
    echo "Bucket: s3://$BUCKET_NAME (LocalStack)"
    echo ""
    echo "Next steps:"
    echo "  1. Uncomment the S3 backend block in backend.tf"
    echo "  2. Run: terraform init -migrate-state"
    echo "  3. Answer 'yes' to copy existing state"
    echo ""
    echo "Verify bucket contents with:"
    echo "  aws s3 ls s3://$BUCKET_NAME/ --endpoint-url $ENDPOINT --recursive"
    echo ""
fi
