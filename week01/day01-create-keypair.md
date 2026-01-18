# Day 1: Create Key Pair

## Task

For this task, create a key pair with the following requirements:

- Name of the key pair should be xfusion-kp.
- Key pair type must be rsa

## Help

```bash
aws ec2 create-keypair help
```

<details>
<summary><h2>Solution</h2></summary>


```bash
key_name="xfusion-kp"
key_type="rsa"

aws ec2 create-key-pair --key-name "$key_name" --key-type "$key_type"
```

</details>
<details>
<summary><h2>Validate</h2></summary>


```bash
aws ec2 describe-key-pairs --filters "Name=key-name,Values=$key_name" \
  --query "KeyPairs[?KeyName=='"$key_name"'].{Name:KeyName,Type:KeyType}" \
  --output table
```

```bash
read -r name type < <(aws ec2 describe-key-pairs \
  --filter "Name=key-name,Values=$key_name" \
  --query "KeyPairs[0].[KeyName,KeyType]" \
  --output text) && echo "Key name: $name, Key type: $type"

name_valid=false
type_valid=false

[[ "$name" == "$key_name" ]] && name_valid=true
[[ "$type" == "$key_type" ]] && type_valid=true

if [[ "$name_valid" == true ]] && [[ "$type_valid" == true ]]; then
  echo "✓ Success"
  echo "  Key name: $name"
  echo "  Key type: $type"
else
  echo "✗ Fail"
  
  if [[ "$name_valid" == false ]]; then
    echo "  ✗ Key name validation failed"
    echo "    Expected: $key_name"
    echo "    Got: $name"
  else
    echo "  ✓ Key name validation passed"
  fi
  
  if [[ "$type_valid" == false ]]; then
    echo "  ✗ Key type validation failed"
    echo "    Expected: $key_type"
    echo "    Got: $type"
  else
    echo "  ✓ Key type validation passed"
  fi
fi
```

</details>
