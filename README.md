# Terraform State Migration

## Master State Management, Migration, and Import

Welcome to the **Terraform State Migration Challenge**! In real-world DevOps, you'll often need to migrate Terraform state between backends, import existing resources, and manage state across teams. This challenge teaches you essential state management skills.

You'll learn how to:

- Understand Terraform state structure
- Migrate state from local to remote (S3)
- Import existing AWS resources into Terraform
- Move resources between state files
- Handle state locking and recovery
- Split and merge Terraform configurations

---

## 🚀 Quick Start

> **GitHub Account Required** for grading and submission (Options A & B).
> Don't have one? [Create a free GitHub account](https://github.com/signup) - it's free and essential for any DevOps career!
>
> Option C works without GitHub but you won't get automated grading.

### Step 1: Get the Code

**Option A: Fork (Easiest)**
```bash
# 1. Click "Fork" button on GitHub (top right of this page)
# 2. Clone YOUR fork:
git clone https://github.com/YOUR-USERNAME/terraform-state-migration.git
cd terraform-state-migration
```

**Option B: Clone & Create Your Own Repo**
```bash
# 1. Clone this repo
git clone https://github.com/techlearn-center/terraform-state-migration.git
cd terraform-state-migration

# 2. Remove the original remote
git remote remove origin

# 3. Create a new repo on GitHub (github.com/new)
# 4. Add your new repo as origin
git remote add origin https://github.com/YOUR-USERNAME/YOUR-REPO-NAME.git
git push -u origin main
```

**Option C: Clone Only (Practice, No Grading)**
```bash
git clone https://github.com/techlearn-center/terraform-state-migration.git
cd terraform-state-migration
# Note: You won't be able to push or get GitHub Actions grading
```

### Step 2: Choose Your Path

| Path | Best For | Requirements |
|------|----------|--------------|
| **LocalStack** | Learning, no cost | Docker, Terraform |
| **Real AWS** | Production experience | AWS account, Terraform |

### Step 3: Complete the Tasks

```bash
# For LocalStack:
docker-compose up -d
cd scenario-1-local-to-remote
terraform init

# For Real AWS:
aws configure
cd scenario-1-local-to-remote
terraform init
```

### Step 4: Check Your Progress

```bash
python run.py                 # Local progress checker
```

### Step 5: Submit Your Work

```bash
git add .
git commit -m "Complete terraform-state-migration challenge"
git push origin main
# Check GitHub Actions for your grade!
```

---

## 📚 Table of Contents

1. [Why State Migration?](#why-state-migration)
2. [Understanding State Structure](#understanding-state-structure)
3. [State Commands Deep Dive](#state-commands-deep-dive)
4. [Migration Scenarios](#migration-scenarios)
5. [Prerequisites](#prerequisites)
6. [Challenge Overview](#challenge-overview)
7. [Tasks](#tasks)
8. [Troubleshooting](#troubleshooting)

---

## Why State Migration?

### Real-World Scenarios

```
┌─────────────────────────────────────────────────────────────────┐
│                    WHEN YOU NEED STATE MIGRATION                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  📁 Scenario 1: Local to Remote                                 │
│  ─────────────────────────────────                              │
│  You started with local state on your laptop.                   │
│  Now the team needs to collaborate.                             │
│  → Migrate to S3 backend                                        │
│                                                                 │
│  🏢 Scenario 2: Import Existing Resources                       │
│  ──────────────────────────────────────────                     │
│  Someone created resources manually in AWS Console.             │
│  Now you need Terraform to manage them.                         │
│  → Import into Terraform state                                  │
│                                                                 │
│  🔀 Scenario 3: Splitting Configurations                        │
│  ────────────────────────────────────────                       │
│  Your Terraform grew too large.                                 │
│  Need to split into modules or separate states.                 │
│  → Move resources between states                                │
│                                                                 │
│  🔄 Scenario 4: Backend Migration                               │
│  ─────────────────────────────────                              │
│  Company switching from Terraform Cloud to S3.                  │
│  Or from one S3 bucket to another.                              │
│  → Migrate between backends                                     │
│                                                                 │
│  🆘 Scenario 5: State Recovery                                  │
│  ─────────────────────────────                                  │
│  State file corrupted or lost.                                  │
│  Need to rebuild state from existing resources.                 │
│  → Import and reconstruct state                                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### The Cost of Getting It Wrong

```
┌─────────────────────────────────────────────────────────────────┐
│                    ⚠️ STATE MIGRATION RISKS                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ❌ Wrong: terraform destroy + terraform apply                  │
│     • Destroys production resources!                            │
│     • Causes downtime                                           │
│     • May lose data                                             │
│                                                                 │
│  ❌ Wrong: Manually editing state file                          │
│     • Corrupts state                                            │
│     • Creates drift                                             │
│     • Breaks future operations                                  │
│                                                                 │
│  ✅ Right: Use Terraform state commands                         │
│     • terraform state mv                                        │
│     • terraform state rm                                        │
│     • terraform import                                          │
│     • terraform state pull/push                                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Understanding State Structure

### What's in a State File?

```json
{
  "version": 4,
  "terraform_version": "1.5.0",
  "serial": 42,
  "lineage": "abc123-def456-...",
  "outputs": {
    "instance_ip": {
      "value": "54.123.45.67",
      "type": "string"
    }
  },
  "resources": [
    {
      "mode": "managed",
      "type": "aws_instance",
      "name": "web",
      "provider": "provider[\"registry.terraform.io/hashicorp/aws\"]",
      "instances": [
        {
          "schema_version": 1,
          "attributes": {
            "id": "i-0abc123def456",
            "ami": "ami-12345678",
            "instance_type": "t2.micro"
          }
        }
      ]
    }
  ]
}
```

### State File Components

```
┌─────────────────────────────────────────────────────────────────┐
│                    STATE FILE STRUCTURE                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  version           → State format version (currently 4)         │
│  terraform_version → Terraform version that wrote state         │
│  serial            → Increments on every change                 │
│  lineage           → Unique ID for this state (never changes)   │
│  outputs           → Output values from configuration           │
│  resources         → All managed resources                      │
│                                                                 │
│  Resource Addressing:                                           │
│  ──────────────────                                             │
│  aws_instance.web              → Single resource                │
│  aws_instance.web[0]           → Resource with count            │
│  aws_instance.web["key"]       → Resource with for_each         │
│  module.app.aws_instance.web   → Resource in module             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## State Commands Deep Dive

### Essential State Commands

```bash
# List all resources in state
terraform state list
# Output:
# aws_instance.web
# aws_security_group.main
# aws_vpc.main

# Show details of a specific resource
terraform state show aws_instance.web
# Output:
# resource "aws_instance" "web" {
#     ami                    = "ami-12345678"
#     instance_type          = "t2.micro"
#     ...
# }

# Move/rename a resource
terraform state mv aws_instance.web aws_instance.web_server
# Moved aws_instance.web to aws_instance.web_server

# Remove a resource from state (doesn't destroy it!)
terraform state rm aws_instance.web
# Removed aws_instance.web
# The resource still exists in AWS, just not managed by TF

# Import existing resource into state
terraform import aws_instance.web i-0abc123def456
# aws_instance.web: Importing...
# aws_instance.web: Import successful!

# Pull state to local file
terraform state pull > state.json

# Push local state file (DANGEROUS!)
terraform state push state.json
```

### State Migration Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│              LOCAL TO REMOTE MIGRATION WORKFLOW                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Step 1: Backup current state                                   │
│  ────────────────────────────                                   │
│  $ cp terraform.tfstate terraform.tfstate.backup                │
│                                                                 │
│  Step 2: Create remote backend (S3 bucket)                      │
│  ────────────────────────────────────────────                   │
│  $ aws s3 mb s3://my-terraform-state-bucket                     │
│                                                                 │
│  Step 3: Add backend configuration                              │
│  ───────────────────────────────────                            │
│  terraform {                                                    │
│    backend "s3" {                                               │
│      bucket = "my-terraform-state-bucket"                       │
│      key    = "terraform.tfstate"                               │
│      region = "us-east-1"                                       │
│    }                                                            │
│  }                                                              │
│                                                                 │
│  Step 4: Initialize with migration                              │
│  ────────────────────────────────────                           │
│  $ terraform init -migrate-state                                │
│                                                                 │
│  Terraform will ask:                                            │
│  "Do you want to copy existing state to the new backend?"       │
│  Answer: yes                                                    │
│                                                                 │
│  Step 5: Verify                                                 │
│  ─────────────                                                  │
│  $ terraform state list                                         │
│  $ terraform plan  # Should show no changes                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Import Workflow

### Importing Existing Resources

```
┌─────────────────────────────────────────────────────────────────┐
│                    IMPORT WORKFLOW                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Step 1: Write the resource configuration                       │
│  ────────────────────────────────────────                       │
│  # In main.tf                                                   │
│  resource "aws_instance" "imported" {                           │
│    # Start with minimal config                                  │
│  }                                                              │
│                                                                 │
│  Step 2: Import the resource                                    │
│  ─────────────────────────────                                  │
│  $ terraform import aws_instance.imported i-0abc123def456       │
│                                                                 │
│  Step 3: Show the imported state                                │
│  ──────────────────────────────────                             │
│  $ terraform state show aws_instance.imported                   │
│                                                                 │
│  Step 4: Update configuration to match                          │
│  ─────────────────────────────────────                          │
│  # Copy attributes from state show to main.tf                   │
│  resource "aws_instance" "imported" {                           │
│    ami           = "ami-12345678"                               │
│    instance_type = "t2.micro"                                   │
│    # ... other attributes                                       │
│  }                                                              │
│                                                                 │
│  Step 5: Verify no changes                                      │
│  ─────────────────────────                                      │
│  $ terraform plan                                               │
│  # Should show "No changes"                                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Import Block (Terraform 1.5+)

```hcl
# New way: import block (Terraform 1.5+)
import {
  to = aws_instance.imported
  id = "i-0abc123def456"
}

resource "aws_instance" "imported" {
  # Configuration here
}

# Run: terraform plan -generate-config-out=generated.tf
# This generates the configuration automatically!
```

---

## Prerequisites

### For LocalStack (Free, Local)
- ✅ Docker and Docker Compose installed
- ✅ Terraform CLI installed (v1.5+)
- ✅ Python 3 (for run.py)
- ❌ No AWS account needed

### For Real AWS
- ✅ AWS Account ([Sign up free](https://aws.amazon.com/free/))
- ✅ AWS CLI installed and configured
- ✅ Terraform CLI installed (v1.5+)
- ❌ Docker NOT required

### Helpful Background
- 📖 Completed [terraform-basics](https://github.com/techlearn-center/terraform-basics)
- 📖 Completed [terraform-remote-state](https://github.com/techlearn-center/terraform-remote-state)
- 📖 Completed [terraform-workspaces](https://github.com/techlearn-center/terraform-workspaces)

---

## Challenge Overview

### Scenarios

```
terraform-state-migration/
├── docker-compose.yml           # LocalStack
├── README.md                    # This file
├── run.py                       # Progress checker
│
├── scenario-1-local-to-remote/  # Migrate local state to S3
│   ├── main.tf                  # Resources (provided)
│   ├── backend.tf               # Backend config (TODO)
│   └── migrate.sh               # Migration script (TODO)
│
├── scenario-2-import/           # Import existing resources
│   ├── main.tf                  # Resource to import (TODO)
│   ├── import.sh                # Import script (TODO)
│   └── setup.sh                 # Creates resource to import
│
├── scenario-3-move/             # Move resources between states
│   ├── old-project/             # Original project
│   └── new-project/             # Move resources here
│
└── solutions/                   # Complete solutions
```

---

## Tasks

---

### Task 1: Local to Remote State Migration (Detailed Walkthrough)

Migrate an existing local state file to an S3 backend.

**Directory:** `scenario-1-local-to-remote/`

**Objective:** You have a project with local state. Migrate it to S3.

#### Step 1: Start LocalStack and Navigate to Scenario

```bash
# Start LocalStack (from project root)
docker-compose up -d

# Verify LocalStack is running
docker-compose ps

# Navigate to scenario 1
cd scenario-1-local-to-remote
```

#### Step 2: Create the S3 Bucket for State Storage

```bash
# Run the bucket creation script
chmod +x create-bucket.sh
./create-bucket.sh

# Or manually create the bucket:
aws s3 mb s3://terraform-state-migration-demo --endpoint-url http://localhost:4566
```

#### Step 3: Initialize with LOCAL State First (Important!)

The backend block in `backend.tf` should be **commented out** initially.

```bash
# Verify backend.tf has the S3 backend COMMENTED OUT
cat backend.tf

# Initialize Terraform (uses local state)
terraform init
```

#### Step 4: Create Resources with Local State

```bash
# Apply to create resources (state stored LOCALLY in terraform.tfstate)
terraform apply -auto-approve

# Verify resources were created
terraform state list
# Should show:
# aws_instance.web
# aws_security_group.web

# Verify local state file exists
ls -la terraform.tfstate
```

#### Step 5: Uncomment the S3 Backend

Edit `backend.tf` and **uncomment** the entire terraform block:

```hcl
terraform {
  backend "s3" {
    bucket = "terraform-state-migration-demo"
    key    = "scenario-1/terraform.tfstate"
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

#### Step 6: Migrate State from Local to S3

```bash
# Run migration
terraform init -migrate-state

# When prompted: "Do you want to copy existing state to the new backend?"
# Type: yes
```

#### Step 7: Verify Migration Was Successful

```bash
# This should show "No changes" - proving state migrated correctly
terraform plan

# Verify state is now in S3
aws s3 ls s3://terraform-state-migration-demo/scenario-1/ --endpoint-url http://localhost:4566
# Should show: terraform.tfstate

# The local terraform.tfstate should now be empty or gone
cat terraform.tfstate  # Should show empty or minimal content
```

#### Success Criteria
- ✅ `terraform plan` shows "No changes"
- ✅ State file exists in S3 bucket
- ✅ Resources still exist and are managed

---

### Task 2: Import Existing Resources (Detailed Walkthrough)

Import manually-created AWS resources into Terraform.

**Directory:** `scenario-2-import/`

**Objective:** A resource was created manually (via AWS Console). Import it into Terraform.

#### Step 1: Navigate to Scenario 2

```bash
cd ../scenario-2-import
```

#### Step 2: Create a Resource "Manually" (Simulating AWS Console)

```bash
# This script creates an EC2 instance outside of Terraform
chmod +x setup.sh
./setup.sh

# Note the Instance ID from the output! Example: i-abc123def456
# Save it - you'll need it for the import command
```

#### Step 3: Initialize Terraform

```bash
terraform init
```

#### Step 4: Write the Resource Configuration

Edit `main.tf` and add a resource block for the instance you want to import:

```hcl
# Add this resource block to main.tf
resource "aws_instance" "imported" {
  # Leave empty for now - we'll fill it after import
}
```

#### Step 5: Import the Existing Resource

```bash
# Replace <instance-id> with the ID from setup.sh output
terraform import aws_instance.imported <instance-id>

# Example:
# terraform import aws_instance.imported i-abc123def456
```

#### Step 6: View the Imported Resource Details

```bash
# Show all attributes of the imported resource
terraform state show aws_instance.imported
```

This will display something like:
```hcl
resource "aws_instance" "imported" {
    ami                    = "ami-04681a1dbd79675a5"
    instance_type          = "t2.micro"
    tags                   = {
        "Name"      = "manually-created-instance"
        "CreatedBy" = "console"
    }
    # ... more attributes
}
```

#### Step 7: Update main.tf to Match the Imported State

Copy the required attributes from `terraform state show` into your `main.tf`:

```hcl
resource "aws_instance" "imported" {
  ami           = "ami-04681a1dbd79675a5"  # Copy from state show
  instance_type = "t2.micro"               # Copy from state show

  tags = {
    Name      = "manually-created-instance"
    CreatedBy = "console"
  }
}
```

#### Step 8: Verify Import Was Successful

```bash
# This should show "No changes" - proving config matches the resource
terraform plan
```

#### Success Criteria
- ✅ `terraform import` completes successfully
- ✅ `terraform state show` displays resource attributes
- ✅ `terraform plan` shows "No changes"

---

### Task 3: Move Resources Between States (Detailed Walkthrough)

Split a large Terraform project by moving resources to a new state.

**Directory:** `scenario-3-move/`

**Objective:** Move the database resources from `old-project` to `new-project`.

#### Step 1: Navigate to the Old Project

```bash
cd ../scenario-3-move/old-project
```

#### Step 2: Initialize and Create Resources in Old Project

```bash
# Initialize Terraform
terraform init

# Create all resources (web + database)
terraform apply -auto-approve

# List all resources
terraform state list
# Should show:
# aws_instance.web
# aws_instance.db
# aws_security_group.web
# aws_security_group.db
```

#### Step 3: Initialize the New Project

```bash
# Go to new project
cd ../new-project

# Initialize (creates empty state)
terraform init

# Go back to old project
cd ../old-project
```

#### Step 4: Move Database Resources to New Project

```bash
# Move the database instance
terraform state mv -state-out=../new-project/terraform.tfstate \
  aws_instance.db aws_instance.db

# Move the database security group
terraform state mv -state-out=../new-project/terraform.tfstate \
  aws_security_group.db aws_security_group.db

# Verify resources moved out of old project
terraform state list
# Should now only show:
# aws_instance.web
# aws_security_group.web
```

#### Step 5: Verify New Project Has the Resources

```bash
cd ../new-project

# List resources in new project
terraform state list
# Should show:
# aws_instance.db
# aws_security_group.db
```

#### Step 6: Update Configuration Files

**In `old-project/main.tf`:** Comment out or remove the database resources (aws_instance.db and aws_security_group.db)

**In `new-project/main.tf`:** Uncomment the database resources

#### Step 7: Verify Both Projects

```bash
# In new-project directory
terraform plan
# Should show "No changes"

# Check old project
cd ../old-project
terraform plan
# Should show "No changes"
```

#### Success Criteria
- ✅ `terraform state list` shows correct resources in each project
- ✅ `terraform plan` shows "No changes" in BOTH projects
- ✅ Resources are now managed by separate state files

---

### Task 4: State Recovery

Practice recovering from a "lost" state file.

**Directory:** `scenario-4-recovery/` (bonus)

**Objective:** Rebuild state from existing AWS resources.

This simulates a disaster scenario where state is lost but resources exist.

```bash
cd scenario-4-recovery

# "Lose" the state file
rm terraform.tfstate

# Your task: Reconstruct state by importing all resources
terraform import aws_instance.web <instance-id>
terraform import aws_security_group.main <sg-id>
# etc.

# Verify
terraform plan  # Should show no changes
```

---

## Getting Started

### Step 1: Start LocalStack

```bash
docker-compose up -d
docker-compose ps
```

### Step 2: Initialize Scenario 1

```bash
cd scenario-1-local-to-remote
terraform init
terraform apply -auto-approve
terraform state list
```

### Step 3: Complete Each Scenario

Work through scenarios 1-4 in order.

### Step 4: Check Progress

```bash
python run.py
```

---

## How Grading Works

### Local Progress Checker (`run.py`)

```bash
python run.py
```

### GitHub Actions (Automated Grading)

| Component | Points | Requirements |
|-----------|--------|--------------|
| Scenario 1 Files | 3 | backend.tf exists and configured |
| Scenario 1 Content | 3 | S3 backend, bucket, key, region |
| Scenario 2 Files | 3 | main.tf with import resource |
| Scenario 2 Content | 3 | aws_instance resource for import |
| Scenario 3 Files | 4 | Both old and new project main.tf |
| Scenario 3 Content | 2 | Resources properly split |
| Documentation | 2 | migrate.sh and import.sh scripts |
| **Total** | **20** | **75% needed to pass** |

---

## State Command Reference

```bash
# === LISTING ===
terraform state list                    # List all resources
terraform state list module.app         # List resources in module

# === SHOWING ===
terraform state show aws_instance.web   # Show resource details

# === MOVING ===
terraform state mv SOURCE DEST          # Move/rename resource
terraform state mv -state-out=FILE ...  # Move to different state

# === REMOVING ===
terraform state rm aws_instance.web     # Remove from state (keeps resource!)

# === IMPORTING ===
terraform import ADDR ID                # Import existing resource

# === PULLING/PUSHING ===
terraform state pull > backup.json      # Download state
terraform state push backup.json        # Upload state (careful!)

# === REPLACING ===
terraform state replace-provider OLD NEW  # Change provider

# === REFRESHING ===
terraform refresh                       # Update state from real resources
```

---

## Troubleshooting

### State Lock Issues

```bash
# Error: state is locked
terraform force-unlock LOCK_ID

# Prevent lock timeout
export TF_LOCK_TIMEOUT=300s
```

### Backend Migration Errors

```bash
# Error: Backend configuration changed
terraform init -reconfigure

# Error: State not found
terraform init -migrate-state
```

### Import Errors

```bash
# Error: Resource already in state
terraform state rm aws_instance.web
terraform import aws_instance.web i-xxx

# Error: Configuration doesn't match
# Run terraform state show and update your config
```

### State File Corruption

```bash
# Restore from backup
cp terraform.tfstate.backup terraform.tfstate

# If S3 versioning enabled
aws s3api list-object-versions --bucket BUCKET --prefix KEY
aws s3api get-object --bucket BUCKET --key KEY --version-id VER state.json
```

---

## Best Practices

### 1. Always Backup Before Migration

```bash
# Local state
cp terraform.tfstate terraform.tfstate.backup

# Remote state
terraform state pull > state-backup-$(date +%Y%m%d).json
```

### 2. Use -dry-run When Available

```bash
# Check what would happen
terraform plan
```

### 3. Enable State Versioning

```hcl
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}
```

### 4. Document All Migrations

```bash
# Keep a log
echo "$(date): Migrated aws_instance.web from local to S3" >> migration.log
```

---

## Next Steps

After completing this challenge:

1. **Advanced IAM**
   - [aws-iam-advanced](https://github.com/techlearn-center/aws-iam-advanced)
   - Roles, assume role, cross-account

2. **CI/CD Integration**
   - [cicd-pipeline](https://github.com/techlearn-center/cicd-pipeline)
   - Automate Terraform in pipelines

3. **Monitoring**
   - [monitoring-stack](https://github.com/techlearn-center/monitoring-stack)
   - Monitor your infrastructure

---

## Resources

- [Terraform State Documentation](https://developer.hashicorp.com/terraform/language/state)
- [Backend Configuration](https://developer.hashicorp.com/terraform/language/settings/backends/configuration)
- [Import Documentation](https://developer.hashicorp.com/terraform/cli/import)
- [State Command Reference](https://developer.hashicorp.com/terraform/cli/commands/state)

---

## License

This challenge is part of the TechLearn Center curriculum.
Free to use for educational purposes.

---

**Happy State Managing! 🔄**

*Remember: Always backup before migrating!*
