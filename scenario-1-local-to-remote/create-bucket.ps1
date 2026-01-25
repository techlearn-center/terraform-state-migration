# ============================================================================
# Create S3 Bucket for Terraform State Storage (Windows PowerShell)
# ============================================================================
#
# This script creates an S3 bucket for storing Terraform state files.
# It works with both LocalStack (free) and Real AWS.
#
# USAGE:
#   .\create-bucket.ps1              # Uses LocalStack (default)
#   .\create-bucket.ps1 localstack   # Explicitly use LocalStack
#   .\create-bucket.ps1 aws          # Use Real AWS
#
# ============================================================================

param(
    [Parameter(Position=0)]
    [ValidateSet("localstack", "aws")]
    [string]$Mode = "localstack"
)

$ErrorActionPreference = "Stop"

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "  Create S3 Bucket for Terraform State" -ForegroundColor Cyan
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
    $BUCKET_NAME = "tfstate-$ACCOUNT_ID"
    $REGION = if ($env:AWS_DEFAULT_REGION) { $env:AWS_DEFAULT_REGION } else { "us-east-1" }

    Write-Host "Account ID: $ACCOUNT_ID"
    Write-Host "Bucket Name: $BUCKET_NAME"
    Write-Host "Region: $REGION"
    Write-Host ""

    # Create bucket
    Write-Host "Creating S3 bucket..." -ForegroundColor Yellow
    if ($REGION -eq "us-east-1") {
        aws s3 mb "s3://$BUCKET_NAME" --region $REGION 2>$null
    }
    else {
        aws s3 mb "s3://$BUCKET_NAME" --region $REGION `
            --create-bucket-configuration LocationConstraint=$REGION 2>$null
    }

    # Enable versioning
    Write-Host "Enabling versioning..." -ForegroundColor Yellow
    aws s3api put-bucket-versioning `
        --bucket $BUCKET_NAME `
        --versioning-configuration Status=Enabled

    # Enable encryption
    Write-Host "Enabling encryption..." -ForegroundColor Yellow
    $encryptConfig = '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
    aws s3api put-bucket-encryption `
        --bucket $BUCKET_NAME `
        --server-side-encryption-configuration $encryptConfig

    # Block public access
    Write-Host "Blocking public access..." -ForegroundColor Yellow
    aws s3api put-public-access-block `
        --bucket $BUCKET_NAME `
        --public-access-block-configuration `
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host "  Bucket Created Successfully!" -ForegroundColor Green
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Bucket: s3://$BUCKET_NAME" -ForegroundColor White
    Write-Host ""
    Write-Host "IMPORTANT: Update backend.tf with:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  terraform {"
    Write-Host "    backend `"s3`" {"
    Write-Host "      bucket = `"$BUCKET_NAME`""
    Write-Host "      key    = `"scenario-1/terraform.tfstate`""
    Write-Host "      region = `"$REGION`""
    Write-Host "      encrypt = true"
    Write-Host "    }"
    Write-Host "  }"
    Write-Host ""
    Write-Host "Then run:"
    Write-Host "  terraform init -migrate-state"
    Write-Host ""
}
else {
    # ========================================
    # LOCALSTACK MODE (Default)
    # ========================================
    Write-Host "Mode: LOCALSTACK (Free)" -ForegroundColor Yellow
    Write-Host ""

    $BUCKET_NAME = "terraform-state-migration-demo"
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
    Write-Host "Bucket Name: $BUCKET_NAME"
    Write-Host ""

    # Create bucket
    Write-Host "Creating S3 bucket..." -ForegroundColor Yellow
    aws s3 mb "s3://$BUCKET_NAME" --endpoint-url $ENDPOINT 2>$null

    # Enable versioning
    Write-Host "Enabling versioning..." -ForegroundColor Yellow
    aws s3api put-bucket-versioning `
        --bucket $BUCKET_NAME `
        --versioning-configuration Status=Enabled `
        --endpoint-url $ENDPOINT

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host "  Bucket Created Successfully!" -ForegroundColor Green
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Bucket: s3://$BUCKET_NAME (LocalStack)" -ForegroundColor White
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Uncomment the S3 backend block in backend.tf"
    Write-Host "  2. Run: terraform init -migrate-state"
    Write-Host "  3. Answer 'yes' to copy existing state"
    Write-Host ""
    Write-Host "Verify bucket contents with:"
    Write-Host "  aws s3 ls s3://$BUCKET_NAME/ --endpoint-url $ENDPOINT --recursive"
    Write-Host ""
}
