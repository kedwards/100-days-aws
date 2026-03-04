# Day 7: Change EC2 Instance Type

## Task

An EC2 instances was underutilized, prompting them to decide to change the instance type. Please make sure the Status check is completed (if its still in Initializing state) before making any changes to the instance.

1) Change the instance type from t2.micro to t2.nano for datacenter-ec2 instance.

2) Make sure the ec2 instance datacenter-ec2 is in running state after the change.

## Help

```bash
aws ec2 describe-instances help
aws ec2 stop-instances help
aws ec2 modify-instance-attribute help
aws ec2 start-instances help
```

<details>
<summary><h2>Solution</h2></summary>


```bash
instance_type=t2.nano
instance_name=datacenter-ec2
instance_state=running

# ── Get instance ID ─────────────────────────────────────────────
instance_id=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$instance_name" \
  --query "Reservations[].Instances[].InstanceId" --output text) && echo "Instance ID: $instance_id"

# ── Stop instance ───────────────────────────────────────────────
aws ec2 stop-instances --instance-ids "$instance_id" && echo "Stopping instance..."
aws ec2 wait instance-stopped --instance-ids "$instance_id" && echo "Instance stopped"

# ── Change instance type ────────────────────────────────────────
aws ec2 modify-instance-attribute \
  --instance-id "$instance_id" \
  --attribute instanceType \
  --value "$instance_type" && echo "Changed instance type to $instance_type"

# ── Start instance ──────────────────────────────────────────────
aws ec2 start-instances --instance-ids "$instance_id" && echo "Starting instance..."
aws ec2 wait instance-running --instance-ids "$instance_id" && echo "Instance running"

aws ec2 describe-instances --instance-ids "$instance_id" \
  --query "Reservations[0].Instances[0].{InstanceId:InstanceId,Type:InstanceType,State:State.Name}" \
  --output table
```

</details>

<details>
<summary><h2>Validate</h2></summary>


```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$instance_name" \
  --query "Reservations[].Instances[].{ID:InstanceId,State:State.Name,Type:InstanceType}" \
  --output table
```

```bash
read -r id type state <<< "$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$instance_name" \
  --query "Reservations[0].Instances[0].[InstanceId,InstanceType,State.Name]" \
  --output text)" && echo "Instance ID: $id, Type: $type, State: $state"

instance_exists=false
type_valid=false
state_valid=false

[[ -n "$id" && "$id" != "None" ]] && instance_exists=true
[[ "$type" == "$instance_type" ]] && type_valid=true
[[ "$state" == "$instance_state" ]] && state_valid=true

if [[ "$instance_exists" == true ]] && [[ "$type_valid" == true ]] && [[ "$state_valid" == true ]]; then
  echo "✓ Success"
  echo "  Instance ID: $id"
  echo "  Instance type: $type"
  echo "  Instance state: $state"
else
  echo "✗ Fail"
  
  if [[ "$instance_exists" == false ]]; then
    echo "  ✗ Instance not found with name: $instance_name"
  else
    echo "  ✓ Instance exists"
  fi
  
  if [[ "$type_valid" == false ]]; then
    echo "  ✗ Instance type validation failed"
    echo "    Expected: $instance_type"
    echo "    Got: $type"
  else
    echo "  ✓ Instance type validation passed"
  fi
  
  if [[ "$state_valid" == false ]]; then
    echo "  ✗ Instance state validation failed"
    echo "    Expected: $instance_state"
    echo "    Got: $state"
  else
    echo "  ✓ Instance state validation passed"
  fi
fi
```

</details>
