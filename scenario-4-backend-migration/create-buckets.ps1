# ============================================================================
# Create S3 Buckets for Backend Migration Scenario (Windows PowerShell)
# ============================================================================
#
# This script creates TWO S3 buckets:
#   - Bucket A (source): Where state starts
#   - Bucket B (target): Where state migrates to
#
# USAGE:
#   .\create-buckets.ps1              # Uses LocalStack (default)
#   .\create-buckets.ps1 localstack   # Explicitly use LocalStack
#   .\create-buckets.ps1 aws          # Use Real AWS
#
# ============================================================================

param(
    [Parameter(Position=0)]
    [ValidateSet("localstack", "aws")]
    [string]$Mode = "localstack"
)

$ErrorActionPreference = "Stop"

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "  Create S3 Buckets for Backend Migration" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""

if ($Mode -eq "aws") {
    # ========================================
    # REAL AWS MODE
    # ========================================
    Write-Host "Mode: REAL AWS" -ForegroundColor Yellow
    Write-Host ""

    # Check AWS credentials
    try {
        $identity = aws sts get-caller-identity 2>$null | ConvertFrom-Json
        if (-not $identity) { throw "No credentials" }
    }
    catch {
        Write-Host "X AWS credentials not configured!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Run: aws configure"
        Write-Host "Then try again."
        exit 1
    }

    $ACCOUNT_ID = $identity.Account
    $BUCKET_A = "tfstate-bucket-a-$ACCOUNT_ID"
    $BUCKET_B = "tfstate-bucket-b-$ACCOUNT_ID"
    $REGION = if ($env:AWS_DEFAULT_REGION) { $env:AWS_DEFAULT_REGION } else { "us-east-1" }

    Write-Host "Account ID: $ACCOUNT_ID"
    Write-Host "Source Bucket (A): $BUCKET_A"
    Write-Host "Target Bucket (B): $BUCKET_B"
    Write-Host "Region: $REGION"
    Write-Host ""

    # Create Bucket A
    Write-Host "Creating Bucket A (source)..." -ForegroundColor Yellow
    if ($REGION -eq "us-east-1") {
        aws s3 mb "s3://$BUCKET_A" --region $REGION 2>$null
    }
    else {
        aws s3 mb "s3://$BUCKET_A" --region $REGION `
            --create-bucket-configuration LocationConstraint=$REGION 2>$null
    }
    aws s3api put-bucket-versioning --bucket $BUCKET_A --versioning-configuration Status=Enabled

    # Create Bucket B
    Write-Host "Creating Bucket B (target)..." -ForegroundColor Yellow
    if ($REGION -eq "us-east-1") {
        aws s3 mb "s3://$BUCKET_B" --region $REGION 2>$null
    }
    else {
        aws s3 mb "s3://$BUCKET_B" --region $REGION `
            --create-bucket-configuration LocationConstraint=$REGION 2>$null
    }
    aws s3api put-bucket-versioning --bucket $BUCKET_B --versioning-configuration Status=Enabled

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host "  Buckets Created Successfully!" -ForegroundColor Green
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Source: s3://$BUCKET_A" -ForegroundColor White
    Write-Host "Target: s3://$BUCKET_B" -ForegroundColor White
    Write-Host ""
    Write-Host "IMPORTANT: Update the backend files:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Edit backend-a.tf - set bucket = `"$BUCKET_A`""
    Write-Host "   Remove LocalStack-specific settings (endpoints, skip_*, etc.)"
    Write-Host ""
    Write-Host "2. Edit backend-b.tf.example - set bucket = `"$BUCKET_B`""
    Write-Host "   Remove LocalStack-specific settings"
    Write-Host ""
    Write-Host "Then follow these steps:" -ForegroundColor Cyan
    Write-Host "  1. terraform init (uses backend-a.tf)"
    Write-Host "  2. terraform apply"
    Write-Host "  3. Verify state in bucket A"
    Write-Host "  4. Rename backend-a.tf to backend-a.tf.bak"
    Write-Host "  5. Rename backend-b.tf.example to backend-b.tf"
    Write-Host "  6. terraform init -migrate-state"
    Write-Host "  7. Verify state now in bucket B"
    Write-Host ""
}
else {
    # ========================================
    # LOCALSTACK MODE (Default)
    # ========================================
    Write-Host "Mode: LOCALSTACK (Free)" -ForegroundColor Yellow
    Write-Host ""

    $BUCKET_A = "tfstate-bucket-a"
    $BUCKET_B = "tfstate-bucket-b"
    $ENDPOINT = "http://localhost:4566"

    # Check if LocalStack is running
    try {
        $health = Invoke-RestMethod -Uri "$ENDPOINT/_localstack/health" -TimeoutSec 5 -ErrorAction SilentlyContinue
    }
    catch {
        Write-Host "X LocalStack not running!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Start it with:"
        Write-Host "  docker-compose up -d"
        Write-Host ""
        Write-Host "Then try again."
        exit 1
    }

    Write-Host "LocalStack endpoint: $ENDPOINT"
    Write-Host "Source Bucket (A): $BUCKET_A"
    Write-Host "Target Bucket (B): $BUCKET_B"
    Write-Host ""

    # Create Bucket A
    Write-Host "Creating Bucket A (source)..." -ForegroundColor Yellow
    aws s3 mb "s3://$BUCKET_A" --endpoint-url $ENDPOINT 2>$null
    aws s3api put-bucket-versioning `
        --bucket $BUCKET_A `
        --versioning-configuration Status=Enabled `
        --endpoint-url $ENDPOINT

    # Create Bucket B
    Write-Host "Creating Bucket B (target)..." -ForegroundColor Yellow
    aws s3 mb "s3://$BUCKET_B" --endpoint-url $ENDPOINT 2>$null
    aws s3api put-bucket-versioning `
        --bucket $BUCKET_B `
        --versioning-configuration Status=Enabled `
        --endpoint-url $ENDPOINT

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host "  Buckets Created Successfully!" -ForegroundColor Green
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Source: s3://$BUCKET_A (LocalStack)" -ForegroundColor White
    Write-Host "Target: s3://$BUCKET_B (LocalStack)" -ForegroundColor White
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. terraform init     (uses backend-a.tf)"
    Write-Host "  2. terraform apply -auto-approve"
    Write-Host "  3. Verify state in bucket A:"
    Write-Host "     aws s3 ls s3://$BUCKET_A/ --recursive --endpoint-url $ENDPOINT"
    Write-Host ""
    Write-Host "  4. Rename backend-a.tf to backend-a.tf.bak"
    Write-Host "  5. Rename backend-b.tf.example to backend-b.tf"
    Write-Host "  6. terraform init -migrate-state"
    Write-Host "  7. Verify state moved to bucket B:"
    Write-Host "     aws s3 ls s3://$BUCKET_B/ --recursive --endpoint-url $ENDPOINT"
    Write-Host ""
}
