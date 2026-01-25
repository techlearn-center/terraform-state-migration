# Terraform State Migration Challenge

Master the art of Terraform state management, migration, and disaster recovery.

---

## What You'll Learn

- Migrate state from local to remote (S3) backend
- Import existing AWS resources into Terraform
- Move resources between state files
- Backup and recover state files

---

## Choose Your Path

> **Pick ONE path and stick with it for the entire challenge.**

| Path | Cost | Best For | Requirements |
|------|------|----------|--------------|
| 🐳 **LocalStack** | FREE | Learning, practice | Docker, Terraform |
| ☁️ **Real AWS** | ~$1-5 | Production experience | AWS account, Terraform |

---

# 🐳 LOCALSTACK PATH (Free, Recommended for Learning)

<details open>
<summary><b>Click to expand LocalStack instructions</b></summary>

## LocalStack Setup

### Prerequisites
- Docker Desktop installed and running
- Terraform CLI installed
- Python 3 (for grading script)

### Step 1: Clone and Start

```bash
# Clone the repo
git clone https://github.com/techlearn-center/terraform-state-migration.git
cd terraform-state-migration

# Start LocalStack
docker-compose up -d

# Verify LocalStack is running
docker-compose ps
# Should show "localstack" container as "Up"
```

### Step 2: Complete the Scenarios

#### Scenario 1: Local to Remote State Migration

```bash
cd scenario-1-local-to-remote

# Create the S3 bucket in LocalStack
chmod +x create-bucket.sh
./create-bucket.sh

# Initialize with LOCAL state first
# (backend.tf should have S3 backend COMMENTED OUT)
terraform init
terraform apply -auto-approve

# Verify resources created
terraform state list
# Should show: aws_instance.web, aws_security_group.web

# Now uncomment the S3 backend in backend.tf
# Then migrate state to S3
terraform init -migrate-state
# Answer "yes" when prompted

# Verify migration succeeded
terraform plan
# Should show: "No changes"
```

#### Scenario 2: Import Existing Resources

```bash
cd ../scenario-2-import

# Create a resource "manually" (simulating AWS Console)
chmod +x setup.sh
./setup.sh
# Note the Instance ID from output!

# Initialize Terraform
terraform init

# Add resource block to main.tf (if not already there)
# resource "aws_instance" "imported" { }

# Import the existing resource
terraform import aws_instance.imported <INSTANCE_ID>

# View imported attributes
terraform state show aws_instance.imported

# Update main.tf to match the imported state
# Then verify
terraform plan
# Should show: "No changes"
```

#### Scenario 3: Move Resources Between States

```bash
cd ../scenario-3-move/old-project

# Create resources in old project
terraform init
terraform apply -auto-approve
terraform state list
# Shows: aws_instance.web, aws_instance.db, etc.

# Initialize new project
cd ../new-project
terraform init

# Go back and move database resources
cd ../old-project
terraform state mv -state-out=../new-project/terraform.tfstate \
  aws_instance.db aws_instance.db

# Verify both projects
terraform state list  # old-project: web only
cd ../new-project
terraform state list  # new-project: db only
```

### Step 3: Verify Your Work

```bash
cd ..  # Back to project root

# Run the grading script
python run.py --verify --mode localstack
```

### Step 4: Submit

```bash
git add .
git commit -m "Complete terraform-state-migration challenge"
git push origin main
# Check GitHub Actions for automated grading
```

</details>

---

# ☁️ REAL AWS PATH (Production Experience)

<details>
<summary><b>Click to expand Real AWS instructions</b></summary>

## Real AWS Setup

### Prerequisites
- AWS Account ([Sign up free](https://aws.amazon.com/free/))
- AWS CLI installed and configured
- Terraform CLI installed
- Python 3 (for grading script)

### Step 1: Configure AWS

```bash
# Configure AWS CLI
aws configure
# Enter:
#   AWS Access Key ID: (from IAM console)
#   AWS Secret Access Key: (from IAM console)
#   Default region: us-east-1
#   Default output format: json

# Verify configuration
aws sts get-caller-identity
# Should show your account ID
```

### Step 2: Clone the Repo

```bash
git clone https://github.com/techlearn-center/terraform-state-migration.git
cd terraform-state-migration
```

### Step 3: Modify Provider Configurations

**IMPORTANT:** You must update the provider blocks in ALL scenario main.tf files.

For each scenario, find and **REPLACE** the LocalStack provider:

```hcl
# DELETE THIS (LocalStack config):
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
}

# REPLACE WITH THIS (Real AWS):
provider "aws" {
  region = "us-east-1"
}
```

### Step 4: Complete the Scenarios

#### Scenario 1: Local to Remote State Migration

```bash
cd scenario-1-local-to-remote

# Create S3 bucket for state (use your account ID for uniqueness)
export STATE_BUCKET="tfstate-$(aws sts get-caller-identity --query Account --output text)"
aws s3 mb s3://$STATE_BUCKET --region us-east-1
aws s3api put-bucket-versioning --bucket $STATE_BUCKET --versioning-configuration Status=Enabled
echo "Your bucket: $STATE_BUCKET"

# Update backend.tf with YOUR bucket name
# Replace: bucket = "your-bucket-name"
# With:    bucket = "tfstate-123456789012"  (your actual bucket)

# Remove LocalStack-specific settings from backend.tf:
# DELETE these lines:
#   endpoints = { s3 = "http://localhost:4566" }
#   skip_credentials_validation = true
#   skip_metadata_api_check     = true
#   skip_requesting_account_id  = true
#   use_path_style              = true
#   access_key                  = "test"
#   secret_key                  = "test"

# Initialize with local state first (backend commented out)
terraform init
terraform apply -auto-approve

# Verify resources created
terraform state list

# Uncomment the S3 backend in backend.tf
# Then migrate
terraform init -migrate-state
# Answer "yes"

# Verify
terraform plan
# Should show: "No changes"

# COLLECT EVIDENCE (Important!)
mkdir -p ../evidence
terraform plan -no-color > ../evidence/scenario1-plan.txt
terraform state list > ../evidence/scenario1-state.txt
aws s3 ls s3://$STATE_BUCKET/ --recursive > ../evidence/s3-state-proof.txt
```

#### Scenario 2: Import Existing Resources

```bash
cd ../scenario-2-import

# Create an EC2 instance manually via AWS Console or CLI
AMI_ID=$(aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=al2023-ami-*-x86_64" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
  --output text)

INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t2.micro \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=manually-created}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Instance ID: $INSTANCE_ID"
# SAVE THIS ID!

# Initialize Terraform
terraform init

# Add to main.tf:
# resource "aws_instance" "imported" { }

# Import
terraform import aws_instance.imported $INSTANCE_ID

# View attributes
terraform state show aws_instance.imported

# Update main.tf with the correct ami and instance_type
# Then verify
terraform plan
# Should show: "No changes"

# COLLECT EVIDENCE
terraform plan -no-color > ../evidence/scenario2-plan.txt
terraform state show aws_instance.imported > ../evidence/scenario2-import.txt
```

#### Scenario 3: Move Resources Between States

```bash
cd ../scenario-3-move/old-project

# Initialize and create resources
terraform init
terraform apply -auto-approve

# Initialize new project
cd ../new-project
terraform init
cd ../old-project

# Move database to new project
terraform state mv -state-out=../new-project/terraform.tfstate \
  aws_instance.db aws_instance.db

# Verify
terraform state list
cd ../new-project
terraform state list

# COLLECT EVIDENCE
terraform state list > ../../evidence/scenario3-new-state.txt
cd ../old-project
terraform state list > ../../evidence/scenario3-old-state.txt
```

### Step 5: Collect AWS Identity Proof

```bash
cd ../..  # Back to project root

# Prove you used real AWS
aws sts get-caller-identity > evidence/aws-identity.txt

# Optional: Take screenshots of AWS Console showing:
# - S3 bucket with state file
# - EC2 instance you imported
# Save as evidence/screenshot-*.png
```

### Step 6: Verify Your Work

```bash
# Run grading with AWS mode
python run.py --verify --mode aws --evidence
```

### Step 7: Clean Up AWS Resources (IMPORTANT!)

```bash
# Destroy resources to avoid charges
cd scenario-1-local-to-remote
terraform destroy -auto-approve

cd ../scenario-2-import
terraform destroy -auto-approve

cd ../scenario-3-move/old-project
terraform destroy -auto-approve
cd ../new-project
terraform destroy -auto-approve

# Delete S3 bucket
aws s3 rb s3://$STATE_BUCKET --force
```

### Step 8: Submit

```bash
git add .
git commit -m "Complete terraform-state-migration challenge with Real AWS"
git push origin main
```

</details>

---

## Grading System

### How Verification Works

The `run.py` script checks your work in three ways:

| Check Type | Command | What It Does |
|------------|---------|--------------|
| **File Check** | `python run.py` | Checks if files exist and have correct content |
| **Live Verify** | `python run.py --verify` | Runs terraform commands to verify state |
| **Evidence** | `python run.py --evidence` | Checks for proof files (Real AWS) |

### For LocalStack Users

```bash
# Basic check
python run.py

# Full verification (recommended)
python run.py --verify --mode localstack
```

### For Real AWS Users

```bash
# Create evidence directory first
mkdir -p evidence

# Collect evidence after each scenario:
terraform plan -no-color > evidence/scenario1-plan.txt
terraform state list > evidence/scenario1-state.txt
aws s3 ls s3://your-bucket/ --recursive > evidence/s3-state-proof.txt
aws sts get-caller-identity > evidence/aws-identity.txt

# Run full verification
python run.py --verify --mode aws --evidence
```

### Evidence Files Checklist

For Real AWS submissions, include these files in `evidence/`:

| File | Command to Generate | Purpose |
|------|---------------------|---------|
| `scenario1-plan.txt` | `terraform plan -no-color > evidence/scenario1-plan.txt` | Proves "No changes" |
| `scenario1-state.txt` | `terraform state list > evidence/scenario1-state.txt` | Shows resources in state |
| `s3-state-proof.txt` | `aws s3 ls s3://bucket/ --recursive > evidence/s3-state-proof.txt` | Proves state in S3 |
| `aws-identity.txt` | `aws sts get-caller-identity > evidence/aws-identity.txt` | Proves real AWS account |
| `screenshot-*.png` | Manual screenshot | Visual proof (optional) |

---

## Quick Reference

### State Commands Cheat Sheet

```bash
# List all resources
terraform state list

# Show resource details
terraform state show aws_instance.web

# Move/rename resource
terraform state mv aws_instance.old aws_instance.new

# Move to different state file
terraform state mv -state-out=other.tfstate aws_instance.db aws_instance.db

# Remove from state (resource still exists!)
terraform state rm aws_instance.web

# Import existing resource
terraform import aws_instance.web i-1234567890abcdef

# Backup state
terraform state pull > backup.json

# Migrate backend
terraform init -migrate-state
```

### Common Issues

| Problem | Solution |
|---------|----------|
| "Backend configuration changed" | `terraform init -reconfigure` |
| "Resource already in state" | `terraform state rm <resource>` then import |
| "No changes" not showing | Update main.tf to match `terraform state show` output |
| LocalStack not working | `docker-compose down && docker-compose up -d` |

---

## Project Structure

```
terraform-state-migration/
├── docker-compose.yml           # LocalStack setup
├── run.py                       # Grading script
├── README.md                    # This file
├── evidence/                    # Your proof files (create this)
│   ├── scenario1-plan.txt
│   ├── scenario1-state.txt
│   ├── s3-state-proof.txt
│   └── aws-identity.txt
├── scenario-1-local-to-remote/  # State migration task
├── scenario-2-import/           # Import existing resources
├── scenario-3-move/             # Move between states
│   ├── old-project/
│   └── new-project/
└── solutions/                   # Reference solutions
```

---

## Scoring

| Component | Points |
|-----------|--------|
| Scenario 1: Files correct | 6 |
| Scenario 2: Files correct | 4 |
| Scenario 3: Files correct | 4 |
| Live Verification (optional) | 6 |
| Evidence Files (Real AWS) | 5 |
| **Total** | **25** |
| **Passing Score** | **60%** |

---

## Next Steps

After completing this challenge:
- [terraform-modules](https://github.com/techlearn-center/terraform-modules) - Build reusable modules
- [aws-iam-advanced](https://github.com/techlearn-center/aws-iam-advanced) - Master IAM policies

---

## Resources

- [Terraform State Documentation](https://developer.hashicorp.com/terraform/language/state)
- [S3 Backend Configuration](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- [Import Documentation](https://developer.hashicorp.com/terraform/cli/import)

---

**Happy State Managing!**
