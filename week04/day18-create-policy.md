# Day 18: Create Read-Only IAM Policy for EC2 Console Access

## Task

When establishing infrastructure on the AWS cloud, Identity and Access Management (IAM) is among the first and most critical services to configure. IAM facilitates the creation and management of user accounts, groups, roles, policies, and other access controls. The Nautilus DevOps team is currently in the process of configuring these resources and has outlined the following requirements.

Create an IAM policy named iampolicy_kirsty in us-east-1 region, it must allow read-only access to the EC2 console, i.e this policy must allow users to view all instances, AMIs, and snapshots in the Amazon EC2 console.

## Help

```bash
aws iam create-policy help
aws iam get-policy help
aws iam list-policies help
```

<details>
<summary><h2>Solution</h2></summary>


```bash
policy_name=iampolicy_kirsty

# Create policy document for read-only EC2 console access
cat > /tmp/policy.json << 'POLICY'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "EC2ReadOnlyAccess",
            "Effect": "Allow",
            "Action": [
                "ec2:Describe*",
                "ec2:GetConsole*"
            ],
            "Resource": "*"
        }
    ]
}
POLICY

aws iam create-policy \
  --policy-name "$policy_name" \
  --policy-document file:///tmp/policy.json
```

</details>

<details>
<summary><h2>Validate</h2></summary>


```bash
policy_arn=$(aws iam list-policies --scope Local \
  --query "Policies[?PolicyName=='$policy_name'].Arn" \
  --output text) && echo "Policy ARN: $policy_arn"

aws iam get-policy --policy-arn "$policy_arn" \
  --query "Policy.{PolicyName:PolicyName,Arn:Arn,CreateDate:CreateDate}" \
  --output table
```

```bash
read -r policy_arn retrieved_name <<< "$(aws iam list-policies --scope Local \
  --query "Policies[?PolicyName=='$policy_name'].[Arn,PolicyName]" \
  --output text)" && echo "Policy ARN: $policy_arn, Policy name: $retrieved_name"

# Check validation
policy_exists=false
name_valid=false

[[ -n "$policy_arn" && "$policy_arn" != "None" ]] && policy_exists=true
[[ "$retrieved_name" == "$policy_name" ]] && name_valid=true

if [[ "$policy_exists" == true ]] && [[ "$name_valid" == true ]]; then
  echo "✓ Success"
  echo "  Policy name: $retrieved_name"
  echo "  Policy ARN: $policy_arn"
else
  echo "✗ Fail"
  
  if [[ "$policy_exists" == false ]]; then
    echo "  ✗ IAM policy not found"
  else
    echo "  ✓ IAM policy exists"
  fi
  
  if [[ "$name_valid" == false ]]; then
    echo "  ✗ Policy name validation failed"
    echo "    Expected: $policy_name"
    echo "    Got: $retrieved_name"
  else
    echo "  ✓ Policy name validation passed"
  fi
fi
```

</details>
