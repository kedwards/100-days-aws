# Day 20: Create IAM Role for EC2 with Policy Attachment

## Task

When establishing infrastructure on the AWS cloud, Identity and Access Management (IAM) is among the first and most critical services to configure. IAM facilitates the creation and management of user accounts, groups, roles, policies, and other access controls. The Nautilus DevOps team is currently in the process of configuring these resources and has outlined the following requirements:

Create an IAM role as below:

1) IAM role name must be iamrole_rose.

2) Entity type must be AWS Service and use case must be EC2.

3) Attach a policy named iampolicy_rose.


## Help

```bash
aws iam create-role help
aws iam get-role help
aws iam list-policies help
aws iam attach-role-policy help
aws iam list-attached-role-policies help
```

<details>
<summary><h2>Solution</h2></summary>


```bash
role_name=iamrole_rose
policy_name=iampolicy_rose

# Create trust policy document
cat > /tmp/trust-policy.json << 'POLICY'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sts:AssumeRole"
      ],
      "Principal": {
        "Service": [
          "ec2.amazonaws.com"
        ]
      }
    }
  ]
}
POLICY

# Create the role
aws iam create-role \
  --role-name "$role_name" \
  --assume-role-policy-document file:///tmp/trust-policy.json

# Get policy ARN
read -r policy_arn < <(aws iam list-policies \
  --query "Policies[?PolicyName=='$policy_name'].Arn" \
  --output text) && echo "Policy ARN: $policy_arn"

# Attach policy to role
aws iam attach-role-policy \
  --role-name "$role_name" \
  --policy-arn "$policy_arn"
```

</details>

<details>
<summary><h2>Validate</h2></summary>


```bash
aws iam list-attached-role-policies --role-name "$role_name" \
  --query "AttachedPolicies[].{PolicyName:PolicyName,PolicyArn:PolicyArn}" \
  --output table
```

```bash
read -r role_arn < <(aws iam get-role --role-name "$role_name" \
  --query "Role.Arn" \
  --output text) && echo "Role ARN: $role_arn"

read -r attached_policy_arn attached_policy_name < <(aws iam list-attached-role-policies \
  --role-name "$role_name" \
  --query "AttachedPolicies[?PolicyName=='$policy_name'].[PolicyArn,PolicyName]" \
  --output text) && echo "Attached policy ARN: $attached_policy_arn, Policy name: $attached_policy_name"

# Check validation
role_exists=false
policy_attached=false
name_valid=false

[[ -n "$role_arn" && "$role_arn" != "None" ]] && role_exists=true
[[ -n "$attached_policy_arn" && "$attached_policy_arn" != "None" ]] && policy_attached=true
[[ "$attached_policy_name" == "$policy_name" ]] && name_valid=true

if [[ "$role_exists" == true ]] && [[ "$policy_attached" == true ]] && [[ "$name_valid" == true ]]; then
  echo "✓ Success"
  echo "  Role: $role_name"
  echo "  Role ARN: $role_arn"
  echo "  Attached policy: $attached_policy_name"
else
  echo "✗ Fail"
  
  if [[ "$role_exists" == false ]]; then
    echo "  ✗ IAM role not found"
  else
    echo "  ✓ IAM role exists"
  fi
  
  if [[ "$policy_attached" == false ]]; then
    echo "  ✗ Policy not attached to role"
  else
    echo "  ✓ Policy attached to role"
  fi
  
  if [[ "$name_valid" == false ]]; then
    echo "  ✗ Policy name validation failed"
    echo "    Expected: $policy_name"
    echo "    Got: $attached_policy_name"
  else
    echo "  ✓ Policy name validation passed"
  fi
fi
```

</details>
