# Scenario 2: Import Existing Resources

## What is This Scenario About?

**The Problem:** Someone on your team created an EC2 instance manually through the AWS Console (the web interface) instead of using Terraform. The server is running and serving traffic, but Terraform doesn't know it exists. If you run `terraform apply` now, Terraform will try to create a **duplicate** server because it has no record of the existing one.

**The Solution:** Use `terraform import` to tell Terraform about the existing resource, bringing it under Terraform management without recreating it.

**Real-World Example:** A new developer joined and created a staging server through the AWS Console during an urgent deployment. Now the team needs to manage it with Terraform like everything else. You can't delete and recreate it because it's already running production traffic.

---

## Learning Objectives

By completing this scenario, you will:

- [ ] Understand why manually-created resources are a problem for Terraform
- [ ] Know how to write an empty resource block for import
- [ ] Be able to use `terraform import` to bring existing resources under management
- [ ] Know how to inspect imported resource attributes with `terraform state show`
- [ ] Be able to update Terraform configuration to match imported state
- [ ] Understand the difference between Instance IDs (`i-xxx`) and AMI IDs (`ami-xxx`)

**After this scenario, you should be able to answer:**
- "What happens if you run `terraform apply` without importing an existing resource?"
- "What is the difference between `terraform import` and `terraform apply`?"
- "Why do you need to update `main.tf` after importing?"

---

## Prerequisites

- Docker Desktop running (for LocalStack) OR AWS account configured (for Real AWS)
- Terraform CLI installed
- You are inside the `scenario-2-import/` directory

---

## Step-by-Step Instructions

### Step 1: Navigate to the Scenario Directory

```bash
cd scenario-2-import
```

### Step 2: Create a Resource "Manually" (Simulating the AWS Console)

The setup script simulates someone creating an EC2 instance through the AWS Console, bypassing Terraform entirely.

```bash
# Make the script executable
chmod +x setup.sh

# Run the script to create a "manually-created" resource
./setup.sh           # For LocalStack (default)
# OR
./setup.sh aws       # For Real AWS
```

**What does `setup.sh` do?**
- Uses the AWS CLI (not Terraform!) to create an EC2 instance directly
- This simulates a human clicking "Launch Instance" in the AWS Console
- Terraform knows nothing about this instance - it's not in any state file
- The script outputs important IDs you'll need - **save them!**

You'll see output like:
```
==============================================
  MANUALLY CREATED RESOURCE
==============================================

Instance ID: i-abc123def456    <-- SAVE THIS (for terraform import)
AMI ID:      ami-12345678      <-- SAVE THIS (for main.tf)
Type:        t2.micro
==============================================
```

**Save both the Instance ID and the AMI ID** - you'll need them in later steps.

### Step 3: Add an Empty Resource Block to main.tf

Before you can import, Terraform needs a "placeholder" in the configuration. Open `main.tf` in your editor and add this at the bottom:

```hcl
resource "aws_instance" "imported" {
}
```

**Why do we need an empty block?**
- `terraform import` maps a real AWS resource to a Terraform configuration block
- The block must exist in your code before import - Terraform needs to know WHERE to store the imported data
- We leave it empty because we don't know the exact attributes yet - we'll fill them in after import

### Step 4: Initialize Terraform

```bash
# Download providers and set up the backend
terraform init
```

**What does `terraform init` do here?**
- Downloads the AWS provider plugin
- Sets up local state (no S3 backend in this scenario)
- The state file starts empty - Terraform doesn't know about any resources

### Step 5: Import the Existing Instance

Use the **Instance ID** from Step 2 (the one starting with `i-`):

```bash
# Tell Terraform about the existing instance
terraform import aws_instance.imported i-abc123def456
```
*(Replace `i-abc123def456` with YOUR actual Instance ID from the setup script output)*

**What does `terraform import` do?**
- `aws_instance.imported` - This is the **Terraform resource address** (the name in your code)
- `i-abc123def456` - This is the **AWS resource ID** (the real instance in AWS)
- The command tells Terraform: "Hey, the instance `i-abc123def456` in AWS is the same thing as `aws_instance.imported` in my code"
- Terraform reads all the instance's attributes from AWS and stores them in the state file
- **Important:** Import only updates the STATE file, not your CODE (main.tf)

### Step 6: View the Imported Attributes

```bash
# Show all attributes Terraform learned about the imported instance
terraform state show aws_instance.imported
```

**What does `terraform state show` do?**
- Reads the state file and displays all attributes for the specified resource
- Shows things like: `ami`, `instance_type`, `tags`, `id`, `vpc_security_group_ids`, etc.
- These are the ACTUAL values from AWS - you need to copy some of them to your `main.tf`

Look for these key values in the output:
- `ami = "ami-xxxxxxxx"` - Copy this AMI ID
- `instance_type = "t2.micro"`
- `tags = { ... }` - Copy the exact tags

### Step 7: Update main.tf to Match the Imported State

Open `main.tf` and replace the empty resource block with the actual values:

```hcl
resource "aws_instance" "imported" {
  ami           = "ami-12345678"  # <-- Use the AMI ID from state show (NOT the Instance ID!)
  instance_type = "t2.micro"

  tags = {
    Name      = "manually-created-instance"
    CreatedBy = "console"
  }
}
```

**CRITICAL: Do NOT confuse Instance ID with AMI ID!**
```
Instance ID: i-abc123def456     <-- Used for: terraform import command
AMI ID:      ami-12345678       <-- Used for: ami field in main.tf

These are completely different things:
- Instance ID = the unique identifier of a running server
- AMI ID = the template/image that was used to create that server
```

### Step 8: Verify - Must Show "No Changes"

```bash
# Verify that your code matches the actual resource
terraform plan
```

**What does `terraform plan` do here?**
- Compares your `main.tf` configuration with the state file
- Compares the state file with the real resource in AWS
- If everything matches: **"No changes. Your infrastructure matches the configuration."**
- If there are differences: it shows what would need to change - go back and fix your `main.tf`

If you see "No changes" - **success!** The manually-created instance is now fully managed by Terraform.

---

## Collecting Evidence

Save proof that you completed this scenario:

```bash
# Create the evidence directory if it doesn't exist
mkdir -p ../evidence

# Save the terraform plan output (proves "No changes" after import)
terraform plan -no-color > ../evidence/scenario2-plan.txt

# Save the imported resource details (proves you successfully imported)
terraform state show aws_instance.imported > ../evidence/scenario2-import.txt

# Save the state list (proves the resource is tracked)
terraform state list > ../evidence/scenario2-state.txt
```

**What are these evidence commands doing?**
- `terraform plan -no-color > file.txt` - Saves plan output to prove "No changes"
- `terraform state show ... > file.txt` - Saves the full resource details from state
- `terraform state list > file.txt` - Lists all tracked resources
- The `>` redirects output to a file instead of the screen

---

## Cleanup

### For LocalStack:
```bash
# Destroy the imported resource
terraform destroy -auto-approve
```

### For Real AWS:
```bash
# Destroy the imported resource (stops billing)
terraform destroy -auto-approve
```

**What does `terraform destroy` do here?**
- Since the instance is now managed by Terraform (thanks to import), Terraform can destroy it
- This terminates the EC2 instance in AWS
- The state file is updated to reflect the resource no longer exists

---

## Self-Reflection Questions

After completing this scenario, take a few minutes to reflect:

1. **What was this scenario about?**
   - Why are manually-created resources a problem?
   - What would happen if you ran `terraform apply` without importing first?

2. **What did I learn?**
   - What is the `terraform import` command and when do you use it?
   - Why do you need to create an empty resource block before importing?
   - Why do you need to update `main.tf` after importing?
   - What is the difference between Instance ID and AMI ID?

3. **Did I collect evidence?**
   - Did I save the plan output showing "No changes"?
   - Did I save the state show output with resource details?

4. **Could I do this again without instructions?**
   - What are the 5 steps of the import workflow? (empty block, import, state show, update code, verify plan)
   - Could I import a different resource type (like a security group or S3 bucket)?

5. **What would be different in production?**
   - How would you find the resource IDs of manually-created resources in a real AWS account?
   - What if the resource has many complex attributes - how would you handle that?
   - Are there tools that automate import configuration generation? (Hint: `terraformer`, `terraform plan -generate-config-out`)

**Write a brief report** in `../evidence/my-learning-report.md` documenting your answers.

---

## Success Criteria

- [ ] Setup script ran successfully, resource created "manually" (Step 2)
- [ ] Empty resource block added to `main.tf` (Step 3)
- [ ] `terraform import` ran successfully (Step 5)
- [ ] `terraform state show` displays imported attributes (Step 6)
- [ ] `main.tf` updated to match imported attributes (Step 7)
- [ ] `terraform plan` shows "No changes" (Step 8)
- [ ] Evidence files saved in `../evidence/` directory

---

## Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| "Resource not found in configuration" | Empty resource block not added to main.tf | Add `resource "aws_instance" "imported" {}` to main.tf |
| "InvalidAMIID.Malformed" | You put Instance ID (i-xxx) in the `ami` field | Use AMI ID (ami-xxx) from `terraform state show` output |
| "Plan shows changes after import" | main.tf doesn't match actual attributes | Run `terraform state show` and copy exact values |
| "Resource already in state" | You ran import twice | Run `terraform state rm aws_instance.imported` then import again |
| "Wrong directory" | Commands run from wrong scenario folder | Make sure you're in `scenario-2-import/` |
