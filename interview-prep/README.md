# Terraform State Management - Interview Prep

## Common Interview Questions & Hands-On Practice

This mini-challenge prepares you for DevOps/Cloud Engineer interviews by covering the most frequently asked Terraform state management questions.

---

## Question 1: "What is Terraform state and why is it important?"

### Expected Answer:
- Terraform state is a JSON file that maps your configuration to real-world resources
- It tracks resource IDs, dependencies, and metadata
- Without state, Terraform wouldn't know what resources it manages
- State enables: plan/apply, dependency tracking, performance optimization

### Hands-On Practice:
```bash
cd ../scenario-1-local-to-remote
terraform init
terraform apply -auto-approve

# Examine the state file
cat terraform.tfstate | head -50

# Key things to point out:
# - "serial" increments with each change
# - "lineage" is a unique ID that never changes
# - "resources" contains all managed resources with their IDs
```

**Interview Tip:** Mention that state contains sensitive data (passwords, keys) so it should be stored securely.

---

## Question 2: "How do you migrate Terraform state from local to remote?"

### Expected Answer:
1. Create the remote backend (S3 bucket)
2. Add backend configuration to terraform block
3. Run `terraform init -migrate-state`
4. Verify with `terraform plan` (should show no changes)

### Hands-On Practice:
```bash
# You should have already done this in scenario-1
# The key command is:
terraform init -migrate-state

# Terraform will ask:
# "Do you want to copy existing state to the new backend?"
# Answer: yes
```

**Interview Tip:** Mention state locking with DynamoDB to prevent concurrent modifications.

---

## Question 3: "A colleague created an EC2 instance manually. How do you bring it under Terraform management?"

### Expected Answer:
1. Write a resource block in your .tf file
2. Run `terraform import <resource_address> <resource_id>`
3. Run `terraform state show` to see imported attributes
4. Update your config to match the imported state
5. Verify with `terraform plan` (should show no changes)

### Hands-On Practice:
```bash
cd ../scenario-2-import

# Create a "manual" resource
./setup.sh  # Note the instance ID!

# Write minimal resource block, then:
terraform import aws_instance.imported <instance-id>
terraform state show aws_instance.imported
# Update main.tf with the attributes
terraform plan  # Should show "No changes"
```

**Interview Tip:** Mention `terraform import` only imports state, not configuration. You must write the config manually (or use `terraform plan -generate-config-out` in TF 1.5+).

---

## Question 4: "How do you split a large Terraform project into smaller ones?"

### Expected Answer:
1. Use `terraform state mv` to move resources to a new state file
2. Remove the resource blocks from the old project
3. Add the resource blocks to the new project
4. Verify both projects show "No changes"

### Hands-On Practice:
```bash
cd ../scenario-3-move/old-project
terraform init && terraform apply -auto-approve

# Move database resources to new project
terraform state mv -state-out=../new-project/terraform.tfstate \
  aws_instance.db aws_instance.db

terraform state mv -state-out=../new-project/terraform.tfstate \
  aws_security_group.db aws_security_group.db

# Update configs in both projects
# Verify: terraform plan in both should show "No changes"
```

**Interview Tip:** Emphasize that `state mv` doesn't touch real infrastructure - it only moves the state tracking.

---

## Question 5: "What happens if the state file gets corrupted or lost?"

### Expected Answer:
1. **If you have backups:** Restore from backup or S3 versioning
2. **If no backups:** Re-import all resources using `terraform import`
3. **Prevention:** Enable S3 versioning, use state locking, regular backups

### Hands-On Practice:
```bash
cd ../scenario-1-local-to-remote

# Simulate "losing" state
mv terraform.tfstate terraform.tfstate.lost

# Now terraform thinks nothing exists:
terraform plan  # Shows it wants to CREATE everything!

# Recovery option 1: Restore backup
mv terraform.tfstate.lost terraform.tfstate

# Recovery option 2: Re-import (if no backup)
# terraform import aws_instance.web <instance-id>
# terraform import aws_security_group.web <sg-id>
```

**Interview Tip:** This is why remote state with versioning is critical for production.

---

## Question 6: "Explain the difference between `terraform state rm` and `terraform destroy`"

### Expected Answer:
| Command | What it does | Real infrastructure |
|---------|--------------|---------------------|
| `terraform state rm` | Removes resource from state only | **Unchanged** (still exists!) |
| `terraform destroy` | Removes from state AND destroys | **Deleted** |

### Hands-On Practice:
```bash
# CAREFUL: Only do this on LocalStack/test resources!

# state rm example:
terraform state rm aws_instance.web
# The instance still exists in AWS, but Terraform no longer manages it

# To manage it again, you'd need to import it back:
terraform import aws_instance.web <instance-id>
```

**Interview Tip:** Use `state rm` when you want to stop managing a resource without destroying it (e.g., handing off to another team).

---

## Question 7: "How do you handle state locking?"

### Expected Answer:
- State locking prevents concurrent operations that could corrupt state
- For S3 backend, use DynamoDB table for locking
- If a lock is stuck, use `terraform force-unlock <LOCK_ID>`

### Configuration Example:
```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"  # This enables locking!
  }
}
```

**Interview Tip:** Mention that state locking is automatic with most remote backends.

---

## Question 8: "What's in a Terraform state file?" (Whiteboard Question)

### Draw This Structure:
```
terraform.tfstate
├── version: 4
├── terraform_version: "1.5.0"
├── serial: 42 (increments on each change)
├── lineage: "abc-123..." (unique ID, never changes)
├── outputs: { ... }
└── resources: [
    {
      type: "aws_instance"
      name: "web"
      provider: "hashicorp/aws"
      instances: [
        {
          attributes: {
            id: "i-abc123"
            ami: "ami-xxx"
            instance_type: "t2.micro"
          }
        }
      ]
    }
  ]
```

---

## Question 9: "What are Terraform workspaces and when would you use them?"

### Expected Answer:
- Workspaces allow multiple state files for the same configuration
- Common use case: dev/staging/prod environments
- Each workspace has its own state file
- Access current workspace with `terraform.workspace`

### Commands:
```bash
terraform workspace list
terraform workspace new dev
terraform workspace select prod
terraform workspace show
```

**Interview Tip:** Some teams prefer separate directories/repos over workspaces for better isolation.

---

## Quick Reference: State Commands

```bash
# LIST resources in state
terraform state list

# SHOW details of a resource
terraform state show aws_instance.web

# MOVE/RENAME a resource
terraform state mv aws_instance.old aws_instance.new

# MOVE to different state file
terraform state mv -state-out=other.tfstate aws_instance.web aws_instance.web

# REMOVE from state (keeps real resource!)
terraform state rm aws_instance.web

# IMPORT existing resource
terraform import aws_instance.web i-abc123

# PULL state to local file
terraform state pull > state.json

# PUSH local file to remote (DANGEROUS!)
terraform state push state.json

# FORCE UNLOCK stuck state
terraform force-unlock LOCK_ID
```

---

## Interview Scenario Practice

### Scenario 1: "Production state file was accidentally deleted"
**Your Answer:**
1. Don't panic - the infrastructure is still running
2. Check if S3 versioning is enabled - restore previous version
3. If no versioning, identify all resources in AWS console
4. Re-import each resource using `terraform import`
5. Verify with `terraform plan` shows no changes
6. Enable versioning to prevent future issues

### Scenario 2: "Two developers ran terraform apply at the same time"
**Your Answer:**
1. This is why we use state locking (DynamoDB)
2. If locks weren't enabled, state might be corrupted
3. Recovery: `terraform state pull`, fix conflicts manually, `terraform state push`
4. Prevention: Always use remote backend with locking

### Scenario 3: "Need to rename a resource without destroying it"
**Your Answer:**
```bash
# Old: aws_instance.web
# New: aws_instance.web_server

# Option 1: state mv
terraform state mv aws_instance.web aws_instance.web_server
# Then update the .tf file to match

# Option 2: moved block (Terraform 1.1+)
moved {
  from = aws_instance.web
  to   = aws_instance.web_server
}
```

---

## Checklist: Before Your Interview

- [ ] Can explain what state is and why it matters
- [ ] Know how to migrate local to remote state
- [ ] Can import existing resources
- [ ] Understand `state mv` vs `state rm` vs `destroy`
- [ ] Know about state locking with DynamoDB
- [ ] Can draw state file structure on whiteboard
- [ ] Practiced all scenarios hands-on with LocalStack

---

## Run Through All Scenarios

```bash
# Start LocalStack
cd ..
docker-compose up -d

# Scenario 1: State Migration
cd scenario-1-local-to-remote
# ... practice migration

# Scenario 2: Import
cd ../scenario-2-import
# ... practice import

# Scenario 3: Move
cd ../scenario-3-move/old-project
# ... practice state mv

# Clean up
docker-compose down
```

---

**Good luck with your interview! 🎯**

*Remember: Interviewers want to see you understand the concepts AND have hands-on experience. This practice gives you both.*
