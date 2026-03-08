# 100 Days Challenges - Project Documentation

## Overview
This repository contains solutions and exercises for KodeKloud's 100 Days challenges, completed by the DevOps team. The repo is organized into separate challenge tracks.

## Project Structure
```
100-days-aws/
├── week01/          # Days 1-5: Key pairs, security groups, subnets, S3, volumes
├── week02/          # Days 6-10: EC2 instances, instance management, Elastic IPs
├── week03/          # Days 11-15: Network interfaces, volumes, AMIs, snapshots
├── week04/          # Days 16-20: IAM users, groups, policies, roles
├── week05/          # Days 21-25: EC2 with EIP, SSH access, S3 sync, ALB, CloudWatch
├── week06/          # Days 26-30: Nginx, public VPC, ECR, VPC peering, NAT instances
├── week07/          # Days 31-35: RDS, advanced topics
├── week08/          # Days 36-40: S3 lifecycle, CloudFront, static websites, troubleshooting
├── week09/          # Days 41-45: KMS, DynamoDB, EKS, Auto Scaling, NAT Gateway
├── week10/          # Days 46-50: Lambda, SQS/SNS, CloudFormation, VPC peering, storage
├── template.md      # Standard template for all day files
└── README.md        # Project readme

100-days-devops/
├── template.md      # Standard template for all day files
└── README.md        # Project readme
```

## Day File Format
All day files must follow the template structure in the respective `template.md`:

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
1. Ensure the relevant CLI tools are configured with appropriate credentials
2. Copy the code block from the Solution section
3. Paste into terminal (commands are designed for copy-paste execution)
4. Run the Validate section to confirm success

## Testing
Test scripts are located in the same week directory as the day file:
- Format: `dayXX-test.sh`
- Run with: `bash 100-days-aws/weekXX/dayXX-test.sh` or `bash 100-days-devops/weekXX/dayXX-test.sh`

## AWS Region
Unless otherwise specified, all AWS resources are created in `us-east-1`.
