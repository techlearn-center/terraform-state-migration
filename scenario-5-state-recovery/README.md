# Scenario 5: State Recovery

## The Scenario

Your production Terraform state file was accidentally deleted. The resources still exist in AWS, but Terraform doesn't know about them.

**Your mission:** Rebuild the state file by importing all existing resources.

---

## Choose Your Mode

This scenario supports **two modes**. Choose based on your situation:

| Mode | Best For | Cost | Requirements |
|------|----------|------|--------------|
| **LocalStack** (Default) | Learning, practice | Free | Docker installed |
| **Real AWS** | Real-world experience | ~$0.01-0.05 | AWS account + credentials |

---

## Why This Matters

State loss happens in real life:
- Someone deleted `terraform.tfstate` thinking it was temporary
- S3 bucket with state was accidentally removed
- State file corruption after a failed migration
- New team member runs `terraform apply` without state

Without recovery skills, teams often:
- Re-create resources (causes downtime)
- Manually edit state (dangerous)
- Abandon Terraform for those resources

---

## Understanding the Problem

### What is Terraform State?

Terraform state is the **source of truth** that maps your configuration to real resources:

```
+-------------------+          +-------------------+          +-------------------+
|   main.tf         |          |   State File      |          |   AWS Resources   |
|   (Your Code)     |          | (terraform.tfstate)|         |   (Reality)       |
+-------------------+          +-------------------+          +-------------------+
|                   |          |                   |          |                   |
| resource "aws_    |  <---->  | aws_instance.web  |  <---->  | i-0abc123def456   |
|   instance" "web" |          | = i-0abc123def456 |          |                   |
|                   |          |                   |          |                   |
+-------------------+          +-------------------+          +-------------------+

        CODE             links to          STATE         links to         REALITY
```

### What Happens When State is Lost?

```
BEFORE DISASTER:
================

  main.tf                    State                      AWS
  +----------+          +-------------+          +----------------+
  | instance |  <---->  | instance =  |  <---->  | i-0abc123...   |
  | "web"    |          | i-0abc123   |          | (running)      |
  +----------+          +-------------+          +----------------+


AFTER DISASTER (State Deleted):
===============================

  main.tf                    State                      AWS
  +----------+          +-------------+          +----------------+
  | instance |          |             |          | i-0abc123...   |
  | "web"    |  --X-->  |   EMPTY!    |  --X-->  | (still there!) |
  +----------+          +-------------+          +----------------+

  Terraform thinks:                    Reality:
  "I need to CREATE                    "Instance already
   aws_instance.web"                    exists in AWS!"

  Result: terraform apply would try to create a DUPLICATE instance!
```

### The Recovery Process

```
RECOVERY USING terraform import:
================================

  Step 1: You have the resource ID from AWS (i-0abc123...)

  Step 2: Run: terraform import aws_instance.web i-0abc123...

  Step 3: State is rebuilt!

  main.tf                    State                      AWS
  +----------+          +-------------+          +----------------+
  | instance |  <---->  | instance =  |  <---->  | i-0abc123...   |
  | "web"    |          | i-0abc123   |          | (running)      |
  +----------+          +-------------+          +----------------+

  Now terraform plan shows: "No changes" (state matches reality!)
```

---

## File Structure

```
scenario-5-state-recovery/
|-- main.tf                      # Resources to recover
|-- provider-localstack.tf       # LocalStack provider (default)
|-- provider-aws.tf.example      # Real AWS provider (rename to use)
|-- terraform.tfvars.aws.example # Variables for Real AWS
|-- simulate-disaster.sh         # Creates resources and "loses" state
|-- simulate-disaster.ps1        # Windows version
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

### Step 2: Simulate the Disaster

```bash
cd scenario-5-state-recovery

# Make script executable (Linux/Mac)
chmod +x simulate-disaster.sh

# Run the disaster simulation
./simulate-disaster.sh           # Linux/Mac
.\simulate-disaster.ps1          # Windows PowerShell
```

The script creates:
| Resource | Name |
|----------|------|
| EC2 Instance | `recovery-web-server` |
| Security Group | `recovery-web-sg` |
| EBS Volume | `recovery-data-volume` |

Then it **deletes** the state file, simulating accidental deletion.

### Step 3: Observe the Problem

```bash
terraform init
terraform plan
```

**What you'll see:**

```
Terraform will perform the following actions:

  # aws_ebs_volume.data will be created
  + resource "aws_ebs_volume" "data" { ... }

  # aws_instance.web will be created
  + resource "aws_instance" "web" { ... }

  # aws_security_group.web will be created
  + resource "aws_security_group" "web" { ... }

Plan: 3 to add, 0 to change, 0 to destroy.
```

**The problem:** Terraform wants to CREATE these resources, but they already exist!

### Step 4: Get the Resource IDs

```bash
cat resource-ids.txt
```

Output example:
```
INSTANCE_ID=i-0abc123def456789
SECURITY_GROUP_ID=sg-0def456abc789012
VOLUME_ID=vol-0789abc123def456
```

### Step 5: Import Each Resource

```bash
# Import the EC2 instance
terraform import aws_instance.web <INSTANCE_ID>

# Import the security group
terraform import aws_security_group.web <SECURITY_GROUP_ID>

# Import the EBS volume
terraform import aws_ebs_volume.data <VOLUME_ID>
```

### Step 6: Verify the Recovery

```bash
# List all resources in state
terraform state list

# Check that plan shows no changes
terraform plan
```

Expected output:
```
No changes. Your infrastructure matches the configuration.
```

---

## Option B: Real AWS

### Prerequisites

- AWS account with billing enabled
- AWS CLI installed and configured (`aws configure`)
- Permissions: EC2 (instances, security groups, EBS volumes)

### Step 1: Verify AWS Credentials

```bash
aws sts get-caller-identity
```

### Step 2: Switch to AWS Provider

```bash
cd scenario-5-state-recovery

# Disable LocalStack provider
mv provider-localstack.tf provider-localstack.tf.bak

# Enable AWS provider
mv provider-aws.tf.example provider-aws.tf
```

### Step 3: Configure Variables

```bash
mv terraform.tfvars.aws.example terraform.tfvars
```

### Step 4: Simulate the Disaster

```bash
chmod +x simulate-disaster.sh
./simulate-disaster.sh aws
```

**Important:** Note the output! It shows:
- The AMI ID used
- The resource IDs created
- The availability zone

Example output:
```
Using AMI: ami-0c101f26f147fa7fd

[Step 1/4] Creating EC2 instance...
   Instance ID: i-0abc123def456789
[Step 2/4] Creating Security Group...
   Security Group ID: sg-0def456abc789012
[Step 3/4] Creating EBS Volume...
   Volume ID: vol-0789abc123def456
[Step 4/4] 'Losing' state file...

Resource IDs saved to: resource-ids.txt
```

### Step 5: Update terraform.tfvars

Edit `terraform.tfvars` to match the AMI ID from the script output:

```hcl
ami_id = "ami-0c101f26f147fa7fd"  # Use the AMI from script output!
availability_zone = "us-east-1a"
```

### Step 6: Observe the Problem

```bash
terraform init
terraform plan
```

Terraform will show it wants to CREATE 3 resources (but they already exist).

### Step 7: Import Each Resource

Use the IDs from `resource-ids.txt`:

```bash
# Import the EC2 instance
terraform import aws_instance.web i-0abc123def456789

# Import the security group
terraform import aws_security_group.web sg-0def456abc789012

# Import the EBS volume
terraform import aws_ebs_volume.data vol-0789abc123def456
```

### Step 8: Handle AMI Mismatch (If Needed)

If `terraform plan` shows AMI changes after import:

```bash
# Check the actual AMI
terraform state show aws_instance.web | grep ami
```

Update `terraform.tfvars` with the correct AMI ID.

### Step 9: Verify the Recovery

```bash
terraform state list
terraform plan
# Should show: "No changes"
```

### Step 10: Clean Up (Important!)

```bash
# Destroy resources to avoid charges
terraform destroy -auto-approve
```

---

## Understanding What Import Does

### Before Import

```
terraform.tfstate = empty (or doesn't exist)

aws_instance.web:
  State: NOT TRACKED
  AWS:   EXISTS (i-0abc123...)
```

### The Import Command

```bash
terraform import aws_instance.web i-0abc123...
```

This tells Terraform:
> "The resource `aws_instance.web` in my config corresponds to `i-0abc123...` in AWS.
> Please add this mapping to my state file."

### After Import

```
terraform.tfstate now contains:
{
  "resources": [
    {
      "type": "aws_instance",
      "name": "web",
      "instances": [
        {
          "attributes": {
            "id": "i-0abc123...",
            "ami": "ami-12345...",
            "instance_type": "t2.micro",
            ...
          }
        }
      ]
    }
  ]
}
```

---

## Handling Import Mismatches

Sometimes after import, `terraform plan` still shows changes. This means your `main.tf` doesn't exactly match the actual resource attributes.

### Example: AMI Mismatch

Your main.tf/tfvars says:
```hcl
ami_id = "ami-old-value"
```

But the actual instance uses `ami-real-value`.

**How to fix:**

1. Check what was imported:
   ```bash
   terraform state show aws_instance.web
   ```

2. Update `terraform.tfvars` (or `main.tf`) to match:
   ```hcl
   ami_id = "ami-real-value"   # Updated!
   ```

3. Verify:
   ```bash
   terraform plan
   # Should now show: "No changes"
   ```

---

## Common Errors and Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| `Resource already exists in state` | You imported the same resource twice | `terraform state rm <resource>` then re-import |
| `Plan shows changes after import` | main.tf/tfvars doesn't match actual resource | Update to match `terraform state show` output |
| `Cannot find resource` | Wrong resource ID | Double-check the ID in AWS Console or `resource-ids.txt` |
| `Resource address does not exist` | Typo in resource name | Check main.tf for the exact resource address |
| `Error: Inconsistent dependency lock file` | Provider mismatch | Run `terraform init -upgrade` |

---

## Success Criteria

- [ ] All 3 resources imported into state
- [ ] `terraform state list` shows all resources
- [ ] `terraform plan` shows "No changes"

---

## Key Commands Reference

| Command | Purpose |
|---------|---------|
| `terraform import <addr> <id>` | Import existing resource into state |
| `terraform state list` | List all resources in state |
| `terraform state show <addr>` | Show details of a resource |
| `terraform state rm <addr>` | Remove resource from state (doesn't delete in AWS) |
| `terraform state pull` | Download state to stdout (for backup) |

---

## Real-World Tips

### 1. Document Resource IDs

Keep a record of critical resource IDs somewhere outside of Terraform:
- Confluence/Wiki pages
- AWS resource tags
- Separate backup documentation

### 2. Enable State Versioning

If using S3 backend, enable versioning:
```bash
aws s3api put-bucket-versioning \
  --bucket my-state-bucket \
  --versioning-configuration Status=Enabled
```

This lets you recover deleted state from S3 version history.

### 3. Use Remote State

Local state files are easily lost. Use remote backends (S3, Terraform Cloud) for production.

### 4. Regular State Backups

```bash
# Pull state to a backup file
terraform state pull > state-backup-$(date +%Y%m%d).json
```

---

## What You Learned

1. **State is critical** - Without it, Terraform doesn't know what it manages
2. **Import rebuilds state** - Links configuration to existing resources
3. **Import requires matching config** - Resource block must exist in .tf files
4. **Always verify** - Run `terraform plan` after import to confirm success

---

## Next Steps

After completing this scenario:
- Practice with [Scenario 3: Moving Resources](../scenario-3-move/) between states
- Learn about [Scenario 4: Backend Migration](../scenario-4-backend-migration/) for changing state storage
