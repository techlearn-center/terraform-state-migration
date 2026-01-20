# Setup Script for Windows - Create a "manually" created resource
# ===============================================================
# This simulates someone creating resources via AWS Console

$ENDPOINT = "http://localhost:4566"

Write-Host "Creating EC2 instance 'manually' (simulating AWS Console)..." -ForegroundColor Cyan

# Create the instance using AWS CLI
$result = aws ec2 run-instances `
    --image-id "ami-12345678" `
    --instance-type "t2.micro" `
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=manually-created-instance},{Key=CreatedBy,Value=console}]" `
    --endpoint-url $ENDPOINT `
    --output json 2>$null | ConvertFrom-Json

$INSTANCE_ID = $result.Instances[0].InstanceId

if (-not $INSTANCE_ID) {
    Write-Host "Error: Could not create instance. Make sure LocalStack is running." -ForegroundColor Red
    Write-Host "Start LocalStack with: docker run -d -p 4566:4566 localstack/localstack" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  MANUALLY CREATED RESOURCE" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Instance ID: $INSTANCE_ID" -ForegroundColor Yellow
Write-Host "AMI ID:      ami-12345678"
Write-Host "Type:        t2.micro"
Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Your task:" -ForegroundColor Cyan
Write-Host "1. Write a resource block in main.tf for this instance"
Write-Host "2. Run: terraform import aws_instance.imported $INSTANCE_ID"
Write-Host "3. Run: terraform state show aws_instance.imported"
Write-Host "4. Update main.tf to match the imported state"
Write-Host "5. Run: terraform plan (should show no changes)"
Write-Host ""

# Save instance ID for reference
$INSTANCE_ID | Out-File -FilePath ".instance_id" -NoNewline
