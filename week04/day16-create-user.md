# Day 16 - Create IAM User

## Task

When establishing infrastructure on the AWS cloud, Identity and Access Management (IAM) is among the first and most critical services to configure. IAM facilitates the creation and management of user accounts, groups, roles, policies, and other access controls. The Nautilus DevOps team is currently in the process of configuring these resources and has outlined the following requirements:

For this task, create an IAM user named iamuser_jim.

## Help

```bash
aws iam create-user help
aws iam list-users help
aws iam get-user help
```

<details>
<summary><h2>Solution</h2></summary>


```bash
user_name=iamuser_jim

aws iam create-user --user-name "$user_name"
```

</details>

<details>
<summary><h2>Validate</h2></summary>


```bash
aws iam get-user --user-name "$user_name" \
  --query "User.{UserName:UserName,UserId:UserId,CreateDate:CreateDate}" \
  --output table
```

```bash
read -r retrieved_username user_id <<< "$(aws iam get-user --user-name "$user_name" \
  --query "User.[UserName,UserId]" \
  --output text)" && echo "Username: $retrieved_username, User ID: $user_id"

# Check validation
user_exists=false
name_valid=false

[[ -n "$user_id" && "$user_id" != "None" ]] && user_exists=true
[[ "$retrieved_username" == "$user_name" ]] && name_valid=true

if [[ "$user_exists" == true ]] && [[ "$name_valid" == true ]]; then
  echo "✓ Success"
  echo "  User name: $retrieved_username"
  echo "  User ID: $user_id"
else
  echo "✗ Fail"
  
  if [[ "$user_exists" == false ]]; then
    echo "  ✗ IAM user not found"
  else
    echo "  ✓ IAM user exists"
  fi
  
  if [[ "$name_valid" == false ]]; then
    echo "  ✗ Username validation failed"
    echo "    Expected: $user_name"
    echo "    Got: $retrieved_username"
  else
    echo "  ✓ Username validation passed"
  fi
fi
```

</details>
