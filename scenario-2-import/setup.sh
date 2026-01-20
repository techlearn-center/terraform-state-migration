#!/bin/bash
# Setup Script - Create a "manually" created resource
# ====================================================
# This simulates someone creating resources via AWS Console

ENDPOINT="http://localhost:4566"

echo "Creating EC2 instance 'manually' (simulating AWS Console)..."
echo ""

# Create the instance using a simple AMI ID (LocalStack accepts any)
RESULT=$(aws ec2 run-instances \
  --image-id "ami-12345678" \
  --instance-type "t2.micro" \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=manually-created-instance},{Key=CreatedBy,Value=console}]' \
  --endpoint-url "$ENDPOINT" \
  --output json 2>&1)

# Check if command succeeded
if [ $? -ne 0 ]; then
  echo "Error: Could not create instance."
  echo "Make sure LocalStack is running: docker run -d -p 4566:4566 localstack/localstack"
  echo ""
  echo "Error details: $RESULT"
  exit 1
fi

# Extract instance ID
INSTANCE_ID=$(echo "$RESULT" | grep -o '"InstanceId": "[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$INSTANCE_ID" ]; then
  echo "Error: Could not extract instance ID from response."
  exit 1
fi

echo "=========================================="
echo "  MANUALLY CREATED RESOURCE"
echo "=========================================="
echo ""
echo "Instance ID: $INSTANCE_ID"
echo "AMI ID:      ami-12345678"
echo "Type:        t2.micro"
echo ""
echo "=========================================="
echo ""
echo "Your task:"
echo "1. Add a minimal resource block to main.tf:"
echo ""
echo "   resource \"aws_instance\" \"imported\" {"
echo "     # Will be filled in after import"
echo "   }"
echo ""
echo "2. Run: terraform import aws_instance.imported $INSTANCE_ID"
echo "3. Run: terraform state show aws_instance.imported"
echo "4. Update main.tf to match the imported state"
echo "5. Run: terraform plan (should show no changes)"
echo ""

# Save instance ID for reference
echo "$INSTANCE_ID" > .instance_id
echo "Instance ID saved to .instance_id"
