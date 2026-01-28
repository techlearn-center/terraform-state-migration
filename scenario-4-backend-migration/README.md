# Scenario 4: Backend Migration

## The Scenario

Your company has decided to reorganize its Terraform state storage. You need to migrate state from one S3 bucket to another **without destroying or recreating any resources**.

**Your mission:** Safely migrate Terraform state between S3 backends with zero downtime.

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

## Your Task

### What You'll Do

1. Create two S3 buckets (A and B)
2. Initialize Terraform with Backend A
3. Create resources (state goes to Bucket A)
4. Migrate state from Bucket A to Bucket B
5. Verify: `terraform plan` shows "No changes"

### Visual Overview

```
BEFORE MIGRATION:
+------------------+                      +------------------+
|   Bucket A       |                      |   Bucket B       |
|   (Source)       |                      |   (Target)       |
+------------------+                      +------------------+
|                  |                      |                  |
| terraform.tfstate|                      |     (empty)      |
|                  |                      |                  |
+------------------+                      +------------------+
         ^
         |
    Terraform reads/writes here


AFTER MIGRATION:
+------------------+                      +------------------+
|   Bucket A       |                      |   Bucket B       |
|   (Source)       |                      |   (Target)       |
+------------------+                      +------------------+
|                  |                      |                  |
|     (empty)      |                      | terraform.tfstate|
|                  |                      |                  |
+------------------+                      +------------------+
                                                   ^
                                                   |
                                          Terraform reads/writes here
```

---

## Step-by-Step Instructions

### Step 1: Create the S3 Buckets

```bash
cd scenario-4-backend-migration

# Make script executable (Linux/Mac)
chmod +x create-buckets.sh

# Run the script
./create-buckets.sh           # LocalStack (default)
# OR
.\create-buckets.ps1          # Windows PowerShell
```

This creates:
- `tfstate-bucket-a` (source bucket)
- `tfstate-bucket-b` (target bucket)

### Step 2: Initialize with Backend A

```bash
# Initialize Terraform (uses backend-a.tf)
terraform init
```

You should see:
```
Initializing the backend...
Successfully configured the backend "s3"!
```

### Step 3: Create Resources

```bash
terraform apply -auto-approve
```

This creates an EC2 instance and security group. The **state is now in Bucket A**.

### Step 4: Verify State is in Bucket A

```bash
# LocalStack
aws s3 ls s3://tfstate-bucket-a/ --recursive --endpoint-url http://localhost:4566

# Real AWS
aws s3 ls s3://tfstate-bucket-a/ --recursive
```

Expected output:
```
2024-01-15 10:30:00       1234 scenario-4/terraform.tfstate
```

### Step 5: Switch Backend Configuration

```bash
# Rename backend-a.tf (disable it)
mv backend-a.tf backend-a.tf.bak

# Rename backend-b.tf.example to activate it
mv backend-b.tf.example backend-b.tf
```

**Important:** Only ONE backend configuration can be active at a time!

### Step 6: Migrate the State

```bash
terraform init -migrate-state
```

Terraform will ask:
```
Do you want to copy existing state to the new backend?
  Enter "yes" to copy and "no" to start fresh.

  Enter a value: yes
```

**Type `yes` and press Enter.**

You should see:
```
Successfully configured the backend "s3"!
```

### Step 7: Verify Migration Success

```bash
# Check that plan shows no changes
terraform plan
```

Expected output:
```
No changes. Your infrastructure matches the configuration.
```

```bash
# Verify state is now in Bucket B
aws s3 ls s3://tfstate-bucket-b/ --recursive --endpoint-url http://localhost:4566
```

Expected output:
```
2024-01-15 10:35:00       1234 scenario-4/terraform.tfstate
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

## File Structure Explained

```
scenario-4-backend-migration/
|-- main.tf                 # Your resources (instance, security group)
|-- backend-a.tf            # Backend config pointing to Bucket A
|-- backend-b.tf.example    # Backend config pointing to Bucket B (rename to use)
|-- create-buckets.sh       # Script to create both S3 buckets
|-- create-buckets.ps1      # Windows version
+-- README.md               # This file
```

### Understanding the Backend Files

**backend-a.tf** (Initial backend):
```hcl
terraform {
  backend "s3" {
    bucket = "tfstate-bucket-a"
    key    = "scenario-4/terraform.tfstate"
    region = "us-east-1"
  }
}
```

**backend-b.tf** (Target backend):
```hcl
terraform {
  backend "s3" {
    bucket = "tfstate-bucket-b"    # Different bucket!
    key    = "scenario-4/terraform.tfstate"
    region = "us-east-1"
  }
}
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

### Mistake 4: Not verifying with terraform plan

Always run `terraform plan` after migration to confirm:
- State was migrated correctly
- No resources will be changed/destroyed

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
