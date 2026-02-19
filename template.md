# Day XX - Task title

## Task

Task desriptiona goes here. Make sure to include all necessary details and
requirements for the task.

## Help

```bash
aws command help
aws command2 help
```

<details>
<summary><h2>Solution</h2></summary>

```bash
tag_value=value

aws_value=$(aws command describe-something \
  --filter "Name=tag:Name,Values=$tag_value" \
  --query "Returned[].AwsValue" \
  --output text) && echo "AWS Value: $aws_value"
```

</details>

<details>
<summary><h2>Validate</h2></summary>

```bash
aws ec2 describe-omething--filters "Name=tag:Name,Values=$tag_vale" \
  --query "Returned[?KeyName=='"$key_name"'].{Name:KeyName,Type:KeyType}" \
  --output table
```

```bash
key_name=keyName
tag_value=value

aws_value=$(aws command describe-something \
  --filter "Name=tag:Name,Values=$tag_value" \
  --query "Returned[].AwsValue" \
  --output text) && echo "AWS Value: $aws_value"

name_valid=false

[[ "$aws_value" == "$key_name" ]] && name_valid=true

if [[ "$name_valid" == true ]]; then
  echo "✓ Success"
  echo "  Key name: $aws_value"
else
  echo "✗ Fail"
  
  if [[ "$name_valid" == false ]]; then
    echo "  ✗ Key name validation failed"
    echo "    Expected: $key_name"
    echo "    Got: $aws_value"
  else
    echo "  ✓ Key name validation passed"
  fi
fi
```

</details>
