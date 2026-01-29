# Scenario 4: Backend Migration (Switching Between Backends)

## What is This Scenario About?

**The Problem:** Your company stores Terraform state in S3 bucket "A". Due to a compliance requirement (or a company restructuring, or a region change), you need to move the state to a different S3 bucket "B". The infrastructure must remain untouched - you're only changing WHERE the state file is stored.

**The Solution:** Use `terraform init -migrate-state` to move the state from one S3 backend to another. This is similar to Scenario 1 (local to remote), but this time you're migrating between two remote backends.

**Real-World Example:** Your company was acquired, and the new parent company requires all Terraform state to be stored in their centralized S3 bucket in a different AWS account. You need to migrate state from the old bucket to the new one without any infrastructure downtime.

---

## Learning Objectives

By completing this scenario, you will:

- [ ] Understand that backends can be changed without affecting infrastructure
- [ ] Know how to configure multiple S3 backend configurations
- [ ] Be able to switch between backend configurations by renaming files
- [ ] Successfully migrate state between two different S3 buckets
- [ ] Verify state exists in the target bucket after migration

**After this scenario, you should be able to answer:**
- "How do you migrate state between two S3 buckets?"
- "What happens to the state in the original bucket after migration?"
- "What's the difference between `-migrate-state` and `-reconfigure`?"

---

## Prerequisites

- Docker Desktop running (for LocalStack) OR AWS account configured (for Real AWS)
- Terraform CLI installed
- You are inside the `scenario-4-backend-migration/` directory

---

## Understanding the File Structure

```
scenario-4-backend-migration/
├── main.tf                # Terraform resources (EC2 instance + security group)
├── backend-a.tf           # Backend config pointing to S3 Bucket A (active)
├── backend-b.tf.example   # Backend config pointing to S3 Bucket B (inactive)
├── create-buckets.sh      # Script to create both S3 buckets
└── create-buckets.ps1     # PowerShell version for Windows
```

**The key idea:** Terraform can only use ONE backend at a time. By renaming files, you switch which backend is active:
- `backend-a.tf` (active) + `backend-b.tf.example` (ignored) = Using Bucket A
- `backend-a.tf.bak` (ignored) + `backend-b.tf` (active) = Using Bucket B

Terraform only reads files ending in `.tf` - anything else (`.example`, `.bak`) is ignored.

---

## Step-by-Step Instructions

### Step 1: Navigate to the Scenario Directory

```bash
cd scenario-4-backend-migration
```

### Step 2: Create Both S3 Buckets

```bash
# Make the script executable
chmod +x create-buckets.sh

# Create both S3 buckets
./create-buckets.sh           # For LocalStack (default)
# OR
./create-buckets.sh aws       # For Real AWS
```

**What does `create-buckets.sh` do?**
- Creates TWO S3 buckets: one called "Bucket A" (the source) and one called "Bucket B" (the destination)
- For LocalStack, the bucket names are `tfstate-bucket-a` and `tfstate-bucket-b`
- For Real AWS, it generates unique bucket names (since S3 bucket names must be globally unique)
- Enables versioning and encryption on both buckets
- Outputs the bucket names - **save these if using Real AWS!**

### Step 3: Initialize with Backend A

```bash
# Initialize Terraform using Backend A (the current active backend)
terraform init
```

**What does `terraform init` do here?**
- Reads `backend-a.tf` to find the backend configuration
- Connects to S3 Bucket A
- Creates or downloads the state file from Bucket A
- Since this is the first run, the state is empty

### Step 4: Create Resources

```bash
# Create the resources defined in main.tf
terraform apply -auto-approve
```

**What does this create?**
- An EC2 instance (`aws_instance.app`) and a security group (`aws_security_group.app`)
- The state file is stored in S3 Bucket A
- This simulates your existing infrastructure before the migration

### Step 5: Verify State is in Bucket A

```bash
# For LocalStack: List contents of Bucket A
aws s3 ls s3://tfstate-bucket-a/ --recursive --endpoint-url http://localhost:4566

# For Real AWS: (use your actual bucket name)
# aws s3 ls s3://YOUR-BUCKET-A/ --recursive
```

**What does `aws s3 ls` do?**
- Lists all files in the S3 bucket
- `--recursive` shows files in all subdirectories
- You should see a file like `scenario-4/terraform.tfstate` - that's your state!
- `--endpoint-url` tells the AWS CLI to talk to LocalStack instead of real AWS

### Step 6: Switch Backend Configuration

```bash
# Rename backend-a.tf to disable it (Terraform ignores non-.tf files)
mv backend-a.tf backend-a.tf.bak

# Rename backend-b.tf.example to activate it
mv backend-b.tf.example backend-b.tf
```

**What do these `mv` (move/rename) commands do?**
- `mv backend-a.tf backend-a.tf.bak` - Renames the file so it no longer ends in `.tf`. Terraform won't read it anymore.
- `mv backend-b.tf.example backend-b.tf` - Renames the file so it ends in `.tf`. Terraform will now read this as the backend configuration.
- After this, Terraform thinks the backend is Bucket B (but the state is still in Bucket A!)

### Step 7: Migrate State to Backend B

```bash
# Migrate the state from Bucket A to Bucket B
terraform init -migrate-state
```

**What does `terraform init -migrate-state` do?**
- Detects that the backend configuration has changed (from Bucket A to Bucket B)
- Asks: "Do you want to copy existing state to the new backend?"
- When you answer **"yes"**:
  1. Downloads the state from Bucket A
  2. Uploads it to Bucket B
  3. Updates Terraform's internal tracking to use Bucket B
- The state in Bucket A is NOT deleted (it remains as a backup)

**Type `yes` when prompted.**

### Step 8: Verify the Migration

```bash
# Check that no infrastructure changes are needed
terraform plan
# Should show: "No changes"

# For LocalStack: Verify state is now in Bucket B
aws s3 ls s3://tfstate-bucket-b/ --recursive --endpoint-url http://localhost:4566

# For Real AWS: (use your actual bucket name)
# aws s3 ls s3://YOUR-BUCKET-B/ --recursive
```

**What are we verifying?**
- `terraform plan` showing "No changes" proves the migration was seamless - infrastructure is untouched
- `aws s3 ls` on Bucket B proves the state file is in the new location

---

## Collecting Evidence

Save proof that you completed this scenario:

```bash
# Create the evidence directory if it doesn't exist
mkdir -p ../evidence

# Save the terraform plan output (proves "No changes" after migration)
terraform plan -no-color > ../evidence/scenario4-plan.txt

# Save the state list (proves resources are tracked)
terraform state list > ../evidence/scenario4-state.txt

# For LocalStack: Prove state is in Bucket B
aws s3 ls s3://tfstate-bucket-b/ --recursive --endpoint-url http://localhost:4566 > ../evidence/scenario4-bucket-b.txt

# For Real AWS: (use your actual bucket name)
# aws s3 ls s3://YOUR-BUCKET-B/ --recursive > ../evidence/scenario4-bucket-b.txt
```

**What are these evidence commands doing?**
- Saves plan output proving infrastructure was not affected by the migration
- Saves state list proving resources are still tracked
- Saves S3 listing proving state is in the new bucket (Bucket B)

---

## Cleanup

### For LocalStack:
```bash
# Destroy all resources
terraform destroy -auto-approve
```

### For Real AWS:
```bash
# Destroy all resources
terraform destroy -auto-approve

# Delete BOTH S3 buckets (use your actual bucket names)
aws s3 rb s3://YOUR-BUCKET-A --force
aws s3 rb s3://YOUR-BUCKET-B --force
```

**Why delete both buckets?**
- Bucket A still has the old state file (it wasn't deleted during migration)
- Bucket B has the current state file
- S3 buckets incur storage costs even if small
- `--force` empties the bucket before deleting it

---

## Self-Reflection Questions

After completing this scenario, take a few minutes to reflect:

1. **What was this scenario about?**
   - Why would a company need to migrate state between two S3 buckets?
   - What real-world events trigger backend migrations?

2. **What did I learn?**
   - How does Terraform know which backend to use? (It reads `.tf` files)
   - What is the difference between `-migrate-state` and `-reconfigure`?
     - `-migrate-state`: Copies state from old backend to new backend
     - `-reconfigure`: Starts fresh with the new backend (doesn't copy state!)
   - What happens to the state in the old bucket after migration?

3. **Did I collect evidence?**
   - Did I save the plan output showing "No changes"?
   - Did I prove the state file exists in Bucket B?

4. **Could I do this again without instructions?**
   - What are the steps? (Create new bucket, update backend config, init -migrate-state, verify plan)
   - Could you migrate from S3 to Azure Blob Storage? (Same concept, different backend type)

5. **What would be different in production?**
   - Would you coordinate with the team before changing the backend?
   - What happens if someone runs `terraform apply` during the migration?
   - Should you enable state locking on both buckets?

**Write a brief report** in `../evidence/my-learning-report.md` documenting your answers.

---

## Success Criteria

- [ ] Both S3 buckets created (Step 2)
- [ ] Resources created with state in Bucket A (Step 4)
- [ ] State verified in Bucket A (Step 5)
- [ ] Backend configuration switched to Bucket B (Step 6)
- [ ] State migrated to Bucket B (Step 7)
- [ ] `terraform plan` shows "No changes" (Step 8)
- [ ] State verified in Bucket B (Step 8)
- [ ] Evidence files saved in `../evidence/` directory

---

## Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| "Backend configuration changed" | Terraform detected the switch but you didn't run init | Run `terraform init -migrate-state` |
| "Error copying state" | Target bucket doesn't exist | Run `create-buckets.sh` first |
| "Two backend blocks found" | Both .tf files are active | Make sure only ONE backend file ends in `.tf` |
| "No state file found" in new bucket | Migration didn't complete | Re-run `terraform init -migrate-state` and answer "yes" |
| "localhost:4566 connection refused" | LocalStack isn't running | Run `docker-compose up -d` from project root |
