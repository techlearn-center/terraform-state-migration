# Scenario 2: Import Existing Resources

## The Scenario

A team member created an EC2 instance manually through the AWS Console. Now you need to bring this "orphaned" resource under Terraform management without destroying and recreating it.

**Your mission:** Import an existing AWS resource into Terraform state.

---

## Choose Your Mode

| Mode | Best For | Cost | Requirements |
|------|----------|------|--------------|
| **LocalStack** (Default) | Learning, practice | Free | Docker installed |
| **Real AWS** | Real-world experience | ~$0.01-0.05 | AWS account + credentials |

---

## Why This Matters

### Common Situations Requiring Import

| Situation | Example |
|-----------|---------|
| **Legacy resources** | Infrastructure created before adopting Terraform |
| **Manual creation** | Someone created resources via AWS Console |
| **Migration** | Moving from CloudFormation or other IaC tools |
| **Emergency fixes** | Resources created manually during incidents |
| **Acquisitions** | Inheriting infrastructure from another team |

### The Problem Without Import

```
WITHOUT TERRAFORM IMPORT:
=========================

Your main.tf                           AWS (Reality)
+----------------------+               +----------------------+
| resource "aws_       |               | i-0abc123def456789   |
|   instance" "web" {  |  CONFLICT!    | (already exists)     |
|   ami = "..."        | ------------> |                      |
| }                    |               |                      |
+----------------------+               +----------------------+

terraform apply would try to CREATE a new instance
because Terraform doesn't know the existing one exists!

Result:
- Duplicate resources
- Wasted money
- Potential conflicts
```

### The Solution: terraform import

```
WITH TERRAFORM IMPORT:
======================

Step 1: Write resource block in main.tf

Step 2: Run terraform import

Your main.tf                State                     AWS (Reality)
+----------------------+    +-------------------+     +----------------------+
| resource "aws_       |    | aws_instance.web  |     | i-0abc123def456789   |
|   instance" "web" {  | -> | = i-0abc123...    | <-> | (already exists)     |
| }                    |    +-------------------+     +----------------------+
+----------------------+

Now Terraform knows about the existing resource!
terraform plan shows: "No changes"
```

---

## Understanding the Import Process

```
IMPORT WORKFLOW:
================

1. IDENTIFY         2. WRITE CONFIG       3. IMPORT            4. REFINE
+-------------+     +---------------+     +---------------+     +---------------+
| Find the    |     | Create empty  |     | terraform     |     | Update config |
| resource ID | --> | resource      | --> | import        | --> | to match      |
| in AWS      |     | block in .tf  |     | command       |     | actual state  |
+-------------+     +---------------+     +---------------+     +---------------+

   AWS Console         main.tf              Terminal            main.tf
   i-0abc123...        resource {}          $ terraform         ami = "..."
                                            import ...          tags = {...}
```

---

## File Structure

```
scenario-2-import/
|-- main.tf                      # Resource configuration (add your resource block here)
|-- provider-localstack.tf       # LocalStack provider (default)
|-- provider-aws.tf.example      # Real AWS provider (rename to use)
|-- terraform.tfvars.aws.example # Variables for Real AWS
|-- setup.sh                     # Creates a "manual" resource to import
|-- setup.ps1                    # Windows version
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
```

### Step 2: Create the "Manual" Resource

```bash
cd scenario-2-import

chmod +x setup.sh
./setup.sh
```

The script simulates someone creating a resource via AWS Console. Note the output:

```
==============================================
  MANUALLY CREATED RESOURCE (LocalStack)
==============================================

Instance ID: i-abc123def456
AMI ID:      ami-12345678
Type:        t2.micro

Your task:
1. Add a resource block to main.tf
2. Run: terraform import aws_instance.imported i-abc123def456
...
```

**Save the Instance ID!** You'll need it for the import command.

### Step 3: Write the Resource Block

Edit `main.tf` and add an **uncommented** resource block:

```hcl
resource "aws_instance" "imported" {
  ami           = "ami-12345678"
  instance_type = "t2.micro"

  tags = {
    Name      = "manually-created-instance"
    CreatedBy = "console"
  }
}
```

**Important:** The resource block MUST exist before you can import!

### Step 4: Initialize Terraform

```bash
terraform init
```

### Step 5: Import the Resource

```bash
terraform import aws_instance.imported <INSTANCE_ID>
```

Example:
```bash
terraform import aws_instance.imported i-abc123def456
```

You should see:
```
aws_instance.imported: Importing from ID "i-abc123def456"...
aws_instance.imported: Import prepared!
aws_instance.imported: Refreshing state...

Import successful!
```

### Step 6: Verify the Import

```bash
# Check what's in state
terraform state list

# See the imported attributes
terraform state show aws_instance.imported

# Verify no changes needed
terraform plan
```

If `terraform plan` shows changes, update `main.tf` to match the actual resource attributes.

---

## Option B: Real AWS

### Prerequisites

- AWS account with billing enabled
- AWS CLI installed and configured (`aws configure`)
- Permissions: EC2

### Step 1: Verify AWS Credentials

```bash
aws sts get-caller-identity
```

### Step 2: Switch to AWS Provider

```bash
cd scenario-2-import

# Disable LocalStack provider
mv provider-localstack.tf provider-localstack.tf.bak

# Enable AWS provider
mv provider-aws.tf.example provider-aws.tf

# Configure variables
mv terraform.tfvars.aws.example terraform.tfvars
```

### Step 3: Create the "Manual" Resource

```bash
chmod +x setup.sh
./setup.sh aws
```

Note the output carefully:
```
==============================================
  MANUALLY CREATED RESOURCE (Real AWS)
==============================================

Instance ID: i-0abc123def456789
AMI ID:      ami-0c101f26f147fa7fd
Type:        t2.micro
Region:      us-east-1
```

**Save both the Instance ID and AMI ID!**

### Step 4: Update terraform.tfvars

Edit `terraform.tfvars` with the AMI ID from the script output:

```hcl
ami_id = "ami-0c101f26f147fa7fd"  # Use the AMI from setup.sh output!
```

### Step 5: Write the Resource Block

Edit `main.tf` and add an **uncommented** resource block:

```hcl
resource "aws_instance" "imported" {
  ami           = var.ami_id
  instance_type = "t2.micro"

  tags = {
    Name      = "manually-created-instance"
    CreatedBy = "console"
  }
}
```

### Step 6: Initialize and Import

```bash
terraform init
terraform import aws_instance.imported <INSTANCE_ID>
```

### Step 7: Handle Attribute Mismatches

After import, run:
```bash
terraform plan
```

If it shows changes, check the actual attributes:
```bash
terraform state show aws_instance.imported
```

Update `main.tf` to match (especially `ami`, `instance_type`, and `tags`).

### Step 8: Verify Success

```bash
terraform plan
# Should show: "No changes. Your infrastructure matches the configuration."
```

### Step 9: Clean Up (Important!)

```bash
terraform destroy -auto-approve
```

---

## Common Mistakes and Solutions

### Mistake 1: Resource block doesn't exist

**Error:**
```
Error: resource address "aws_instance.imported" does not exist in the configuration.
```

**Solution:** You must write the resource block in `main.tf` BEFORE running `terraform import`. Import doesn't create configuration - it only creates state.

### Mistake 2: Wrong resource address

**Error:**
```
Error: resource address "aws_instance.wrong_name" does not exist in the configuration.
```

**Solution:** The resource address in the import command must exactly match your .tf file:
- In main.tf: `resource "aws_instance" "imported" { }`
- Import command: `terraform import aws_instance.imported <id>`

### Mistake 3: Plan shows changes after import

**Symptom:** After import, `terraform plan` wants to change attributes.

**Solution:** This is normal! Import only adds the resource to state - it doesn't update your config. You need to update `main.tf` to match the actual resource:

```bash
# See actual attributes
terraform state show aws_instance.imported

# Update main.tf to match
# Then verify
terraform plan
```

### Mistake 4: AMI mismatch for Real AWS

**Symptom:** Plan shows AMI will be changed.

**Solution:** Update `terraform.tfvars` with the correct AMI ID:
```bash
terraform state show aws_instance.imported | grep ami
# Copy the ami value to terraform.tfvars
```

---

## Understanding What Import Does

### Before Import

```
main.tf:
  resource "aws_instance" "imported" { ... }

terraform.tfstate:
  (empty or doesn't mention aws_instance.imported)

AWS:
  Instance i-abc123 exists
```

### The Import Command

```bash
terraform import aws_instance.imported i-abc123
```

This tells Terraform: "The resource `aws_instance.imported` in my configuration corresponds to `i-abc123` in AWS."

### After Import

```
main.tf:
  resource "aws_instance" "imported" { ... }

terraform.tfstate:
  aws_instance.imported = {
    id = "i-abc123"
    ami = "ami-12345678"
    instance_type = "t2.micro"
    ...
  }

AWS:
  Instance i-abc123 exists
```

Now Terraform knows about the resource and can manage it!

---

## Success Criteria

- [ ] "Manual" resource created via setup.sh
- [ ] Resource block added to main.tf
- [ ] `terraform import` completed successfully
- [ ] `terraform state list` shows the resource
- [ ] `terraform plan` shows "No changes"

---

## Key Commands Reference

| Command | Purpose |
|---------|---------|
| `terraform import <addr> <id>` | Import existing resource into state |
| `terraform state list` | List all resources in state |
| `terraform state show <addr>` | Show details of a resource |
| `terraform plan` | Verify configuration matches state |

---

## Real-World Tips

### 1. Find Resource IDs

```bash
# EC2 instances
aws ec2 describe-instances --query 'Reservations[].Instances[].InstanceId'

# Security groups
aws ec2 describe-security-groups --query 'SecurityGroups[].GroupId'

# S3 buckets
aws s3 ls
```

### 2. Use Tags to Identify Resources

Well-tagged resources are easier to identify for import:
```bash
aws ec2 describe-instances --filters "Name=tag:Name,Values=my-server"
```

### 3. Import in Batches

For many resources, create a script:
```bash
#!/bin/bash
terraform import aws_instance.web i-abc123
terraform import aws_instance.api i-def456
terraform import aws_security_group.web sg-789xyz
```

### 4. Document What You Import

Keep a log of imported resources for your team.

---

## Next Steps

After completing this scenario:
- Try [Scenario 3: Move Resources](../scenario-3-move/) between state files
- Learn about [Scenario 4: Backend Migration](../scenario-4-backend-migration/)
