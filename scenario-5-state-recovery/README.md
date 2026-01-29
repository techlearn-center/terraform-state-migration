# Scenario 5: State Recovery (Disaster Recovery)

## What is This Scenario About?

**The Problem:** Your production Terraform state file was accidentally deleted. The servers, security groups, and storage volumes are still running in AWS, but Terraform has no memory of them. If you run `terraform apply`, Terraform will try to create **duplicate** resources because it thinks nothing exists. You need to rebuild the state file from scratch without touching the running infrastructure.

**The Solution:** Use `terraform import` to re-import each existing resource back into a fresh state file, effectively reconstructing Terraform's "memory" of the infrastructure.

**Real-World Example:** A junior engineer accidentally deleted the S3 bucket containing the production state file. The company's 50+ production servers are still running, but Terraform can't manage them anymore. You need to recover the state before the next deployment, or the team will have to manually manage everything.

---

## Learning Objectives

By completing this scenario, you will:

- [ ] Understand why state loss is a critical incident
- [ ] Know how to identify existing AWS resources that need to be imported
- [ ] Be able to import multiple resource types (EC2, Security Group, EBS Volume)
- [ ] Know how to update Terraform code to match real infrastructure
- [ ] Understand disaster recovery procedures for Terraform state

**After this scenario, you should be able to answer:**
- "What happens when you lose your Terraform state file?"
- "How do you rebuild state from existing infrastructure?"
- "Why does Terraform want to CREATE resources when state is lost?"
- "How would you prevent state loss in production?"

---

## Prerequisites

- Docker Desktop running (for LocalStack) OR AWS account configured (for Real AWS)
- Terraform CLI installed
- You are inside the `scenario-5-state-recovery/` directory

---

## Understanding the Disaster

Here's what happens when state is lost:

```
BEFORE DISASTER:
  main.tf → defines 3 resources
  terraform.tfstate → tracks 3 resources (instance, SG, volume)
  AWS → 3 resources running

  terraform plan → "No changes" (everything matches)

AFTER DISASTER (state deleted):
  main.tf → still defines 3 resources
  terraform.tfstate → GONE / EMPTY
  AWS → 3 resources STILL running

  terraform plan → "3 to add" (Terraform thinks nothing exists!)
  terraform apply → would CREATE DUPLICATES (BAD!)
```

**The fix:** Import each existing resource back into state so Terraform knows about them again.

---

## Step-by-Step Instructions

### Step 1: Navigate to the Scenario Directory

```bash
cd scenario-5-state-recovery
```

### Step 2: Simulate the Disaster

The disaster script creates real resources in AWS, then deletes the state file - leaving "orphaned" resources that Terraform doesn't know about.

```bash
# Make the script executable
chmod +x simulate-disaster.sh

# Run the disaster simulation
./simulate-disaster.sh           # For LocalStack (default)
# OR
./simulate-disaster.sh aws       # For Real AWS
```

**What does `simulate-disaster.sh` do? (Line by line)**

1. **Creates an EC2 instance** using the AWS CLI (not Terraform):
   - Runs `aws ec2 run-instances` to launch a `t2.micro` instance
   - Tags it with `Name=recovery-web-server`
   - This simulates existing production infrastructure

2. **Creates a Security Group** using the AWS CLI:
   - Runs `aws ec2 create-security-group` named `recovery-web-sg`
   - Adds ingress rules for ports 80 (HTTP) and 443 (HTTPS)
   - This simulates the firewall rules protecting the server

3. **Creates an EBS Volume** using the AWS CLI:
   - Runs `aws ec2 create-volume` with 100GB, gp3 type
   - Tags it with `Name=recovery-data-volume`
   - This simulates a data storage volume

4. **Deletes the state file** (`rm -f terraform.tfstate`):
   - This is the "disaster" - Terraform's memory is wiped
   - The resources are still running in AWS, but Terraform doesn't know

5. **Outputs the Resource IDs** and saves them to `resource-ids.txt`:
   - You'll need these IDs to import the resources back

**Save the Resource IDs from the output!** You'll see:
```
Resource IDs to import:
  aws_instance.web       -> i-0abc123def456
  aws_security_group.web -> sg-0def789abc123
  aws_ebs_volume.data    -> vol-0ghi456jkl789
```

### Step 3: See the Problem

```bash
# Initialize Terraform (with an empty state)
terraform init

# See what Terraform THINKS needs to happen
terraform plan
```

**What does `terraform plan` show?**
- **"3 to add"** - Terraform wants to CREATE 3 new resources
- But these resources already exist in AWS!
- If you ran `terraform apply` now, it would try to create duplicates
- This is why we need to import instead

### Step 4: Import the EC2 Instance

```bash
# Import the existing EC2 instance
terraform import aws_instance.web <INSTANCE_ID>
```
*(Replace `<INSTANCE_ID>` with the actual Instance ID from Step 2, like `i-0abc123def456`)*

**What does this command do?**
- `aws_instance.web` - The resource address in your `main.tf` code
- `<INSTANCE_ID>` - The real AWS instance ID (from the disaster script output or `resource-ids.txt`)
- Terraform contacts AWS, reads all the instance's attributes, and stores them in the state file
- Now Terraform "remembers" this instance

### Step 5: Import the Security Group

```bash
# Import the existing security group
terraform import aws_security_group.web <SECURITY_GROUP_ID>
```
*(Replace `<SECURITY_GROUP_ID>` with the actual SG ID from Step 2, like `sg-0def789abc123`)*

**What does this command do?**
- Same concept as Step 4, but for the security group
- Terraform reads the security group's name, description, rules, and tags from AWS
- Stores all attributes in the state file

### Step 6: Import the EBS Volume

```bash
# Import the existing EBS volume
terraform import aws_ebs_volume.data <VOLUME_ID>
```
*(Replace `<VOLUME_ID>` with the actual Volume ID from Step 2, like `vol-0ghi456jkl789`)*

**What does this command do?**
- Same concept - imports the EBS volume into state
- Terraform reads the volume's size, type, availability zone, and tags from AWS

### Step 7: View Imported Attributes

After importing all 3 resources, inspect them to ensure your `main.tf` matches:

```bash
# View each imported resource's attributes
terraform state show aws_instance.web
terraform state show aws_security_group.web
terraform state show aws_ebs_volume.data
```

**What does `terraform state show` tell you?**
- Shows ALL attributes Terraform learned from AWS
- Compare these with your `main.tf` - they should match
- If they don't match, you'll need to update `main.tf` (see Step 8)

### Step 8: Update main.tf if Needed

If `terraform plan` shows changes after import, it means your `main.tf` doesn't perfectly match the actual resources. Common things to fix:

- **`ami`** in `aws_instance.web` - Must match the actual AMI ID from `terraform state show`
- **`availability_zone`** in `aws_ebs_volume.data` - Must match the actual AZ
- **`tags`** - Must match exactly (including capitalization)
- **Security group rules** - ingress/egress rules must match exactly

```bash
# Check what terraform state show reports for each resource
terraform state show aws_instance.web
# Look for: ami = "ami-xxxxxxxx"
# Update main.tf if different
```

### Step 9: Verify Recovery

```bash
# Verify ALL resources are recovered
terraform plan
```

**Expected output:** "No changes. Your infrastructure matches the configuration."

If you see "No changes" - **congratulations!** You've successfully recovered from a state disaster. All 3 resources are back under Terraform management without recreating anything.

If changes still appear, run `terraform state show` for the affected resource and update `main.tf` to match the exact values.

---

## Collecting Evidence

Save proof that you completed this scenario:

```bash
# Create the evidence directory if it doesn't exist
mkdir -p ../evidence

# Save the terraform plan output (proves "No changes" after recovery)
terraform plan -no-color > ../evidence/scenario5-plan.txt

# Save the state list (proves all 3 resources are tracked)
terraform state list > ../evidence/scenario5-state.txt

# Save detailed state for each resource
terraform state show aws_instance.web > ../evidence/scenario5-instance.txt
terraform state show aws_security_group.web > ../evidence/scenario5-sg.txt
terraform state show aws_ebs_volume.data > ../evidence/scenario5-volume.txt
```

**What are these evidence commands doing?**
- Saves plan output proving infrastructure was recovered without changes
- Saves state list proving all 3 resources are tracked in the new state
- Saves detailed attributes for each resource as proof of successful import

---

## Cleanup

### For LocalStack:
```bash
# Destroy all resources
terraform destroy -auto-approve
```

### For Real AWS:
```bash
# IMPORTANT: Destroy resources to stop billing!
terraform destroy -auto-approve
```

**What does `terraform destroy` do here?**
- Since all resources are now in the state (thanks to import), Terraform can destroy them
- Terminates the EC2 instance
- Deletes the security group
- Deletes the EBS volume
- Without the recovery (import), you'd have to manually delete these in the AWS Console!

---

## Self-Reflection Questions

After completing this scenario, take a few minutes to reflect:

1. **What was this scenario about?**
   - What does it mean to "lose" Terraform state?
   - Why is state loss considered a critical incident?
   - What would happen if you ran `terraform apply` with lost state?

2. **What did I learn?**
   - How do you rebuild a state file from existing infrastructure?
   - How many resources did you import, and what types were they?
   - What information do you need to import a resource? (Resource type, name, and AWS ID)
   - Why might you need to update `main.tf` after importing?

3. **Did I collect evidence?**
   - Did I save the plan output showing "No changes" after recovery?
   - Did I save the state list showing all 3 recovered resources?

4. **Could I do this in a real emergency?**
   - How would you find the Resource IDs of existing resources in AWS without a script?
     - `aws ec2 describe-instances`, `aws ec2 describe-security-groups`, `aws ec2 describe-volumes`
   - What if you had 50 resources to import instead of 3?
   - How long would this take for a production environment with hundreds of resources?

5. **How would you PREVENT this in production?**
   - Enable S3 versioning on the state bucket (recover previous versions)
   - Enable MFA Delete on the state bucket (require multi-factor auth to delete)
   - Use DynamoDB locking (prevent concurrent writes)
   - Set up regular state backups (`terraform state pull > backup.json`)
   - Use IAM policies to restrict who can delete the state bucket
   - Enable S3 Object Lock for compliance

**Write a brief report** in `../evidence/my-learning-report.md` documenting your answers.

---

## Success Criteria

- [ ] Disaster simulated - resources exist but state is gone (Step 2)
- [ ] `terraform plan` shows "3 to add" before import (Step 3)
- [ ] All 3 resources imported (`aws_instance.web`, `aws_security_group.web`, `aws_ebs_volume.data`) (Steps 4-6)
- [ ] `terraform state list` shows all 3 resources (Step 7)
- [ ] `main.tf` updated if needed to match imported attributes (Step 8)
- [ ] `terraform plan` shows "No changes" (Step 9)
- [ ] Evidence files saved in `../evidence/` directory

---

## Tips

1. **Forgot the Resource IDs?** Check `resource-ids.txt` in this directory - the script saved them
2. **Plan shows changes after import?** Run `terraform state show <resource>` and copy the exact attribute values to `main.tf`
3. **Import failed?** Make sure the resource address matches your `main.tf` exactly (e.g., `aws_instance.web` not `aws_instance.server`)
4. **Want to start over?** Destroy resources (`terraform destroy` if state exists, or manually via AWS Console/CLI), delete `terraform.tfstate`, and re-run `simulate-disaster.sh`

---

## Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| "Resource already exists in state" | You imported the same resource twice | `terraform state rm <resource>` then re-import |
| "Plan shows changes after import" | main.tf doesn't match actual attributes | Run `terraform state show` and copy exact values to main.tf |
| "Cannot find resource" | Wrong resource ID | Check `resource-ids.txt` for correct IDs |
| "Resource not found in configuration" | Resource block missing from main.tf | Ensure `main.tf` has all 3 resource blocks |
| "InvalidAMIID" | AMI ID in main.tf doesn't match | Get correct AMI from `terraform state show aws_instance.web` |
