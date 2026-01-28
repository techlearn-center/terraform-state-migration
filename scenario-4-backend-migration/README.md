# Scenario 4: Backend Migration

## The Scenario

Your company has decided to reorganize its Terraform state storage. You need to migrate state from one S3 bucket to another **without destroying or recreating any resources**.

**Your mission:** Safely migrate Terraform state between S3 backends with zero downtime.

---

## Choose Your Mode

This scenario supports **two modes**. Choose based on your situation:

| Mode | Best For | Cost | Requirements |
|------|----------|------|--------------|
| **LocalStack** (Default) | Learning, practice | Free | Docker installed |
| **Real AWS** | Real-world experience | ~$0.01-0.05 | AWS account + credentials |

---

## Why This Matters

Backend migrations happen frequently in real organizations:

| Situation | Example |
|-----------|---------|
| **Company restructuring** | Moving from `company-old-tfstate` to `company-new-tfstate` |
| **Region change** | Migrating state from `us-east-1` to `eu-west-1` for compliance |
| **Account migration** | Moving state to a new AWS account |
| **Naming convention update** | Changing from `tfstate-prod` to `prod-terraform-state` |
| **Provider change** | Moving from Terraform Cloud to S3 (or vice versa) |

### The Wrong Way vs The Right Way

```
+------------------------------------------------------------------+
|                     BACKEND MIGRATION                             |
+------------------------------------------------------------------+

  WRONG: Delete state and re-apply
  =========================================

  terraform destroy              # Destroys all resources!
  [edit backend config]
  terraform init
  terraform apply                # Recreates everything

  Result: Downtime, potential data loss, DNS changes, etc.


  RIGHT: Use terraform init -migrate-state
  =========================================

  [edit backend config]
  terraform init -migrate-state  # Copies state to new backend
  terraform plan                 # Shows "No changes"

  Result: Zero downtime, no resource changes

+------------------------------------------------------------------+
```

---

## Understanding Backends

### What is a Backend?

A **backend** determines where Terraform stores its **state file**. The state file tracks:
- Which resources Terraform manages
- Resource IDs and attributes
- Dependencies between resources

```
+-------------------+     +-----------------+     +------------------+
|  Your .tf files   | --> | terraform apply | --> | AWS Resources    |
|  (Configuration)  |     |                 |     | (Reality)        |
+-------------------+     +--------+--------+     +------------------+
                                  |
                                  v
                         +-----------------+
                         |   State File    |
                         | (terraform.tfstate)
                         |                 |
                         | Stored in your  |
                         | BACKEND (S3)    |
                         +-----------------+
```

### Common Backend Types

| Backend | Where State is Stored | Best For |
|---------|----------------------|----------|
| `local` | Your computer (`terraform.tfstate`) | Learning, personal projects |
| `s3` | AWS S3 bucket | Teams using AWS |
| `azurerm` | Azure Blob Storage | Teams using Azure |
| `gcs` | Google Cloud Storage | Teams using GCP |
| `remote` | Terraform Cloud | Enterprise teams |

---

## File Structure

```
scenario-4-backend-migration/
|-- main.tf                      # Resources (instance, security group)
|-- provider-localstack.tf       # LocalStack provider (default)
|-- provider-aws.tf.example      # Real AWS provider (rename to use)
|-- backend-a.tf                 # LocalStack Backend A (default)
|-- backend-b.tf.example         # LocalStack Backend B (rename to migrate)
|-- backend-a-aws.tf.example     # Real AWS Backend A (rename to use)
|-- backend-b-aws.tf.example     # Real AWS Backend B (rename to migrate)
|-- terraform.tfvars.aws.example # Variables for Real AWS
|-- create-buckets.sh            # Script to create S3 buckets
|-- create-buckets.ps1           # Windows version
+-- README.md                    # This file
```

---

## Option A: LocalStack (Free - Recommended for Learning)

### Prerequisites

- Docker installed
- AWS CLI installed

### Step 1: Start LocalStack

```bash
# From the repository root
docker-compose up -d

# Verify LocalStack is running
curl http://localhost:4566/_localstack/health
```

### Step 2: Create the S3 Buckets

```bash
cd scenario-4-backend-migration

# Make script executable (Linux/Mac)
chmod +x create-buckets.sh

# Run the script
./create-buckets.sh           # Linux/Mac
.\create-buckets.ps1          # Windows PowerShell
```

This creates:
- `tfstate-bucket-a` (source bucket)
- `tfstate-bucket-b` (target bucket)

### Step 3: Initialize with Backend A

```bash
terraform init
```

You should see:
```
Initializing the backend...
Successfully configured the backend "s3"!
```

### Step 4: Create Resources

```bash
terraform apply -auto-approve
```

### Step 5: Verify State is in Bucket A

```bash
aws s3 ls s3://tfstate-bucket-a/ --recursive --endpoint-url http://localhost:4566
```

Expected output:
```
2024-01-15 10:30:00       1234 scenario-4/terraform.tfstate
```

### Step 6: Switch Backend Configuration

```bash
# Disable Backend A
mv backend-a.tf backend-a.tf.bak

# Enable Backend B
mv backend-b.tf.example backend-b.tf
```

### Step 7: Migrate the State

```bash
terraform init -migrate-state
```

When prompted, type `yes` and press Enter.

### Step 8: Verify Migration

```bash
# Should show "No changes"
terraform plan

# Verify state is in Bucket B
aws s3 ls s3://tfstate-bucket-b/ --recursive --endpoint-url http://localhost:4566
```

---

## Option B: Real AWS

### Prerequisites

- AWS account with billing enabled
- AWS CLI installed and configured (`aws configure`)
- Permissions: S3, EC2

### Step 1: Verify AWS Credentials

```bash
aws sts get-caller-identity
```

### Step 2: Switch to AWS Provider

```bash
cd scenario-4-backend-migration

# Disable LocalStack provider
mv provider-localstack.tf provider-localstack.tf.bak

# Enable AWS provider
mv provider-aws.tf.example provider-aws.tf
```

### Step 3: Create the S3 Buckets

```bash
chmod +x create-buckets.sh
./create-buckets.sh aws
```

**Important:** Note the bucket names from the output! They include your account ID and timestamp for uniqueness.

Example output:
```
Source Bucket (A): tfstate-scenario4-a-123456789012-20240115103000
Target Bucket (B): tfstate-scenario4-b-123456789012-20240115103000
```

### Step 4: Configure Backend A

```bash
# Disable LocalStack backend
mv backend-a.tf backend-a-localstack.tf.bak

# Enable AWS backend
mv backend-a-aws.tf.example backend-a.tf
```

**Edit `backend-a.tf`** and replace `YOUR-BUCKET-A-NAME` with your actual bucket name:

```hcl
terraform {
  backend "s3" {
    bucket = "tfstate-scenario4-a-123456789012-20240115103000"  # Your bucket name
    key    = "scenario-4/terraform.tfstate"
    region = "us-east-1"
  }
}
```

### Step 5: Configure Variables

```bash
mv terraform.tfvars.aws.example terraform.tfvars
```

**Edit `terraform.tfvars`** and update the AMI ID for your region:

```hcl
use_localstack = false
ami_id = "ami-0c101f26f147fa7fd"  # Update for your region
```

To find the latest Amazon Linux AMI:
```bash
aws ec2 describe-images --owners amazon \
  --filters "Name=name,Values=al2023-ami-*-x86_64" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
  --output text
```

### Step 6: Initialize and Create Resources

```bash
terraform init
terraform apply -auto-approve
```

### Step 7: Verify State is in Bucket A

```bash
aws s3 ls s3://YOUR-BUCKET-A-NAME/ --recursive
```

### Step 8: Configure Backend B

**Edit `backend-b-aws.tf.example`** and replace `YOUR-BUCKET-B-NAME` with your actual bucket name.

```bash
# Disable Backend A
mv backend-a.tf backend-a.tf.bak

# Enable Backend B
mv backend-b-aws.tf.example backend-b.tf
```

### Step 9: Migrate the State

```bash
terraform init -migrate-state
```

When prompted, type `yes`.

### Step 10: Verify Migration

```bash
# Should show "No changes"
terraform plan

# Verify state is in Bucket B
aws s3 ls s3://YOUR-BUCKET-B-NAME/ --recursive
```

### Step 11: Clean Up (Important!)

```bash
# Destroy resources to avoid charges
terraform destroy -auto-approve

# Delete the S3 buckets
aws s3 rb s3://YOUR-BUCKET-A-NAME --force
aws s3 rb s3://YOUR-BUCKET-B-NAME --force
```

---

## What Happened Behind the Scenes?

When you ran `terraform init -migrate-state`:

1. Terraform read the state from Bucket A
2. Terraform wrote the state to Bucket B
3. Terraform updated `.terraform/terraform.tfstate` to point to Bucket B
4. Future operations now use Bucket B

```
terraform init -migrate-state

    +----------------+         +----------------+
    |   Bucket A     |  COPY   |   Bucket B     |
    |----------------|  ---->  |----------------|
    | tfstate file   |         | tfstate file   |
    +----------------+         +----------------+

    .terraform/terraform.tfstate now points to Bucket B
```

---

## Common Mistakes and Solutions

### Mistake 1: Both backend files active

**Error:**
```
Error: Duplicate backend configuration
```

**Solution:** Only ONE `backend` block can exist. Rename or delete the old one:
```bash
mv backend-a.tf backend-a.tf.bak
```

### Mistake 2: Forgetting -migrate-state flag

**Error:**
```
Error: Backend configuration changed
```

**Solution:** Use the `-migrate-state` flag:
```bash
terraform init -migrate-state
```

### Mistake 3: Answering "no" to migration prompt

**Result:** State stays in old bucket, new bucket is empty.

**Solution:** Re-run `terraform init -migrate-state` and answer "yes".

### Mistake 4: Mixing LocalStack and AWS configs

**Error:** Various connection errors

**Solution:** Make sure you're using matching configs:
- LocalStack: `provider-localstack.tf` + `backend-a.tf` (LocalStack version)
- Real AWS: `provider-aws.tf` + `backend-a.tf` (AWS version)

### Mistake 5: Wrong bucket name in backend config

**Error:**
```
Error: Failed to get existing workspaces: S3 bucket does not exist
```

**Solution:** Double-check bucket name matches exactly what `create-buckets.sh` created.

---

## Success Criteria

- [ ] Both S3 buckets created
- [ ] Resources created with Backend A
- [ ] State migrated to Backend B
- [ ] `terraform plan` shows "No changes"
- [ ] State file exists in Bucket B

---

## Key Concepts Summary

| Concept | Description |
|---------|-------------|
| **Backend** | Where Terraform stores state (local, S3, etc.) |
| **State file** | JSON file tracking managed resources |
| **Backend migration** | Moving state from one backend to another |
| **`-migrate-state`** | Flag that tells Terraform to copy existing state |

---

## Real-World Best Practices

### 1. Always Backup Before Migration

```bash
# Pull current state to a local backup
terraform state pull > state-backup-$(date +%Y%m%d).json
```

### 2. Enable Versioning on State Buckets

```bash
aws s3api put-bucket-versioning \
  --bucket my-state-bucket \
  --versioning-configuration Status=Enabled
```

### 3. Test in Non-Production First

Never migrate production state without testing the process first!

### 4. Coordinate with Your Team

- Announce the migration window
- Ensure no one else is running Terraform
- Use state locking (DynamoDB) to prevent conflicts

---

## Next Steps

After completing this scenario:
- Try [Scenario 5: State Recovery](../scenario-5-state-recovery/) to learn disaster recovery
- Explore using DynamoDB for state locking
