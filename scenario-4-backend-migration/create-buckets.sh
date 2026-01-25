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
#   ./create-buckets.sh                         # Uses LocalStack (default)
#   ./create-buckets.sh localstack              # Explicitly use LocalStack
#   ./create-buckets.sh aws                     # Use Real AWS (auto-generates names)
#   ./create-buckets.sh aws bucket-a bucket-b   # Use Real AWS with custom names
#
# ============================================================================

set -e

# Determine mode from argument (default: localstack)
MODE="${1:-localstack}"
CUSTOM_BUCKET_A="${2:-}"
CUSTOM_BUCKET_B="${3:-}"

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
    REGION="${AWS_DEFAULT_REGION:-us-east-1}"

    # Determine bucket names
    if [ -n "$CUSTOM_BUCKET_A" ] && [ -n "$CUSTOM_BUCKET_B" ]; then
        BUCKET_A="$CUSTOM_BUCKET_A"
        BUCKET_B="$CUSTOM_BUCKET_B"
    else
        TIMESTAMP=$(date +%Y%m%d%H%M%S)
        BUCKET_A="tfstate-scenario4-a-${ACCOUNT_ID}-${TIMESTAMP}"
        BUCKET_B="tfstate-scenario4-b-${ACCOUNT_ID}-${TIMESTAMP}"
    fi

    echo "Account ID: $ACCOUNT_ID"
    echo "Source Bucket (A): $BUCKET_A"
    echo "Target Bucket (B): $BUCKET_B"
    echo "Region: $REGION"
    echo ""

    # Function to create bucket
    create_bucket() {
        local bucket_name=$1
        local label=$2

        if aws s3api head-bucket --bucket "$bucket_name" 2>/dev/null; then
            echo "✅ Bucket $label '$bucket_name' already exists"
        else
            echo "Creating Bucket $label..."
            if [ "$REGION" = "us-east-1" ]; then
                if ! aws s3 mb "s3://$bucket_name" --region "$REGION"; then
                    echo ""
                    echo "❌ Failed to create bucket '$bucket_name'"
                    echo ""
                    echo "Try with custom bucket names:"
                    echo "  ./create-buckets.sh aws my-bucket-a my-bucket-b"
                    exit 1
                fi
            else
                if ! aws s3 mb "s3://$bucket_name" --region "$REGION" \
                    --create-bucket-configuration LocationConstraint="$REGION"; then
                    echo "❌ Failed to create bucket '$bucket_name'"
                    exit 1
                fi
            fi
            echo "✅ Bucket $label created"
        fi

        # Enable versioning
        aws s3api put-bucket-versioning --bucket "$bucket_name" --versioning-configuration Status=Enabled
    }

    # Create both buckets
    create_bucket "$BUCKET_A" "A (source)"
    create_bucket "$BUCKET_B" "B (target)"

    echo ""
    echo "=============================================="
    echo "  ✅ Buckets Ready!"
    echo "=============================================="
    echo ""
    echo "Source: s3://$BUCKET_A"
    echo "Target: s3://$BUCKET_B"
    echo ""
    echo "IMPORTANT: Update the backend files:"
    echo ""
    echo "1. Edit backend-a.tf:"
    echo "   - Set: bucket = \"$BUCKET_A\""
    echo "   - REMOVE all LocalStack settings (endpoints, skip_*, access_key, etc.)"
    echo ""
    echo "2. Edit backend-b.tf.example:"
    echo "   - Set: bucket = \"$BUCKET_B\""
    echo "   - REMOVE all LocalStack settings"
    echo ""
    echo "Then follow these steps:"
    echo "  1. terraform init (uses backend-a.tf)"
    echo "  2. terraform apply"
    echo "  3. Verify state in bucket A"
    echo "  4. mv backend-a.tf backend-a.tf.bak"
    echo "  5. mv backend-b.tf.example backend-b.tf"
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
    echo "✅ Bucket A ready"

    # Create Bucket B
    echo "Creating Bucket B (target)..."
    aws s3 mb "s3://$BUCKET_B" --endpoint-url "$ENDPOINT" 2>/dev/null || echo "Bucket B may already exist"
    aws s3api put-bucket-versioning \
        --bucket "$BUCKET_B" \
        --versioning-configuration Status=Enabled \
        --endpoint-url "$ENDPOINT"
    echo "✅ Bucket B ready"

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
    echo "  4. mv backend-a.tf backend-a.tf.bak"
    echo "  5. mv backend-b.tf.example backend-b.tf"
    echo "  6. terraform init -migrate-state"
    echo "  7. Verify state moved to bucket B:"
    echo "     aws s3 ls s3://$BUCKET_B/ --recursive --endpoint-url $ENDPOINT"
    echo ""
fi
