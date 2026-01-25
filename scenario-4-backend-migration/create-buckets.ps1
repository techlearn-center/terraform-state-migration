# ============================================================================
# Create S3 Buckets for Backend Migration Scenario (Windows PowerShell)
# ============================================================================
#
# This script creates TWO S3 buckets:
#   - Bucket A (source): Where state starts
#   - Bucket B (target): Where state migrates to
#
# USAGE:
#   .\create-buckets.ps1                           # Uses LocalStack (default)
#   .\create-buckets.ps1 localstack                # Explicitly use LocalStack
#   .\create-buckets.ps1 aws                       # Use Real AWS (auto-generates names)
#   .\create-buckets.ps1 aws bucket-a bucket-b     # Use Real AWS with custom names
#
# ============================================================================

param(
    [Parameter(Position=0)]
    [ValidateSet("localstack", "aws")]
    [string]$Mode = "localstack",

    [Parameter(Position=1)]
    [string]$CustomBucketA = "",

    [Parameter(Position=2)]
    [string]$CustomBucketB = ""
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
    $REGION = if ($env:AWS_DEFAULT_REGION) { $env:AWS_DEFAULT_REGION } else { "us-east-1" }

    # Determine bucket names
    if ($CustomBucketA -and $CustomBucketB) {
        $BUCKET_A = $CustomBucketA
        $BUCKET_B = $CustomBucketB
    }
    else {
        $TIMESTAMP = Get-Date -Format "yyyyMMddHHmmss"
        $BUCKET_A = "tfstate-scenario4-a-$ACCOUNT_ID-$TIMESTAMP"
        $BUCKET_B = "tfstate-scenario4-b-$ACCOUNT_ID-$TIMESTAMP"
    }

    Write-Host "Account ID: $ACCOUNT_ID"
    Write-Host "Source Bucket (A): $BUCKET_A"
    Write-Host "Target Bucket (B): $BUCKET_B"
    Write-Host "Region: $REGION"
    Write-Host ""

    # Function to create bucket
    function Create-Bucket {
        param($BucketName, $Label)

        $exists = $false
        try {
            aws s3api head-bucket --bucket $BucketName 2>$null
            $exists = $true
            Write-Host "Bucket $Label '$BucketName' already exists" -ForegroundColor Green
        }
        catch {
            $exists = $false
        }

        if (-not $exists) {
            Write-Host "Creating Bucket $Label..." -ForegroundColor Yellow
            try {
                if ($REGION -eq "us-east-1") {
                    aws s3 mb "s3://$BucketName" --region $REGION
                }
                else {
                    aws s3 mb "s3://$BucketName" --region $REGION `
                        --create-bucket-configuration LocationConstraint=$REGION
                }
                Write-Host "Bucket $Label created" -ForegroundColor Green
            }
            catch {
                Write-Host ""
                Write-Host "X Failed to create bucket '$BucketName'" -ForegroundColor Red
                Write-Host ""
                Write-Host "Try with custom bucket names:"
                Write-Host "  .\create-buckets.ps1 aws my-bucket-a my-bucket-b"
                exit 1
            }
        }

        # Enable versioning
        aws s3api put-bucket-versioning --bucket $BucketName --versioning-configuration Status=Enabled
    }

    # Create both buckets
    Create-Bucket -BucketName $BUCKET_A -Label "A (source)"
    Create-Bucket -BucketName $BUCKET_B -Label "B (target)"

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host "  Buckets Ready!" -ForegroundColor Green
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Source: s3://$BUCKET_A" -ForegroundColor White
    Write-Host "Target: s3://$BUCKET_B" -ForegroundColor White
    Write-Host ""
    Write-Host "IMPORTANT: Update the backend files:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Edit backend-a.tf:"
    Write-Host "   - Set: bucket = `"$BUCKET_A`""
    Write-Host "   - REMOVE all LocalStack settings (endpoints, skip_*, access_key, etc.)"
    Write-Host ""
    Write-Host "2. Edit backend-b.tf.example:"
    Write-Host "   - Set: bucket = `"$BUCKET_B`""
    Write-Host "   - REMOVE all LocalStack settings"
    Write-Host ""
    Write-Host "Then follow these steps:" -ForegroundColor Cyan
    Write-Host "  1. terraform init (uses backend-a.tf)"
    Write-Host "  2. terraform apply"
    Write-Host "  3. Verify state in bucket A"
    Write-Host "  4. Rename-Item backend-a.tf backend-a.tf.bak"
    Write-Host "  5. Rename-Item backend-b.tf.example backend-b.tf"
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
    Write-Host "Bucket A ready" -ForegroundColor Green

    # Create Bucket B
    Write-Host "Creating Bucket B (target)..." -ForegroundColor Yellow
    aws s3 mb "s3://$BUCKET_B" --endpoint-url $ENDPOINT 2>$null
    aws s3api put-bucket-versioning `
        --bucket $BUCKET_B `
        --versioning-configuration Status=Enabled `
        --endpoint-url $ENDPOINT
    Write-Host "Bucket B ready" -ForegroundColor Green

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
    Write-Host "  4. Rename-Item backend-a.tf backend-a.tf.bak"
    Write-Host "  5. Rename-Item backend-b.tf.example backend-b.tf"
    Write-Host "  6. terraform init -migrate-state"
    Write-Host "  7. Verify state moved to bucket B:"
    Write-Host "     aws s3 ls s3://$BUCKET_B/ --recursive --endpoint-url $ENDPOINT"
    Write-Host ""
}
