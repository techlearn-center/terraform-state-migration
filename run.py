#!/usr/bin/env python3
"""
Terraform State Migration Challenge - Grading Script
=====================================================

This script grades your work in THREE ways:

1. FILE CHECK (Default)
   - Checks if required files exist
   - Checks if files contain correct configurations
   - Works offline, no Terraform/AWS needed

2. LIVE VERIFICATION (--verify flag)
   - Actually runs terraform commands
   - Verifies state migration worked
   - Requires Terraform CLI installed

3. EVIDENCE CHECK (--evidence flag)
   - Checks for screenshot/output evidence files
   - Used for Real AWS submissions
   - Proves you completed the work

Usage:
    python run.py                    # Basic file checks only
    python run.py --verify           # Run live Terraform verification
    python run.py --evidence         # Check for evidence files
    python run.py --verify --evidence # Full verification
    python run.py --mode localstack  # Verify LocalStack setup
    python run.py --mode aws         # Verify Real AWS setup
"""

import os
import re
import sys
import subprocess
import argparse
from pathlib import Path

# ANSI colors
GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
BLUE = "\033[94m"
CYAN = "\033[96m"
RESET = "\033[0m"
BOLD = "\033[1m"


def print_header(text):
    print(f"\n{BOLD}{BLUE}{'=' * 65}")
    print(f"  {text}")
    print(f"{'=' * 65}{RESET}\n")


def print_section(text):
    print(f"\n{BOLD}{CYAN}▶ {text}{RESET}")
    print("-" * 50)


def check_passed(message):
    print(f"  {GREEN}✓{RESET} {message}")
    return True


def check_failed(message, hint=""):
    print(f"  {RED}✗{RESET} {message}")
    if hint:
        print(f"    {YELLOW}↳ Hint: {hint}{RESET}")
    return False


def check_info(message):
    print(f"  {BLUE}ℹ{RESET} {message}")


def check_file_exists(filepath):
    """Check if a file exists."""
    return os.path.exists(filepath)


def check_file_contains(filepath, pattern, is_regex=False):
    """Check if a file contains a pattern (ignoring comments)."""
    if not os.path.exists(filepath):
        return False
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
            # Skip commented lines for terraform files
            if filepath.endswith('.tf'):
                lines = content.split('\n')
                uncommented = '\n'.join(
                    line for line in lines
                    if not line.strip().startswith('#')
                )
                content = uncommented
            if is_regex:
                return bool(re.search(pattern, content))
            return pattern in content
    except Exception:
        return False


def run_command(cmd, cwd=None, timeout=60):
    """Run a command and return (success, output)."""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=timeout
        )
        return result.returncode == 0, result.stdout + result.stderr
    except subprocess.TimeoutExpired:
        return False, "Command timed out"
    except Exception as e:
        return False, str(e)


def check_terraform_installed():
    """Check if Terraform CLI is installed."""
    success, output = run_command("terraform version")
    return success


def check_aws_configured():
    """Check if AWS CLI is configured."""
    success, output = run_command("aws sts get-caller-identity")
    return success


def check_docker_running():
    """Check if Docker is running."""
    success, output = run_command("docker ps")
    return success


def check_localstack_running():
    """Check if LocalStack is running."""
    success, output = run_command("docker ps --filter name=localstack --format '{{.Names}}'")
    return success and "localstack" in output.lower()


# =============================================================================
# FILE-BASED CHECKS
# =============================================================================

def grade_scenario_1_files():
    """Grade Scenario 1: Local to Remote - File checks only."""
    print_section("Scenario 1: Local to Remote Migration (Files)")

    checks = []
    base = "scenario-1-local-to-remote"

    # Check backend.tf exists
    if check_file_exists(f'{base}/backend.tf'):
        checks.append(check_passed("backend.tf exists"))
    else:
        checks.append(check_failed("backend.tf exists",
            "Create backend.tf with S3 backend configuration"))
        return checks

    # Check S3 backend configured
    if check_file_contains(f'{base}/backend.tf', 'backend "s3"'):
        checks.append(check_passed("S3 backend configured"))
    else:
        checks.append(check_failed("S3 backend configured",
            "Add: terraform { backend \"s3\" { ... } }"))

    # Check bucket specified
    if check_file_contains(f'{base}/backend.tf', 'bucket'):
        checks.append(check_passed("Bucket specified in backend"))
    else:
        checks.append(check_failed("Bucket specified",
            "Add: bucket = \"your-bucket-name\""))

    # Check key specified
    if check_file_contains(f'{base}/backend.tf', 'key'):
        checks.append(check_passed("Key (state path) specified"))
    else:
        checks.append(check_failed("Key specified",
            "Add: key = \"path/to/terraform.tfstate\""))

    # Check region specified
    if check_file_contains(f'{base}/backend.tf', 'region'):
        checks.append(check_passed("Region specified"))
    else:
        checks.append(check_failed("Region specified",
            "Add: region = \"us-east-1\""))

    # Check create-bucket.sh exists
    if check_file_exists(f'{base}/create-bucket.sh'):
        checks.append(check_passed("create-bucket.sh exists"))
    else:
        checks.append(check_failed("create-bucket.sh exists",
            "Create script to create the S3 bucket"))

    return checks


def grade_scenario_2_files():
    """Grade Scenario 2: Import - File checks only."""
    print_section("Scenario 2: Import Existing Resources (Files)")

    checks = []
    base = "scenario-2-import"

    # Check main.tf exists
    if check_file_exists(f'{base}/main.tf'):
        checks.append(check_passed("main.tf exists"))
    else:
        checks.append(check_failed("main.tf exists"))
        return checks

    # Check aws_instance resource defined
    if check_file_contains(f'{base}/main.tf', 'resource "aws_instance"'):
        checks.append(check_passed("aws_instance resource defined"))
    else:
        checks.append(check_failed("aws_instance resource defined",
            "Add: resource \"aws_instance\" \"imported\" { ... }"))

    # Check resource named correctly
    if check_file_contains(f'{base}/main.tf', 'imported'):
        checks.append(check_passed("Resource named 'imported'"))
    else:
        checks.append(check_failed("Resource named 'imported'",
            "Name your resource: aws_instance.imported"))

    # Check setup.sh exists
    if check_file_exists(f'{base}/setup.sh'):
        checks.append(check_passed("setup.sh exists"))
    else:
        checks.append(check_failed("setup.sh exists"))

    return checks


def grade_scenario_3_files():
    """Grade Scenario 3: Move Resources - File checks only."""
    print_section("Scenario 3: Move Resources Between States (Files)")

    checks = []

    # Check old-project exists
    if check_file_exists('scenario-3-move/old-project/main.tf'):
        checks.append(check_passed("old-project/main.tf exists"))
    else:
        checks.append(check_failed("old-project/main.tf exists"))

    # Check new-project exists
    if check_file_exists('scenario-3-move/new-project/main.tf'):
        checks.append(check_passed("new-project/main.tf exists"))
    else:
        checks.append(check_failed("new-project/main.tf exists"))

    # Check old-project has resources
    if check_file_contains('scenario-3-move/old-project/main.tf', 'aws_instance'):
        checks.append(check_passed("old-project has aws_instance"))
    else:
        checks.append(check_failed("old-project has aws_instance"))

    # Check move script exists
    if check_file_exists('scenario-3-move/move-resources.sh'):
        checks.append(check_passed("move-resources.sh exists"))
    else:
        checks.append(check_failed("move-resources.sh exists",
            "Create script with terraform state mv commands"))

    return checks


# =============================================================================
# LIVE TERRAFORM VERIFICATION
# =============================================================================

def verify_scenario_1_live(mode="localstack"):
    """Verify Scenario 1 with live Terraform commands."""
    print_section(f"Scenario 1: Live Verification ({mode.upper()})")

    checks = []
    base = "scenario-1-local-to-remote"

    # Check terraform init works
    check_info("Running terraform init...")
    success, output = run_command("terraform init -input=false", cwd=base, timeout=120)
    if success:
        checks.append(check_passed("terraform init succeeded"))
    else:
        checks.append(check_failed("terraform init succeeded",
            "Check your backend configuration"))
        return checks

    # Check terraform plan shows no changes (state migrated correctly)
    check_info("Running terraform plan...")
    success, output = run_command("terraform plan -detailed-exitcode", cwd=base, timeout=120)

    # Exit code 0 = no changes, 1 = error, 2 = changes pending
    if "No changes" in output or success:
        checks.append(check_passed("terraform plan shows no changes (state migrated!)"))
    else:
        checks.append(check_failed("terraform plan shows no changes",
            "State might not be migrated correctly"))

    # Check state list shows resources
    check_info("Checking state list...")
    success, output = run_command("terraform state list", cwd=base, timeout=30)
    if success and "aws_" in output:
        checks.append(check_passed(f"State contains resources"))
        for line in output.strip().split('\n'):
            if line.strip():
                check_info(f"  Found: {line.strip()}")
    else:
        checks.append(check_failed("State contains resources"))

    # For LocalStack, verify S3 bucket has state file
    if mode == "localstack":
        check_info("Checking S3 bucket for state file...")
        success, output = run_command(
            "aws s3 ls s3://terraform-state-migration-demo/ --endpoint-url http://localhost:4566 --recursive",
            timeout=30
        )
        if success and "terraform.tfstate" in output:
            checks.append(check_passed("State file exists in S3 bucket"))
        else:
            checks.append(check_failed("State file exists in S3 bucket",
                "Run: terraform init -migrate-state"))

    return checks


def verify_scenario_2_live(mode="localstack"):
    """Verify Scenario 2 with live Terraform commands."""
    print_section(f"Scenario 2: Live Verification ({mode.upper()})")

    checks = []
    base = "scenario-2-import"

    # Check terraform init works
    check_info("Running terraform init...")
    success, output = run_command("terraform init -input=false", cwd=base, timeout=120)
    if success:
        checks.append(check_passed("terraform init succeeded"))
    else:
        checks.append(check_failed("terraform init succeeded"))
        return checks

    # Check state has imported resource
    check_info("Checking for imported resource...")
    success, output = run_command("terraform state list", cwd=base, timeout=30)
    if success and "imported" in output:
        checks.append(check_passed("Imported resource exists in state"))
    else:
        checks.append(check_failed("Imported resource exists in state",
            "Run: terraform import aws_instance.imported <instance-id>"))
        return checks

    # Check terraform plan shows no changes
    check_info("Running terraform plan...")
    success, output = run_command("terraform plan -detailed-exitcode", cwd=base, timeout=120)
    if "No changes" in output or success:
        checks.append(check_passed("terraform plan shows no changes (import complete!)"))
    else:
        checks.append(check_failed("terraform plan shows no changes",
            "Update main.tf to match the imported resource attributes"))

    return checks


# =============================================================================
# EVIDENCE FILE CHECKS
# =============================================================================

def grade_evidence_files():
    """Check for evidence files (screenshots, output logs)."""
    print_section("Evidence Files (For Real AWS Submissions)")

    checks = []
    evidence_dir = "evidence"

    # Check evidence directory exists
    if not os.path.exists(evidence_dir):
        check_info(f"No evidence/ directory found")
        check_info(f"Create it with: mkdir evidence")
        check_info(f"Then add your verification outputs")
        return []

    # Check for plan output
    plan_files = list(Path(evidence_dir).glob("*plan*"))
    if plan_files:
        checks.append(check_passed(f"Plan output found: {plan_files[0].name}"))
    else:
        checks.append(check_failed("Plan output (e.g., scenario1-plan.txt)",
            "Run: terraform plan > evidence/scenario1-plan.txt"))

    # Check for state list output
    state_files = list(Path(evidence_dir).glob("*state*"))
    if state_files:
        checks.append(check_passed(f"State output found: {state_files[0].name}"))
    else:
        checks.append(check_failed("State list output (e.g., scenario1-state.txt)",
            "Run: terraform state list > evidence/scenario1-state.txt"))

    # Check for S3 verification
    s3_files = list(Path(evidence_dir).glob("*s3*"))
    if s3_files:
        checks.append(check_passed(f"S3 verification found: {s3_files[0].name}"))
    else:
        checks.append(check_failed("S3 bucket listing (e.g., s3-state-proof.txt)",
            "Run: aws s3 ls s3://your-bucket/ --recursive > evidence/s3-state-proof.txt"))

    # Check for screenshots
    screenshot_files = list(Path(evidence_dir).glob("*.png")) + \
                      list(Path(evidence_dir).glob("*.jpg")) + \
                      list(Path(evidence_dir).glob("*.jpeg"))
    if screenshot_files:
        checks.append(check_passed(f"Screenshots found: {len(screenshot_files)} file(s)"))
        for f in screenshot_files[:3]:  # Show first 3
            check_info(f"  - {f.name}")
    else:
        check_info("No screenshots found (optional but recommended)")

    # Check for AWS identity
    identity_files = list(Path(evidence_dir).glob("*identity*")) + \
                    list(Path(evidence_dir).glob("*account*"))
    if identity_files:
        checks.append(check_passed(f"AWS identity proof found"))
    else:
        checks.append(check_failed("AWS identity (proves you used real AWS)",
            "Run: aws sts get-caller-identity > evidence/aws-identity.txt"))

    return checks


# =============================================================================
# MAIN GRADING LOGIC
# =============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="Grade Terraform State Migration Challenge",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python run.py                     # Basic file checks
  python run.py --verify            # Live Terraform verification
  python run.py --evidence          # Check evidence files
  python run.py --mode aws          # Check Real AWS setup
  python run.py --mode localstack   # Check LocalStack setup
  python run.py --all               # Run all checks
        """
    )
    parser.add_argument('--verify', action='store_true',
                       help='Run live Terraform verification')
    parser.add_argument('--evidence', action='store_true',
                       help='Check for evidence files')
    parser.add_argument('--mode', choices=['localstack', 'aws'], default='localstack',
                       help='Verification mode (default: localstack)')
    parser.add_argument('--all', action='store_true',
                       help='Run all checks')

    args = parser.parse_args()

    if args.all:
        args.verify = True
        args.evidence = True

    print_header("TERRAFORM STATE MIGRATION - GRADING SCRIPT")

    # Environment checks
    print_section("Environment Check")

    all_checks = []

    # Check Terraform
    if check_terraform_installed():
        check_passed("Terraform CLI installed")
    else:
        check_failed("Terraform CLI installed",
            "Install from: https://terraform.io/downloads")

    # Mode-specific checks
    if args.mode == "localstack":
        if check_docker_running():
            check_passed("Docker is running")
            if check_localstack_running():
                check_passed("LocalStack container is running")
            else:
                check_failed("LocalStack container running",
                    "Run: docker-compose up -d")
        else:
            check_failed("Docker is running",
                "Start Docker Desktop")
    else:  # aws mode
        if check_aws_configured():
            check_passed("AWS CLI configured")
        else:
            check_failed("AWS CLI configured",
                "Run: aws configure")

    # =================================
    # FILE-BASED CHECKS (Always run)
    # =================================

    print_header("FILE-BASED CHECKS")

    all_checks.extend(grade_scenario_1_files())
    all_checks.extend(grade_scenario_2_files())
    all_checks.extend(grade_scenario_3_files())

    # =================================
    # LIVE VERIFICATION (Optional)
    # =================================

    if args.verify:
        print_header(f"LIVE VERIFICATION ({args.mode.upper()})")

        if args.mode == "localstack" and not check_localstack_running():
            print(f"\n{YELLOW}⚠ LocalStack not running. Start with: docker-compose up -d{RESET}")
        elif args.mode == "aws" and not check_aws_configured():
            print(f"\n{YELLOW}⚠ AWS not configured. Run: aws configure{RESET}")
        else:
            all_checks.extend(verify_scenario_1_live(args.mode))
            all_checks.extend(verify_scenario_2_live(args.mode))

    # =================================
    # EVIDENCE CHECKS (Optional)
    # =================================

    if args.evidence:
        print_header("EVIDENCE FILE CHECKS")
        evidence_checks = grade_evidence_files()
        all_checks.extend(evidence_checks)

    # =================================
    # FINAL SCORE
    # =================================

    print_header("FINAL SCORE")

    passed = sum(all_checks)
    total = len(all_checks)
    percentage = (passed / total) * 100 if total > 0 else 0

    print(f"  Checks Passed: {GREEN}{passed}{RESET} / {total}")
    print(f"  Score: {BOLD}{percentage:.1f}%{RESET}")

    # Progress bar
    bar_width = 40
    filled = int(bar_width * passed / total) if total > 0 else 0
    bar = "█" * filled + "░" * (bar_width - filled)

    if percentage >= 80:
        color = GREEN
        grade = "A - Excellent!"
    elif percentage >= 60:
        color = YELLOW
        grade = "B - Good Progress"
    else:
        color = RED
        grade = "C - Keep Working"

    print(f"\n  [{color}{bar}{RESET}]")
    print(f"\n  Grade: {BOLD}{color}{grade}{RESET}")

    # Status message
    if percentage >= 80:
        print(f"\n  {GREEN}🎉 Challenge Complete! You've mastered State Migration!{RESET}")
    elif percentage >= 60:
        print(f"\n  {YELLOW}Good progress! Complete remaining tasks.{RESET}")
    else:
        print(f"\n  {YELLOW}Keep working. Check the hints above.{RESET}")

    # Suggestions
    if not args.verify:
        print(f"\n  {BLUE}💡 Run with --verify for live Terraform checks{RESET}")
    if not args.evidence:
        print(f"  {BLUE}💡 Run with --evidence to check proof files{RESET}")
    if args.mode == "localstack":
        print(f"  {BLUE}💡 Using Real AWS? Run with --mode aws{RESET}")

    print()

    return 0 if percentage >= 60 else 1


if __name__ == "__main__":
    sys.exit(main())
