# Day 14: Terminate EC2 Instance

## Task

Terminate an EC2 instance named xfusion-ec2. Make sure to disable termination protection if it's enabled.

## Help

```bash
aws ec2 describe-instances help
aws ec2 describe-instance-attribute help
aws ec2 modify-instance-attribute help
aws ec2 terminate-instances help
```

<details>
<summary><h2>Solution</h2></summary>


```bash
instance_name=xfusion-ec2

instance_id=$(aws ec2 describe-instances \
  --filter "Name=tag:Name,Values=$instance_name" \
  --query "Reservations[].Instances[].InstanceId" \
  --output text) && echo "Instance ID: $instance_id"

termination_protection=$(aws ec2 describe-instance-attribute \
  --instance-id "$instance_id" \
  --attribute disableApiTermination \
  --query "DisableApiTermination.Value" \
  --output text) && echo "Termination protection: $termination_protection"

if [[ "$termination_protection" == "True" ]]; then
  aws ec2 modify-instance-attribute \
    --no-disable-api-termination \
    --instance-id "$instance_id"
fi

aws ec2 terminate-instances --instance-ids "$instance_id"

aws ec2 describe-instances --instance-ids "$instance_id" \
  --query "Reservations[0].Instances[0].{InstanceId:InstanceId,State:State.Name}" \
  --output table
```

</details>

<details>
<summary><h2>Validate</h2></summary>


```bash
aws ec2 describe-instances --instance-ids "$instance_id" \
  --query "Reservations[].Instances[].{InstanceId:InstanceId,State:State.Name}" \
  --output table
```

```bash
state=$(aws ec2 describe-instances --instance-ids "$instance_id" \
  --query "Reservations[0].Instances[0].State.Name" \
  --output text) && echo "Instance state: $state"

state_valid=false
[[ "$state" == "terminated" || "$state" == "shutting-down" ]] && state_valid=true

if [[ "$state_valid" == true ]]; then
  echo "✓ Success"
  echo "  Instance ID: $instance_id"
  echo "  State: $state"
else
  echo "✗ Fail"
  echo "  ✗ Instance termination validation failed"
  echo "    Expected: terminated or shutting-down"
  echo "    Got: $state"
fi
```

</details>
