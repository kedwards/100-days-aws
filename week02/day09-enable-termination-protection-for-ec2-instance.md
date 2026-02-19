# Day 9: Enable Termination Protection for EC2 Instance

## Task

Enable termination protection for the instance named xfusion-ec2 in us-east-1 region.

## Help

```bash
aws ec2 describe-instances help
aws ec2 describe-instance-attribute help
aws ec2 modify-instance-attribute help
```

<details>
<summary><h2>Solution</h2></summary>


```bash
instance_name=xfusion-ec2

instance_id=$(aws ec2 describe-instances \
  --filter "Name=tag:Name,Values=$instance_name" \
  --query "Reservations[].Instances[].InstanceId" \
  --output text) && echo "Instance ID: $instance_id"

aws ec2 modify-instance-attribute \
  --disable-api-termination \
  --instance-id "$instance_id"
```

</details>
<details>
<summary><h2>Validate</h2></summary>


```bash
aws ec2 describe-instance-attribute \
  --instance-id "$instance_id" \
  --attribute disableApiTermination \
  --query "DisableApiTermination.Value" \
  --output table
```

```bash
termination_protection=$(aws ec2 describe-instance-attribute \
  --instance-id "$instance_id" \
  --attribute disableApiTermination \
  --query "DisableApiTermination.Value" \
  --output text) && echo "Termination protection: $termination_protection"

# Check validation
protection_valid=false
[[ "$termination_protection" == "True" ]] && protection_valid=true

if [[ "$protection_valid" == true ]]; then
  echo "✓ Success"
  echo "  Instance ID: $instance_id"
  echo "  Termination protection: Enabled"
else
  echo "✗ Fail"
  echo "  ✗ Termination protection validation failed"
  echo "    Expected: True (Enabled)"
  echo "    Got: $termination_protection"
fi
```

</details>
