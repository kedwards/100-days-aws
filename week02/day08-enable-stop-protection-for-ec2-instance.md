# Day 08 - Enable Stop Protection for EC2 Instance

## Task

Enable stop protection for the instance named devops-ec2 in us-east-1 region.

## Help

```bash
aws ec2 describe-instances help
aws ec2 describe-instance-attribute help
aws ec2 modify-instance-attribute help
```

<details>
<summary><h2>Solution</h2></summary>


```bash
instance_name=devops-ec2

read -r instance_id < <(aws ec2 describe-instances \
  --filter "Name=tag:Name,Values=$instance_name" \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text) && echo "Instance ID: $instance_id"

aws ec2 modify-instance-attribute \
  --disable-api-stop \
  --instance-id "$instance_id"
```

</details>

<details>
<summary><h2>Validate</h2></summary>


```bash
aws ec2 describe-instance-attribute \
  --instance-id "$instance_id" \
  --attribute disableApiStop \
  --query "DisableApiStop.Value" \
  --output text
```

```bash
read -r stop_protection < <(aws ec2 describe-instance-attribute \
  --instance-id "$instance_id" \
  --attribute disableApiStop \
  --query "DisableApiStop.Value" \
  --output text) && echo "Stop protection: $stop_protection"

# Check validation
protection_valid=false
[[ "$stop_protection" == "True" ]] && protection_valid=true

if [[ "$protection_valid" == true ]]; then
  echo "✓ Success"
  echo "  Instance ID: $instance_id"
  echo "  Stop protection: Enabled"
else
  echo "✗ Fail"
  echo "  ✗ Stop protection validation failed"
  echo "    Expected: True (Enabled)"
  echo "    Got: $stop_protection"
fi
```

</details>
