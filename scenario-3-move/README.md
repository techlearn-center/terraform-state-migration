# Scenario 3: Move Resources Between State Files

## What is This Scenario About?

**The Problem:** Your Terraform project has grown too large. It started as a single project managing a web server and a database server, but now it has hundreds of resources. Every `terraform plan` takes forever, and a change to the web server risks accidentally affecting the database. You need to split the project into two: one for web resources and one for database resources.

**The Solution:** Use `terraform state mv` to move resources from one state file to another without destroying or recreating them. The actual servers in AWS are untouched - you're just reorganizing how Terraform tracks them.

**Real-World Example:** A company's monolithic Terraform codebase has 500+ resources. They need to split it into separate projects by team: the Platform team manages networking, the App team manages compute, and the Data team manages databases. Each team needs their own state file to work independently.

---

## Learning Objectives

By completing this scenario, you will:

- [ ] Understand why splitting state files is important for large projects
- [ ] Know how to use `terraform state mv` to move resources between state files
- [ ] Understand the `-state-out` flag for targeting a different state file
- [ ] Know that you must also update the Terraform code (main.tf) in both projects
- [ ] Understand that moving state doesn't affect actual infrastructure

**After this scenario, you should be able to answer:**
- "What does `terraform state mv` do and when would you use it?"
- "What happens to the actual resources when you move them between state files?"
- "After moving state, why do you need to update main.tf in both projects?"

---

## Prerequisites

- Docker Desktop running (for LocalStack) OR AWS account configured (for Real AWS)
- Terraform CLI installed
- You are inside the `scenario-3-move/` directory

---

## Understanding the Project Structure

This scenario has two sub-directories:

```
scenario-3-move/
├── old-project/        # The monolithic project (has BOTH web and db resources)
│   └── main.tf         # Contains web AND database resource definitions
├── new-project/        # The new project (database resources will move here)
│   └── main.tf         # Has commented-out database resource definitions
└── move-resources.sh   # Helper script (optional - you can do it manually)
```

**The goal:** Move `aws_instance.db` and `aws_security_group.db` from `old-project` to `new-project`.

---

## Step-by-Step Instructions

### Step 1: Navigate to the Old Project

```bash
cd scenario-3-move/old-project
```

### Step 2: Initialize and Create All Resources

```bash
# Download providers and set up local state
terraform init

# Create ALL resources (both web and database)
terraform apply -auto-approve
```

**What does this do?**
- Creates 4 resources: `aws_instance.web`, `aws_instance.db`, `aws_security_group.web`, `aws_security_group.db`
- All 4 are tracked in `old-project/terraform.tfstate`
- This simulates the "too-big monolithic project"

### Step 3: Verify All Resources Exist

```bash
# List all resources in the old project state
terraform state list
```

**Expected output:**
```
aws_instance.db
aws_instance.web
aws_security_group.db
aws_security_group.web
```

All 4 resources are in a single state file. That's the problem we're going to fix.

### Step 4: Initialize the New Project

```bash
# Go to the new project directory
cd ../new-project

# Initialize Terraform (creates an empty state file)
terraform init

# Go back to old-project (we need to run the move commands from here)
cd ../old-project
```

**What does `terraform init` do in new-project?**
- Creates an empty state file in `new-project/`
- This is where the database resources will be moved TO

### Step 5: Move the Database Security Group

```bash
# Move the database security group from old-project to new-project
terraform state mv \
  -state-out=../new-project/terraform.tfstate \
  aws_security_group.db aws_security_group.db
```

**Breaking down this command:**
- `terraform state mv` - The command to move a resource in state
- `-state-out=../new-project/terraform.tfstate` - Where to move it TO (the new project's state file)
- First `aws_security_group.db` - The resource address in the SOURCE state (old-project)
- Second `aws_security_group.db` - The resource address in the DESTINATION state (new-project). Same name here, but you could rename it if needed.

**What happens behind the scenes:**
- Terraform reads the resource data from `old-project/terraform.tfstate`
- Writes that data into `new-project/terraform.tfstate`
- Removes the resource from `old-project/terraform.tfstate`
- **The actual security group in AWS is completely untouched!** This is purely a bookkeeping change.

### Step 6: Move the Database Instance

```bash
# Move the database instance from old-project to new-project
terraform state mv \
  -state-out=../new-project/terraform.tfstate \
  aws_instance.db aws_instance.db
```

**Why move the security group first?**
- The database instance references the security group
- Moving dependencies first prevents potential issues
- In practice, order usually doesn't matter for state moves, but it's a good habit

### Step 7: Verify the Move

```bash
# Check what's left in old-project (should only be web resources)
terraform state list
```

**Expected output:**
```
aws_instance.web
aws_security_group.web
```

```bash
# Check what's now in new-project (should have database resources)
cd ../new-project
terraform state list
```

**Expected output:**
```
aws_instance.db
aws_security_group.db
```

### Step 8: Update the Code in BOTH Projects

**This is the step people forget!** Moving state only changes WHERE Terraform tracks the resources. You must also update the code (`main.tf`) in both projects so the configuration matches the state.

**In `old-project/main.tf`:**
- Comment out or remove the database resource blocks (`aws_security_group.db` and `aws_instance.db`)
- Keep the web resource blocks
- Comment out or remove the database outputs (`db_instance_id`, `db_sg_id`)

**In `new-project/main.tf`:**
- Uncomment the database resource blocks (they're already provided as comments)
- Uncomment the database outputs

### Step 9: Verify Both Projects - Must Show "No Changes"

```bash
# Verify old-project
cd ../old-project
terraform plan
# Should show: "No changes"

# Verify new-project
cd ../new-project
terraform plan
# Should show: "No changes"
```

**What does `terraform plan` verify here?**
- For old-project: The code only defines web resources, and the state only has web resources. They match.
- For new-project: The code defines database resources, and the state has database resources. They match.
- If either shows changes, your `main.tf` doesn't match the state - go back and fix the code.

---

## Collecting Evidence

Save proof that you completed this scenario:

```bash
# From the scenario-3-move directory
cd ..  # if you're in old-project or new-project

# Create the evidence directory if it doesn't exist
mkdir -p ../evidence

# Save old-project state list (proves web resources remain)
cd old-project
terraform state list > ../../evidence/scenario3-old-state.txt
terraform plan -no-color > ../../evidence/scenario3-old-plan.txt

# Save new-project state list (proves database resources moved)
cd ../new-project
terraform state list > ../../evidence/scenario3-new-state.txt
terraform plan -no-color > ../../evidence/scenario3-new-plan.txt
```

**What are these evidence commands doing?**
- Saves the state list from both projects to prove the resources were split correctly
- Saves the plan output from both projects to prove "No changes" in each

---

## Cleanup

### For LocalStack:
```bash
# Destroy resources in BOTH projects
cd old-project
terraform destroy -auto-approve

cd ../new-project
terraform destroy -auto-approve
```

### For Real AWS:
```bash
# IMPORTANT: Destroy in BOTH projects to stop all billing
cd old-project
terraform destroy -auto-approve

cd ../new-project
terraform destroy -auto-approve
```

**Why destroy in both projects?**
- After the move, each project only knows about its own resources
- `old-project` will destroy the web resources
- `new-project` will destroy the database resources
- If you only destroy one, the other resources keep running (and costing money!)

---

## Self-Reflection Questions

After completing this scenario, take a few minutes to reflect:

1. **What was this scenario about?**
   - Why would a team need to split a Terraform project?
   - What are the risks of having too many resources in one state file?

2. **What did I learn?**
   - What does `terraform state mv` do?
   - What does the `-state-out` flag specify?
   - Why do you need to update `main.tf` in BOTH projects after moving state?
   - Do the actual cloud resources get affected when you move state?

3. **Did I collect evidence?**
   - Did I save state lists from both projects?
   - Did I save plan outputs showing "No changes" in both?

4. **Could I explain this to someone else?**
   - Could you explain the difference between moving state vs. destroying and recreating?
   - What would happen if you moved state but forgot to update `main.tf`?

5. **What would be different in production?**
   - How would you plan a state split with hundreds of resources?
   - Would you do this during business hours or during a maintenance window?
   - What backup steps would you take before moving resources?

**Write a brief report** in `../evidence/my-learning-report.md` documenting your answers.

---

## Success Criteria

- [ ] All 4 resources created in old-project (Step 2)
- [ ] Database resources moved to new-project state (Steps 5-6)
- [ ] old-project state shows only web resources (Step 7)
- [ ] new-project state shows only database resources (Step 7)
- [ ] main.tf updated in both projects (Step 8)
- [ ] `terraform plan` shows "No changes" in BOTH projects (Step 9)
- [ ] Evidence files saved in `../evidence/` directory

---

## Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| "Resource not found in state" | Wrong resource name or already moved | Check `terraform state list` for exact names |
| "State file does not exist" for new-project | Didn't run `terraform init` in new-project | Run `terraform init` in new-project first |
| Plan shows "will be created" in new-project | main.tf code not uncommented | Uncomment the database resource blocks in new-project/main.tf |
| Plan shows "will be destroyed" in old-project | main.tf code not commented out | Comment out the database resource blocks in old-project/main.tf |
| "Error writing state" | Permission issues or path wrong | Check the `-state-out` path is correct and directory exists |
