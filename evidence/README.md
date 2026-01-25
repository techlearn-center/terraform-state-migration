# Evidence Directory

This folder is for **Real AWS users** to store proof of completion.

## Required Files

After completing each scenario, run these commands to collect evidence:

### Scenario 1: State Migration
```bash
cd scenario-1-local-to-remote
terraform plan -no-color > ../evidence/scenario1-plan.txt
terraform state list > ../evidence/scenario1-state.txt
aws s3 ls s3://YOUR-BUCKET/ --recursive > ../evidence/s3-state-proof.txt
```

### Scenario 2: Import
```bash
cd scenario-2-import
terraform plan -no-color > ../evidence/scenario2-plan.txt
terraform state show aws_instance.imported > ../evidence/scenario2-import.txt
```

### Scenario 3: Move Resources
```bash
cd scenario-3-move/old-project
terraform state list > ../../evidence/scenario3-old-state.txt
cd ../new-project
terraform state list > ../../evidence/scenario3-new-state.txt
```

### AWS Identity (Required)
```bash
aws sts get-caller-identity > evidence/aws-identity.txt
```

## Checklist

- [ ] `scenario1-plan.txt` - Shows "No changes" after migration
- [ ] `scenario1-state.txt` - Shows resources in state
- [ ] `s3-state-proof.txt` - Shows state file in S3 bucket
- [ ] `scenario2-plan.txt` - Shows "No changes" after import
- [ ] `scenario2-import.txt` - Shows imported resource details
- [ ] `scenario3-old-state.txt` - Shows remaining resources in old project
- [ ] `scenario3-new-state.txt` - Shows moved resources in new project
- [ ] `aws-identity.txt` - Proves you used real AWS account

## Optional Screenshots

You can also add screenshots (PNG/JPG) of:
- AWS S3 Console showing your state bucket
- AWS EC2 Console showing imported instance
- Terminal showing terraform commands

Name them like:
- `screenshot-s3-bucket.png`
- `screenshot-ec2-instance.png`

## Verify Evidence

Run this to check your evidence files:
```bash
python run.py --evidence
```
