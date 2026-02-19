# 100 Days of AWS - Project Documentation

## Overview
This repository contains solutions and exercises for KodeKloud's 50 Days of AWS challenge, completed by the DevOps team. Each day's task focuses on practical AWS CLI skills covering EC2, IAM, S3, VPC, RDS, and other core AWS services.

## Project Structure
```
100-days-aws/
├── week01/          # Days 1-5: Key pairs, security groups, subnets, S3, volumes
├── week02/          # Days 6-10: EC2 instances, instance management, Elastic IPs
├── week03/          # Days 11-15: Network interfaces, volumes, AMIs, snapshots
├── week04/          # Days 16-20: IAM users, groups, policies, roles
├── week05/          # Days 21-25: EC2 with EIP, SSH access, S3 sync, ALB, CloudWatch
├── week06/          # Days 26-30: Nginx, public VPC, ECR, VPC peering, NAT instances
├── week07/          # Days 31+: RDS, advanced topics
├── template.md      # Standard template for all day files
└── README.md        # Project readme
```

## Day File Format
All day files must follow the template structure in `template.md`:

### Required Sections
1. **Title**: `# Day XX - Task Title`
2. **Task**: Description of the requirements
3. **Help**: AWS CLI help commands for reference
4. **Solution**: Working bash commands inside `<details>` tags
5. **Validate**: Commands to verify the solution inside `<details>` tags

### Code Guidelines
- All variables should be defined at the top of code blocks
- Use double quotes for variable expansion: `"$variable"`
- Variable names in the solution MUST match the requirements in the Task section
- Include `read -r` pattern for capturing AWS CLI output
- Always use `--output text` for scripted queries
- Add descriptive `&& echo` statements for debugging

### Validation Pattern
```bash
# Define expected values (must match Task requirements)
expected_variable=value

# Query AWS resources
actual_value=$(aws ... --query "..." --output text) && echo "Value: $actual_value"

# Validation checks
valid=false
[[ "$actual_value" == "$expected_variable" ]] && valid=true

# Output results with success/fail messages
if [[ "$valid" == true ]]; then
  echo "✓ Success"
else
  echo "✗ Fail"
  echo "  Expected: $expected_variable"
  echo "  Got: $actual_value"
fi
```

## Common Issues to Avoid
- Single quotes prevent variable expansion: `'$var'` ❌ vs `"$var"` ✓
- Mismatched variable names between Task and Solution sections
- Template placeholder code left in Validate sections
- Typos in AWS CLI commands (`describe-omething` vs `describe-something`)
- Inconsistent naming conventions within the same file

## Running Solutions
1. Ensure AWS CLI is configured with appropriate credentials
2. Copy the code block from the Solution section
3. Paste into terminal (commands are designed for copy-paste execution)
4. Run the Validate section to confirm success

## Testing
Test scripts are located in the same week directory as the day file:
- Format: `dayXX-test.sh`
- Run with: `bash weekXX/dayXX-test.sh`

## AWS Region
Unless otherwise specified, all resources are created in `us-east-1`.
