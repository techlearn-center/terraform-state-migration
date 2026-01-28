# Scenario 3: Move Resources Between State Files

## The Scenario

Your Terraform project has grown too large. You need to split it into separate projects - moving the database resources to a dedicated "database" project while keeping web resources in the original project.

**Your mission:** Move resources from one Terraform state to another without destroying them.

---

## Choose Your Mode

| Mode | Best For | Cost | Requirements |
|------|----------|------|--------------|
| **LocalStack** (Default) | Learning, practice | Free | Docker installed |
| **Real AWS** | Real-world experience | ~$0.02-0.05 | AWS account + credentials |

---

## Why This Matters

### When to Split Terraform State

| Situation | Example |
|-----------|---------|
| **Large monolith** | Single state with 500+ resources becomes slow |
| **Team boundaries** | Database team vs Application team |
| **Blast radius** | Limit damage if something goes wrong |
| **Different lifecycles** | Infrastructure vs Application resources |
| **Compliance** | Separate state for PCI/HIPAA resources |

### The Problem: Monolithic State

```
BEFORE (One Big Project):
=========================

old-project/
|-- main.tf
|   |-- aws_instance.web
|   |-- aws_security_group.web
|   |-- aws_instance.db        <-- Should be separate
|   |-- aws_security_group.db  <-- Should be separate
|
+-- terraform.tfstate (tracks ALL resources)

Problems:
- Slow terraform plan/apply (500+ resources)
- Risk: one mistake affects everything
- Hard to manage team permissions
- Complex code reviews
```

### The Solution: Split State

```
AFTER (Separate Projects):
==========================

old-project/                       new-project/
|-- main.tf                        |-- main.tf
|   |-- aws_instance.web           |   |-- aws_instance.db
|   |-- aws_security_group.web     |   |-- aws_security_group.db
|                                  |
+-- terraform.tfstate              +-- terraform.tfstate
    (web resources only)               (db resources only)

Benefits:
- Faster operations
- Isolated blast radius
- Clear ownership
- Simpler code reviews
```

---

## Understanding terraform state mv

### What It Does

```
terraform state mv -state-out=../new-project/terraform.tfstate \
  aws_instance.db aws_instance.db

BEFORE:
=======
old-project/terraform.tfstate:
  - aws_instance.web
  - aws_instance.db     <-- This resource

new-project/terraform.tfstate:
  (empty)


AFTER:
======
old-project/terraform.tfstate:
  - aws_instance.web

new-project/terraform.tfstate:
  - aws_instance.db     <-- Moved here!

The actual AWS resource is NOT touched!
Only the state file reference moves.
```

---

## File Structure

```
scenario-3-move/
|-- old-project/                   # Source project (web + db)
|   |-- main.tf
|   |-- provider-localstack.tf
|   +-- provider-aws.tf.example
|
|-- new-project/                   # Destination project (db only)
|   |-- main.tf
|   |-- provider-localstack.tf
|   +-- provider-aws.tf.example
|
|-- move-resources.sh              # Script to move resources
+-- README.md                      # This file
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

### Step 2: Create Resources in Old Project

```bash
cd scenario-3-move/old-project

terraform init
terraform apply -auto-approve
```

Check what was created:
```bash
terraform state list
```

Output:
```
aws_instance.db
aws_instance.web
aws_security_group.db
aws_security_group.web
```

### Step 3: Initialize New Project

```bash
cd ../new-project

terraform init
```

### Step 4: Move Database Resources

Go back to old-project and move the resources:

```bash
cd ../old-project

# Move the database security group
terraform state mv \
  -state-out=../new-project/terraform.tfstate \
  aws_security_group.db aws_security_group.db

# Move the database instance
terraform state mv \
  -state-out=../new-project/terraform.tfstate \
  aws_instance.db aws_instance.db
```

### Step 5: Verify the Move

Check old-project (should only have web resources):
```bash
terraform state list
```

Output:
```
aws_instance.web
aws_security_group.web
```

Check new-project:
```bash
cd ../new-project
terraform state list
```

Output:
```
aws_instance.db
aws_security_group.db
```

### Step 6: Update Configuration Files

**In old-project/main.tf:** Comment out or remove the db resources:
```hcl
# These have been moved to new-project:
# resource "aws_security_group" "db" { ... }
# resource "aws_instance" "db" { ... }
```

**In new-project/main.tf:** Uncomment the db resources (they're already there as comments).

### Step 7: Verify No Changes

```bash
# In old-project
cd ../old-project
terraform plan
# Should show: "No changes"

# In new-project
cd ../new-project
terraform plan
# Should show: "No changes"
```

---

## Option B: Real AWS

### Prerequisites

- AWS account with billing enabled
- AWS CLI installed and configured
- Permissions: EC2

### Step 1: Switch to AWS Provider (Both Projects)

```bash
cd scenario-3-move/old-project

# Switch provider
mv provider-localstack.tf provider-localstack.tf.bak
mv provider-aws.tf.example provider-aws.tf

# Do the same for new-project
cd ../new-project
mv provider-localstack.tf provider-localstack.tf.bak
mv provider-aws.tf.example provider-aws.tf
```

### Step 2: Create Resources in Old Project

```bash
cd ../old-project

terraform init
terraform apply -auto-approve
```

### Step 3: Initialize New Project

```bash
cd ../new-project
terraform init
```

### Step 4: Move Database Resources

```bash
cd ../old-project

# Move resources
terraform state mv \
  -state-out=../new-project/terraform.tfstate \
  aws_security_group.db aws_security_group.db

terraform state mv \
  -state-out=../new-project/terraform.tfstate \
  aws_instance.db aws_instance.db
```

### Step 5: Update Configuration Files

Same as LocalStack - update both main.tf files.

### Step 6: Verify No Changes

```bash
cd ../old-project
terraform plan  # No changes

cd ../new-project
terraform plan  # No changes
```

### Step 7: Clean Up (Important!)

```bash
# Destroy new-project resources
cd ../new-project
terraform destroy -auto-approve

# Destroy old-project resources
cd ../old-project
terraform destroy -auto-approve
```

---

## The terraform state mv Command

### Syntax

```bash
terraform state mv [options] SOURCE DESTINATION
```

### Common Options

| Option | Description |
|--------|-------------|
| `-state-out=PATH` | Write to a different state file |
| `-dry-run` | Preview without making changes |
| `-lock=false` | Don't lock state during operation |

### Examples

**Move within same state (rename):**
```bash
terraform state mv aws_instance.web aws_instance.web_server
```

**Move to different state file:**
```bash
terraform state mv -state-out=../other/terraform.tfstate \
  aws_instance.db aws_instance.db
```

**Move with different name in destination:**
```bash
terraform state mv -state-out=../other/terraform.tfstate \
  aws_instance.db aws_instance.database
```

---

## Common Mistakes and Solutions

### Mistake 1: Forgetting to update configuration

**Symptom:** After moving state, `terraform plan` shows resources will be created/destroyed.

**Solution:**
- Remove/comment resource blocks from source project's main.tf
- Add/uncomment resource blocks in destination project's main.tf

### Mistake 2: Moving before initializing destination

**Error:**
```
Error: state path "../new-project/terraform.tfstate" does not exist
```

**Solution:** Initialize the destination project first:
```bash
cd ../new-project
terraform init
```

### Mistake 3: Dependency issues

**Symptom:** Resources in new project reference resources in old project.

**Solution:** Update references to use data sources or hard-coded values:
```hcl
# Instead of:
security_groups = [aws_security_group.web.id]

# Use:
security_groups = ["sg-12345678"]  # Hard-coded ID
# OR use a data source
```

### Mistake 4: Running terraform apply before updating config

**Danger:** If you run `terraform apply` in old-project after moving state but before updating main.tf, Terraform will try to re-create the moved resources!

**Prevention:** Always update configuration files immediately after moving state.

---

## Success Criteria

- [ ] Resources created in old-project
- [ ] Database resources moved to new-project
- [ ] old-project state has only web resources
- [ ] new-project state has only db resources
- [ ] Both projects show "No changes" on plan
- [ ] Configuration files updated in both projects

---

## Key Commands Reference

| Command | Purpose |
|---------|---------|
| `terraform state mv` | Move resource within/between states |
| `terraform state list` | List resources in state |
| `terraform state show <addr>` | Show resource details |
| `terraform state rm <addr>` | Remove from state (doesn't destroy resource) |

---

## Real-World Best Practices

### 1. Plan Your Split

Before moving, document:
- Which resources move
- New project structure
- Dependency handling

### 2. Coordinate with Team

- Announce the migration window
- Ensure no one else is running Terraform
- Use state locking

### 3. Backup State Files

```bash
# Before moving
cp terraform.tfstate terraform.tfstate.backup
```

### 4. Move in Order

Move dependent resources in the right order:
1. Move security groups first
2. Then move instances that use them

### 5. Use Scripts for Large Moves

For many resources, create a script:
```bash
#!/bin/bash
# move-db-resources.sh

terraform state mv -state-out=../new-project/terraform.tfstate \
  aws_security_group.db aws_security_group.db

terraform state mv -state-out=../new-project/terraform.tfstate \
  aws_instance.db aws_instance.db

terraform state mv -state-out=../new-project/terraform.tfstate \
  aws_db_instance.main aws_db_instance.main
```

---

## Next Steps

After completing this scenario:
- Try [Scenario 4: Backend Migration](../scenario-4-backend-migration/)
- Learn about [Scenario 5: State Recovery](../scenario-5-state-recovery/)
