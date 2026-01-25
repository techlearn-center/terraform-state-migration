#!/bin/bash
# ============================================================================
# Create S3 Buckets for Backend Migration Scenario
# ============================================================================
#
# This script creates TWO S3 buckets:
#   - Bucket A (source): Where state starts
#   - Bucket B (target): Where state migrates to
#
# USAGE:
#   ./create-buckets.sh              # Uses LocalStack (default)
#   ./create-buckets.sh localstack   # Explicitly use LocalStack
#   ./create-buckets.sh aws          # Use Real AWS
#
# ============================================================================

set -e

# Determine mode from argument (default: localstack)
MODE="${1:-localstack}"

echo "=============================================="
echo "  Create S3 Buckets for Backend Migration"
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

    # Get account ID for unique bucket names
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    BUCKET_A="tfstate-bucket-a-${ACCOUNT_ID}"
    BUCKET_B="tfstate-bucket-b-${ACCOUNT_ID}"
    REGION="${AWS_DEFAULT_REGION:-us-east-1}"

    echo "Account ID: $ACCOUNT_ID"
    echo "Source Bucket (A): $BUCKET_A"
    echo "Target Bucket (B): $BUCKET_B"
    echo "Region: $REGION"
    echo ""

    # Create Bucket A
    echo "Creating Bucket A (source)..."
    if [ "$REGION" = "us-east-1" ]; then
        aws s3 mb "s3://$BUCKET_A" --region "$REGION" 2>/dev/null || echo "Bucket A may already exist"
    else
        aws s3 mb "s3://$BUCKET_A" --region "$REGION" \
            --create-bucket-configuration LocationConstraint="$REGION" 2>/dev/null || echo "Bucket A may already exist"
    fi
    aws s3api put-bucket-versioning --bucket "$BUCKET_A" --versioning-configuration Status=Enabled

    # Create Bucket B
    echo "Creating Bucket B (target)..."
    if [ "$REGION" = "us-east-1" ]; then
        aws s3 mb "s3://$BUCKET_B" --region "$REGION" 2>/dev/null || echo "Bucket B may already exist"
    else
        aws s3 mb "s3://$BUCKET_B" --region "$REGION" \
            --create-bucket-configuration LocationConstraint="$REGION" 2>/dev/null || echo "Bucket B may already exist"
    fi
    aws s3api put-bucket-versioning --bucket "$BUCKET_B" --versioning-configuration Status=Enabled

    echo ""
    echo "=============================================="
    echo "  ✅ Buckets Created Successfully!"
    echo "=============================================="
    echo ""
    echo "Source: s3://$BUCKET_A"
    echo "Target: s3://$BUCKET_B"
    echo ""
    echo "IMPORTANT: Update the backend files:"
    echo ""
    echo "1. Edit backend-a.tf - set bucket = \"$BUCKET_A\""
    echo "   Remove LocalStack-specific settings (endpoints, skip_*, etc.)"
    echo ""
    echo "2. Edit backend-b.tf.example - set bucket = \"$BUCKET_B\""
    echo "   Remove LocalStack-specific settings"
    echo ""
    echo "Then follow these steps:"
    echo "  1. terraform init (uses backend-a.tf)"
    echo "  2. terraform apply"
    echo "  3. Verify state in bucket A"
    echo "  4. Rename backend-a.tf to backend-a.tf.bak"
    echo "  5. Rename backend-b.tf.example to backend-b.tf"
    echo "  6. terraform init -migrate-state"
    echo "  7. Verify state now in bucket B"
    echo ""

else
    # ========================================
    # LOCALSTACK MODE (Default)
    # ========================================
    echo "Mode: LOCALSTACK (Free)"
    echo ""

    BUCKET_A="tfstate-bucket-a"
    BUCKET_B="tfstate-bucket-b"
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
    echo "Source Bucket (A): $BUCKET_A"
    echo "Target Bucket (B): $BUCKET_B"
    echo ""

    # Create Bucket A
    echo "Creating Bucket A (source)..."
    aws s3 mb "s3://$BUCKET_A" --endpoint-url "$ENDPOINT" 2>/dev/null || echo "Bucket A may already exist"
    aws s3api put-bucket-versioning \
        --bucket "$BUCKET_A" \
        --versioning-configuration Status=Enabled \
        --endpoint-url "$ENDPOINT"

    # Create Bucket B
    echo "Creating Bucket B (target)..."
    aws s3 mb "s3://$BUCKET_B" --endpoint-url "$ENDPOINT" 2>/dev/null || echo "Bucket B may already exist"
    aws s3api put-bucket-versioning \
        --bucket "$BUCKET_B" \
        --versioning-configuration Status=Enabled \
        --endpoint-url "$ENDPOINT"

    echo ""
    echo "=============================================="
    echo "  ✅ Buckets Created Successfully!"
    echo "=============================================="
    echo ""
    echo "Source: s3://$BUCKET_A (LocalStack)"
    echo "Target: s3://$BUCKET_B (LocalStack)"
    echo ""
    echo "Next steps:"
    echo "  1. terraform init     (uses backend-a.tf)"
    echo "  2. terraform apply -auto-approve"
    echo "  3. Verify state in bucket A:"
    echo "     aws s3 ls s3://$BUCKET_A/ --recursive --endpoint-url $ENDPOINT"
    echo ""
    echo "  4. Rename backend-a.tf to backend-a.tf.bak"
    echo "  5. Rename backend-b.tf.example to backend-b.tf"
    echo "  6. terraform init -migrate-state"
    echo "  7. Verify state moved to bucket B:"
    echo "     aws s3 ls s3://$BUCKET_B/ --recursive --endpoint-url $ENDPOINT"
    echo ""
fi
