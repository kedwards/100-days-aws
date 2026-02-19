# Day 19: Attach IAM Policy to IAM User

## Task

The Nautilus DevOps team has been creating a couple of services on AWS cloud. They have been breaking down the migration into smaller tasks, allowing for better control, risk mitigation, and optimization of resources throughout the migration process. Recently they came up with requirements mentioned below.

An IAM user named iamuser_john and a policy named iampolicy_john already exist. Attach the IAM policy iampolicy_john to the IAM user iamuser_john.

## Help

```bash
aws iam list-policies help
aws iam attach-user-policy help
aws iam list-attached-user-policies help
```

<details>
<summary><h2>Solution</h2></summary>


```bash
user_name=iamuser_john
policy_name=iampolicy_john

policy_arn=$(aws iam list-policies \
  --query "Policies[?PolicyName=='$policy_name'].Arn" \
  --output text) && echo "Policy ARN: $policy_arn"

aws iam attach-user-policy \
  --user-name "$user_name" \
  --policy-arn "$policy_arn"
```

</details>

<details>
<summary><h2>Validate</h2></summary>


```bash
aws iam list-attached-user-policies --user-name "$user_name" \
  --query "AttachedPolicies[].{PolicyName:PolicyName,PolicyArn:PolicyArn}" \
  --output table
```

```bash
read -r attached_policy_arn attached_policy_name <<< "$(aws iam list-attached-user-policies \
  --user-name "$user_name" \
  --query "AttachedPolicies[?PolicyName=='$policy_name'].[PolicyArn,PolicyName]" \
  --output text)" && echo "Attached policy ARN: $attached_policy_arn, Policy name: $attached_policy_name"

# Check validation
policy_attached=false
name_valid=false

[[ -n "$attached_policy_arn" && "$attached_policy_arn" != "None" ]] && policy_attached=true
[[ "$attached_policy_name" == "$policy_name" ]] && name_valid=true

if [[ "$policy_attached" == true ]] && [[ "$name_valid" == true ]]; then
  echo "✓ Success"
  echo "  User: $user_name"
  echo "  Policy name: $attached_policy_name"
  echo "  Policy ARN: $attached_policy_arn"
else
  echo "✗ Fail"
  
  if [[ "$policy_attached" == false ]]; then
    echo "  ✗ Policy not attached to user"
  else
    echo "  ✓ Policy attached to user"
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
