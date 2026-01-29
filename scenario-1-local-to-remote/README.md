# Scenario 1: Local to Remote State Migration

## What is This Scenario About?

**The Problem:** You've been using Terraform on your laptop, and everything works fine for you alone. But now your team needs to collaborate on the same infrastructure. The state file is trapped on your machine - no one else can access it. If two people run `terraform apply` at the same time with their own local state files, they could overwrite each other's changes or create duplicate resources.

**The Solution:** Move (migrate) the Terraform state from your local disk to a shared S3 bucket in AWS, so the entire team can safely work together.

**Real-World Example:** You joined a startup where the lead DevOps engineer had been managing all infrastructure from their laptop. Now the team has grown from 1 to 5 engineers. You need to move the state to a central location so everyone can collaborate without stepping on each other's toes.

---

## Learning Objectives

By completing this scenario, you will:

- [ ] Understand why local state is a problem for teams
- [ ] Know how to create an S3 bucket for remote state storage
- [ ] Be able to configure an S3 backend in Terraform
- [ ] Successfully migrate state from local to remote without destroying resources
- [ ] Verify that no infrastructure changes occurred during migration
- [ ] Understand what `terraform init -migrate-state` does behind the scenes

**After this scenario, you should be able to answer:**
- "What happens to the local state file after migration?"
- "Why do we need to run `terraform plan` after migrating?"
- "What is the `-migrate-state` flag and when would you use it?"

---

## Prerequisites

- Docker Desktop installed and running (for LocalStack) OR AWS account configured (for Real AWS)
- Terraform CLI installed (`terraform --version` to check)
- You are inside the `scenario-1-local-to-remote/` directory

---

## Step-by-Step Instructions

### Step 1: Create the S3 Bucket

Before we can store state remotely, we need an S3 bucket (a cloud storage container) to put it in.

```bash
# Make the script executable (gives it permission to run)
chmod +x create-bucket.sh

# Run the script to create an S3 bucket
./create-bucket.sh           # For LocalStack (default)
# OR
./create-bucket.sh aws       # For Real AWS
```

**What does `create-bucket.sh` do?**
- Creates an S3 bucket in AWS (or LocalStack) to store your state file
- Enables versioning so you can recover previous state versions
- Enables encryption so your state is secure at rest
- Outputs the bucket name you'll need in the next step

### Step 2: Check the Backend Configuration

Open `backend.tf` in your editor and look at it. Right now the S3 backend block is **commented out** (lines start with `#`). This means Terraform will use the **local** backend by default - storing state in a `terraform.tfstate` file on your disk.

```hcl
# This is what commented-out code looks like:
# terraform {
#   backend "s3" {
#     bucket = "terraform-state-migration-demo"
#     key    = "scenario-1/terraform.tfstate"
#     ...
#   }
# }
```

**Leave it commented out for now** - we want to start with local state first, then migrate.

### Step 3: Initialize Terraform with Local State

```bash
# Download the required providers and set up the local backend
terraform init
```

**What does `terraform init` do?**
- Downloads the AWS provider plugin (the code that knows how to talk to AWS)
- Sets up the backend (where state will be stored - local disk for now)
- Creates a `.terraform/` directory with provider binaries
- Creates a `.terraform.lock.hcl` file that locks provider versions

### Step 4: Create the Infrastructure

```bash
# Create the resources defined in main.tf
terraform apply -auto-approve
```

**What does `terraform apply -auto-approve` do?**
- Reads `main.tf` to see what resources should exist
- Compares with the state file (empty at this point)
- Creates the resources: a security group and an EC2 instance
- Updates the state file with the new resource IDs
- `-auto-approve` skips the "are you sure?" prompt (only use for learning!)

### Step 5: Verify Resources Were Created

```bash
# List all resources that Terraform is tracking
terraform state list
```

**What does `terraform state list` do?**
- Reads the state file and lists every resource Terraform knows about
- You should see: `aws_instance.web` and `aws_security_group.web`
- If you see these, it means the state file on your disk is tracking them

### Step 6: Enable the S3 Backend

Now comes the migration. Open `backend.tf` and **uncomment** the S3 backend block (remove the `#` from the beginning of each line). The result should look like:

```hcl
terraform {
  backend "s3" {
    bucket = "terraform-state-migration-demo"  # Your bucket name
    key    = "scenario-1/terraform.tfstate"    # State file path in bucket
    region = "us-east-1"

    # For LocalStack only - remove for real AWS
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

### Step 7: Migrate the State

```bash
# Tell Terraform to move state from local to S3
terraform init -migrate-state
```

**What does `terraform init -migrate-state` do?**
- Detects that the backend configuration has changed (from local to S3)
- Asks: "Do you want to copy existing state to the new backend?"
- When you answer **"yes"**: reads your local `terraform.tfstate`, uploads it to the S3 bucket, and updates Terraform's configuration to use S3 going forward
- Your local state file becomes obsolete (Terraform no longer reads it)

**Type `yes` when prompted** to confirm the migration.

### Step 8: Verify the Migration

```bash
# Check that no infrastructure changes are needed
terraform plan
```

**What does `terraform plan` do here?**
- Reads the state from S3 (not local anymore!)
- Compares state with your `main.tf` configuration
- Compares state with the real resources in AWS
- Should output: **"No changes. Your infrastructure matches the configuration."**

If you see "No changes" - **congratulations, the migration was successful!** The state is now in S3, and no resources were created, modified, or destroyed.

---

## Collecting Evidence

Save proof that you completed this scenario. Run these commands:

```bash
# Create the evidence directory if it doesn't exist
mkdir -p ../evidence

# Save the terraform plan output (proves "No changes" after migration)
terraform plan -no-color > ../evidence/scenario1-plan.txt

# Save the list of resources in state (proves resources are tracked)
terraform state list > ../evidence/scenario1-state.txt

# For LocalStack: Prove state is in S3
aws s3 ls s3://terraform-state-migration-demo/ --recursive --endpoint-url http://localhost:4566 > ../evidence/scenario1-s3-proof.txt

# For Real AWS: Prove state is in S3 (use your actual bucket name)
# aws s3 ls s3://YOUR-BUCKET-NAME/ --recursive > ../evidence/scenario1-s3-proof.txt
```

**What are these evidence commands doing?**
- `terraform plan -no-color > file.txt` - Runs plan and saves the output to a file. `-no-color` removes terminal color codes so the file is readable.
- `terraform state list > file.txt` - Lists all tracked resources and saves to a file.
- `aws s3 ls ... > file.txt` - Lists the contents of the S3 bucket to prove the state file is stored there.
- The `>` symbol redirects command output to a file instead of showing it on screen.

---

## Cleanup

When you're done with this scenario, destroy the resources to avoid charges (especially important for Real AWS!).

### For LocalStack:
```bash
# Destroy all resources managed by Terraform
terraform destroy -auto-approve
```

**What does `terraform destroy -auto-approve` do?**
- Reads the state file to find all tracked resources
- Deletes every resource from AWS (or LocalStack)
- Updates the state file to show no resources exist
- `-auto-approve` skips the confirmation prompt

### For Real AWS:
```bash
# Destroy all resources
terraform destroy -auto-approve

# Also delete the S3 bucket (Terraform doesn't manage the bucket itself)
# Use your actual bucket name from the create-bucket.sh output
aws s3 rb s3://YOUR-BUCKET-NAME --force
```

**What does `aws s3 rb` do?**
- `rb` stands for "remove bucket"
- `--force` deletes all objects in the bucket first, then deletes the bucket itself
- This is needed because Terraform doesn't manage the state bucket - you created it separately

---

## Self-Reflection Questions

After completing this scenario, take a few minutes to reflect:

1. **What was this scenario about?**
   - What real-world problem does local-to-remote state migration solve?
   - When would a company need to do this?

2. **What did I learn?**
   - What is the difference between local and remote state?
   - What command migrates state between backends?
   - What happens to the local state file after migration?

3. **Did I collect evidence?**
   - Did I save the `terraform plan` output showing "No changes"?
   - Did I save proof that the state is now in S3?

4. **Could I explain this to someone else?**
   - Could I walk a colleague through this migration without notes?
   - Could I answer this interview question: "How would you migrate Terraform state from local to S3?"

5. **What would be different in production?**
   - Would you use `-auto-approve` in production? (No!)
   - What safety measures would you add? (Backups, state locking with DynamoDB, encryption)
   - What could go wrong during migration?

**Write a brief report** in `../evidence/my-learning-report.md` documenting your answers.

---

## Success Criteria

- [ ] Resources created with local state (Step 4)
- [ ] S3 backend configured in `backend.tf` (Step 6)
- [ ] State successfully migrated to S3 (Step 7)
- [ ] `terraform plan` shows "No changes" (Step 8)
- [ ] Evidence files saved in `../evidence/` directory

---

## Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| "Backend configuration changed" | You changed backend.tf but didn't run init | Run `terraform init -migrate-state` |
| "Error copying state" | S3 bucket doesn't exist | Run `create-bucket.sh` first |
| "No changes" doesn't appear after migration | Something went wrong during copy | Check S3 bucket has state, try `terraform init -reconfigure` |
| "Access Denied" on S3 | Wrong bucket name or permissions | Verify bucket name matches exactly |
| "localhost:4566 connection refused" | LocalStack isn't running | Run `docker-compose up -d` from project root |
