# Scenario 5: State Recovery

## The Scenario

Your production Terraform state file was accidentally deleted. The resources still exist in AWS, but Terraform doesn't know about them.

**Your mission:** Rebuild the state file by importing all existing resources.

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

## Your Task

### What You'll Do

1. Run a script that creates resources then "loses" the state
2. Observe how Terraform wants to create duplicates
3. Import each resource to rebuild state
4. Verify recovery was successful

---

## Step-by-Step Instructions

### Step 1: Simulate the Disaster

```bash
cd scenario-5-state-recovery

# Make script executable (Linux/Mac)
chmod +x simulate-disaster.sh

# Run the disaster simulation
./simulate-disaster.sh           # LocalStack (default)
# OR
.\simulate-disaster.ps1          # Windows PowerShell
```

The script creates:
| Resource | Name |
|----------|------|
| EC2 Instance | `recovery-web-server` |
| Security Group | `recovery-web-sg` |
| EBS Volume | `recovery-data-volume` |

Then it **deletes** the state file, simulating accidental deletion.

### Step 2: Observe the Problem

```bash
terraform init
terraform plan
```

**What you'll see:**

```
Terraform will perform the following actions:

  # aws_ebs_volume.data will be created
  + resource "aws_ebs_volume" "data" {
      ...
    }

  # aws_instance.web will be created
  + resource "aws_instance" "web" {
      ...
    }

  # aws_security_group.web will be created
  + resource "aws_security_group" "web" {
      ...
    }

Plan: 3 to add, 0 to change, 0 to destroy.
```

**The problem:** Terraform wants to CREATE these resources, but they already exist in AWS!

If you ran `terraform apply` now, you would:
- Create duplicate EC2 instances
- Get errors on security group (name already exists)
- Waste money on duplicate resources

### Step 3: Get the Resource IDs

The disaster script saved the IDs to a file:

```bash
cat resource-ids.txt
```

Output example:
```
INSTANCE_ID=i-0abc123def456789
SECURITY_GROUP_ID=sg-0def456abc789012
VOLUME_ID=vol-0789abc123def456
```

**In real life**, you would find these IDs from:
- AWS Console
- AWS CLI: `aws ec2 describe-instances`
- CloudWatch logs
- Team documentation
- Tags on resources

### Step 4: Import Each Resource

The `terraform import` command has this syntax:
```
terraform import <RESOURCE_ADDRESS> <REAL_RESOURCE_ID>
```

Where:
- `<RESOURCE_ADDRESS>` = The name in your .tf file (e.g., `aws_instance.web`)
- `<REAL_RESOURCE_ID>` = The ID in AWS (e.g., `i-0abc123def456789`)

**Import all three resources:**

```bash
# Import the EC2 instance
terraform import aws_instance.web <INSTANCE_ID>

# Import the security group
terraform import aws_security_group.web <SECURITY_GROUP_ID>

# Import the EBS volume
terraform import aws_ebs_volume.data <VOLUME_ID>
```

**Example with real IDs:**
```bash
terraform import aws_instance.web i-0abc123def456789
terraform import aws_security_group.web sg-0def456abc789012
terraform import aws_ebs_volume.data vol-0789abc123def456
```

**What you'll see after each import:**
```
aws_instance.web: Importing from ID "i-0abc123def456789"...
aws_instance.web: Import prepared!
  Prepared aws_instance for import
aws_instance.web: Refreshing state... [id=i-0abc123def456789]

Import successful!

The resources that were imported are shown above. These resources are now in
your Terraform state and will henceforth be managed by Terraform.
```

### Step 5: Verify the Recovery

```bash
# List all resources in state
terraform state list
```

Expected output:
```
aws_ebs_volume.data
aws_instance.web
aws_security_group.web
```

```bash
# Check that plan shows no changes
terraform plan
```

Expected output:
```
No changes. Your infrastructure matches the configuration.
```

**Congratulations!** You've successfully recovered from state loss!

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

Your main.tf says:
```hcl
resource "aws_instance" "web" {
  ami           = "ami-old-value"
  instance_type = "t2.micro"
}
```

But the actual instance uses `ami-real-value`.

**How to fix:**

1. Check what was imported:
   ```bash
   terraform state show aws_instance.web
   ```

2. Update `main.tf` to match:
   ```hcl
   resource "aws_instance" "web" {
     ami           = "ami-real-value"   # Updated!
     instance_type = "t2.micro"
   }
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
| `Plan shows changes after import` | main.tf doesn't match actual resource | Update main.tf to match `terraform state show` output |
| `Cannot find resource` | Wrong resource ID | Double-check the ID in AWS Console |
| `Resource address does not exist` | Typo in resource name | Check main.tf for the exact resource address |

---

## Success Criteria

- [ ] All 3 resources imported into state
- [ ] `terraform state list` shows all resources
- [ ] `terraform plan` shows "No changes"

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

## Key Commands Reference

| Command | Purpose |
|---------|---------|
| `terraform import <addr> <id>` | Import existing resource into state |
| `terraform state list` | List all resources in state |
| `terraform state show <addr>` | Show details of a resource |
| `terraform state rm <addr>` | Remove resource from state (doesn't delete in AWS) |
| `terraform state pull` | Download state to stdout (for backup) |

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
