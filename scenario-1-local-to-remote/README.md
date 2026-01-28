# Scenario 1: Local to Remote State Migration

## The Scenario

Your team started using Terraform with local state files stored on individual developer machines. As the team grows, you need to migrate to remote state (S3) for collaboration and safety.

**Your mission:** Migrate Terraform state from local storage to an S3 backend without destroying any resources.

---

## Choose Your Mode

| Mode | Best For | Cost | Requirements |
|------|----------|------|--------------|
| **LocalStack** (Default) | Learning, practice | Free | Docker installed |
| **Real AWS** | Real-world experience | ~$0.01/month | AWS account + credentials |

---

## Why This Matters

### Problems with Local State

```
LOCAL STATE (The Problem):
==========================

Developer A's Machine          Developer B's Machine
+--------------------+         +--------------------+
| terraform.tfstate  |         | terraform.tfstate  |
| (version 1)        |         | (version 2)        |
+--------------------+         +--------------------+
         |                              |
         v                              v
    +------------------------------------------+
    |              AWS Resources               |
    |                (shared)                  |
    +------------------------------------------+

Problems:
- No single source of truth
- Developers overwrite each other's changes
- State can be lost if laptop crashes
- No locking - concurrent runs cause corruption
- Secrets in state file stored locally
```

### Benefits of Remote State

```
REMOTE STATE (The Solution):
============================

Developer A                    Developer B
     |                              |
     v                              v
+------------------------------------------+
|              S3 Bucket                   |
|          terraform.tfstate               |
|    (Single Source of Truth)              |
+------------------------------------------+
                    |
                    v
+------------------------------------------+
|              AWS Resources               |
+------------------------------------------+

Benefits:
- Single source of truth
- Team collaboration
- State locking (with DynamoDB)
- Versioning and backup
- Encryption at rest
```

---

## Understanding the Migration

### What Happens During Migration

```
BEFORE (Local State):
====================

Your Machine
+-------------------+
| scenario-1/       |
| +---------------+ |
| |terraform.tfstate| <-- State stored locally
| +---------------+ |
| | main.tf       | |
| +---------------+ |
+-------------------+


AFTER (Remote State):
====================

Your Machine                           S3 Bucket
+-------------------+                  +-------------------+
| scenario-1/       |                  | tfstate-bucket/   |
| +---------------+ |  references      | +---------------+ |
| | .terraform/   |-------------------->| terraform.tfstate |
| +---------------+ |                  | +---------------+ |
| | main.tf       | |                  +-------------------+
| +---------------+ |
+-------------------+

The migration:
1. Copies state from local to S3
2. Configures Terraform to use S3 backend
3. Local state file is no longer used
```

---

## File Structure

```
scenario-1-local-to-remote/
|-- main.tf                      # Resources (EC2, Security Group)
|-- backend.tf                   # Backend config (uncomment to migrate)
|-- provider-localstack.tf       # LocalStack provider (default)
|-- provider-aws.tf.example      # Real AWS provider (rename to use)
|-- backend-aws.tf.example       # Real AWS backend config
|-- create-bucket.sh             # Creates S3 bucket for state
|-- create-bucket.ps1            # Windows version
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

### Step 2: Initialize with Local State

```bash
cd scenario-1-local-to-remote

terraform init
terraform apply -auto-approve
```

This creates resources with **local state**. Check:
```bash
ls -la terraform.tfstate
# You should see the local state file
```

### Step 3: Create the S3 Bucket

```bash
chmod +x create-bucket.sh
./create-bucket.sh
```

### Step 4: Configure the S3 Backend

Edit `backend.tf` and **uncomment** the backend block:

```hcl
terraform {
  backend "s3" {
    bucket = "terraform-state-migration-demo"
    key    = "scenario-1/terraform.tfstate"
    region = "us-east-1"

    # LocalStack settings
    endpoints = {
      s3 = "http://localhost:4566"
    }
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    use_path_style              = true
    access_key                  = "test"
    secret_key                  = "test"
  }
}
```

### Step 5: Migrate the State

```bash
terraform init -migrate-state
```

When prompted:
```
Do you want to copy existing state to the new backend?
  Enter "yes" to copy and "no" to start fresh.

  Enter a value: yes
```

### Step 6: Verify Migration

```bash
# Should show "No changes"
terraform plan

# Check state in S3
aws s3 ls s3://terraform-state-migration-demo/ --recursive --endpoint-url http://localhost:4566
```

Expected output:
```
scenario-1/terraform.tfstate
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
cd scenario-1-local-to-remote

# Disable LocalStack provider
mv provider-localstack.tf provider-localstack.tf.bak

# Enable AWS provider
mv provider-aws.tf.example provider-aws.tf
```

### Step 3: Initialize with Local State

```bash
terraform init
terraform apply -auto-approve
```

### Step 4: Create the S3 Bucket

```bash
chmod +x create-bucket.sh
./create-bucket.sh aws
```

**Important:** Note the bucket name from the output! It includes your account ID for uniqueness.

Example output:
```
Bucket: s3://tfstate-scenario1-123456789012-20240115103000

IMPORTANT: Update backend.tf with this S3 backend configuration:

terraform {
  backend "s3" {
    bucket  = "tfstate-scenario1-123456789012-20240115103000"
    key     = "scenario-1/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
```

### Step 5: Configure the S3 Backend

You can either:

**Option A:** Edit `backend.tf` and replace the LocalStack config with the Real AWS config from the script output.

**Option B:** Use the pre-made AWS backend file:
```bash
# Remove LocalStack backend
rm backend.tf

# Use AWS backend template
mv backend-aws.tf.example backend.tf

# Edit backend.tf and add your bucket name
```

Your `backend.tf` should look like:
```hcl
terraform {
  backend "s3" {
    bucket  = "tfstate-scenario1-123456789012-20240115103000"  # Your bucket
    key     = "scenario-1/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
```

### Step 6: Migrate the State

```bash
terraform init -migrate-state
```

Answer `yes` when prompted.

### Step 7: Verify Migration

```bash
# Should show "No changes"
terraform plan

# Check state in S3
aws s3 ls s3://YOUR-BUCKET-NAME/ --recursive
```

### Step 8: Clean Up (Important!)

```bash
# Destroy resources to avoid charges
terraform destroy -auto-approve

# Delete the S3 bucket
aws s3 rb s3://YOUR-BUCKET-NAME --force
```

---

## What Happened Behind the Scenes?

When you ran `terraform init -migrate-state`:

1. **Read local state:** Terraform read `terraform.tfstate` from disk
2. **Uploaded to S3:** State was uploaded to the S3 bucket
3. **Updated config:** `.terraform/terraform.tfstate` now points to S3
4. **Local state obsolete:** The local `terraform.tfstate` file is no longer used

```
terraform init -migrate-state

    +-------------------+         +-------------------+
    | Local State       |  COPY   | S3 Bucket         |
    | terraform.tfstate | ------> | terraform.tfstate |
    +-------------------+         +-------------------+
                                           ^
                                           |
                                  Future operations
                                  read/write here
```

---

## Common Mistakes and Solutions

### Mistake 1: Forgetting -migrate-state flag

**Error:**
```
Error: Backend configuration changed
```

**Solution:**
```bash
terraform init -migrate-state
```

### Mistake 2: Bucket doesn't exist

**Error:**
```
Error: Failed to get existing workspaces: S3 bucket does not exist
```

**Solution:** Run `create-bucket.sh` first, then update `backend.tf` with the correct bucket name.

### Mistake 3: Running init before apply

If you configure the backend before creating any resources, there's nothing to migrate. The workflow should be:

1. `terraform init` (local)
2. `terraform apply` (creates resources with local state)
3. Configure backend
4. `terraform init -migrate-state` (migrates existing state)

### Mistake 4: Mixing LocalStack and AWS configs

Make sure your provider and backend both point to the same target:
- LocalStack: `provider-localstack.tf` + LocalStack backend settings
- Real AWS: `provider-aws.tf` + clean S3 backend (no LocalStack settings)

---

## Success Criteria

- [ ] Resources created with local state
- [ ] S3 bucket created for remote state
- [ ] State migrated to S3
- [ ] `terraform plan` shows "No changes"
- [ ] Local `terraform.tfstate` is no longer the source of truth

---

## Key Concepts Summary

| Concept | Description |
|---------|-------------|
| **Local state** | `terraform.tfstate` stored on your machine |
| **Remote state** | State stored in S3, Terraform Cloud, etc. |
| **Backend** | Configuration that tells Terraform where to store state |
| **`-migrate-state`** | Flag that copies existing state to new backend |

---

## Real-World Best Practices

### 1. Enable Versioning

```bash
aws s3api put-bucket-versioning \
  --bucket my-state-bucket \
  --versioning-configuration Status=Enabled
```

### 2. Enable Encryption

```hcl
terraform {
  backend "s3" {
    bucket  = "my-state-bucket"
    key     = "terraform.tfstate"
    region  = "us-east-1"
    encrypt = true  # Enable encryption
  }
}
```

### 3. Add State Locking (DynamoDB)

```hcl
terraform {
  backend "s3" {
    bucket         = "my-state-bucket"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"  # Prevents concurrent modifications
  }
}
```

### 4. Block Public Access

The `create-bucket.sh` script automatically blocks public access for Real AWS.

---

## Next Steps

After completing this scenario:
- Try [Scenario 2: Import Existing Resources](../scenario-2-import/)
- Learn about state locking with DynamoDB
