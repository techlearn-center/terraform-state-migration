# ============================================================================
# Create S3 Bucket for Terraform State Storage (Windows PowerShell)
# ============================================================================
#
# This script creates an S3 bucket for storing Terraform state files.
# It works with both LocalStack (free) and Real AWS.
#
# USAGE:
#   .\create-bucket.ps1                      # Uses LocalStack (default)
#   .\create-bucket.ps1 localstack           # Explicitly use LocalStack
#   .\create-bucket.ps1 aws                  # Use Real AWS (auto-generates name)
#   .\create-bucket.ps1 aws my-bucket-name   # Use Real AWS with custom name
#
# ============================================================================

param(
    [Parameter(Position=0)]
    [ValidateSet("localstack", "aws")]
    [string]$Mode = "localstack",

    [Parameter(Position=1)]
    [string]$CustomBucket = ""
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
    $REGION = if ($env:AWS_DEFAULT_REGION) { $env:AWS_DEFAULT_REGION } else { "us-east-1" }

    # Determine bucket name
    if ($CustomBucket) {
        $BUCKET_NAME = $CustomBucket
    }
    else {
        $TIMESTAMP = Get-Date -Format "yyyyMMddHHmmss"
        $BUCKET_NAME = "tfstate-scenario1-$ACCOUNT_ID-$TIMESTAMP"
    }

    Write-Host "Account ID: $ACCOUNT_ID"
    Write-Host "Bucket Name: $BUCKET_NAME"
    Write-Host "Region: $REGION"
    Write-Host ""

    # Check if bucket already exists and we own it
    $bucketExists = $false
    try {
        aws s3api head-bucket --bucket $BUCKET_NAME 2>$null
        $bucketExists = $true
        Write-Host "Bucket '$BUCKET_NAME' already exists and you own it." -ForegroundColor Green
        Write-Host ""
    }
    catch {
        $bucketExists = $false
    }

    if (-not $bucketExists) {
        Write-Host "Creating S3 bucket..." -ForegroundColor Yellow
        try {
            if ($REGION -eq "us-east-1") {
                aws s3 mb "s3://$BUCKET_NAME" --region $REGION
            }
            else {
                aws s3 mb "s3://$BUCKET_NAME" --region $REGION `
                    --create-bucket-configuration LocationConstraint=$REGION
            }
            Write-Host "Bucket created successfully!" -ForegroundColor Green
        }
        catch {
            Write-Host ""
            Write-Host "X Failed to create bucket '$BUCKET_NAME'" -ForegroundColor Red
            Write-Host ""
            Write-Host "Possible causes:"
            Write-Host "  1. Bucket name already taken globally"
            Write-Host "  2. Invalid bucket name"
            Write-Host "  3. Insufficient permissions"
            Write-Host ""
            Write-Host "Try with a custom bucket name:"
            Write-Host "  .\create-bucket.ps1 aws my-unique-bucket-name"
            Write-Host ""
            exit 1
        }
    }

    # Enable versioning
    Write-Host "Enabling versioning..." -ForegroundColor Yellow
    aws s3api put-bucket-versioning `
        --bucket $BUCKET_NAME `
        --versioning-configuration Status=Enabled
    Write-Host "Versioning enabled" -ForegroundColor Green

    # Enable encryption
    Write-Host "Enabling encryption..." -ForegroundColor Yellow
    $encryptConfig = '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
    aws s3api put-bucket-encryption `
        --bucket $BUCKET_NAME `
        --server-side-encryption-configuration $encryptConfig
    Write-Host "Encryption enabled" -ForegroundColor Green

    # Block public access
    Write-Host "Blocking public access..." -ForegroundColor Yellow
    aws s3api put-public-access-block `
        --bucket $BUCKET_NAME `
        --public-access-block-configuration `
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    Write-Host "Public access blocked" -ForegroundColor Green

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host "  Bucket Ready!" -ForegroundColor Green
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Bucket: s3://$BUCKET_NAME" -ForegroundColor White
    Write-Host ""
    Write-Host "IMPORTANT: Update backend.tf with this configuration:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "terraform {"
    Write-Host "  backend `"s3`" {"
    Write-Host "    bucket  = `"$BUCKET_NAME`""
    Write-Host "    key     = `"scenario-1/terraform.tfstate`""
    Write-Host "    region  = `"$REGION`""
    Write-Host "    encrypt = true"
    Write-Host "  }"
    Write-Host "}"
    Write-Host ""
    Write-Host "Also REMOVE these LocalStack-specific lines from backend.tf:" -ForegroundColor Yellow
    Write-Host "  - endpoints { ... }"
    Write-Host "  - skip_credentials_validation = true"
    Write-Host "  - skip_metadata_api_check = true"
    Write-Host "  - skip_requesting_account_id = true"
    Write-Host "  - use_path_style = true"
    Write-Host "  - access_key = `"test`""
    Write-Host "  - secret_key = `"test`""
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
