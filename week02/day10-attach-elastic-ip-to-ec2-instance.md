# Day 10 - Attach Elastic IP to EC2 Instance

## Task

There is an instance named devops-ec2 and an elastic-ip named devops-ec2-eip in us-east-1 region. Attach the devops-ec2-eip elastic-ip to the devops-ec2 instance.

## Help

```bash
aws ec2 describe-instances help
aws ec2 describe-addresses help
aws ec2 associate-address help
```

<details>
<summary><h2>Solution</h2></summary>


```bash
instance_name=devops-ec2
eip_name=devops-ec2-eip

read -r instance_id < <(aws ec2 describe-instances \
  --filter 'Name=tag:Name,Values=$instance_name' \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text) && echo "Instance ID: $instance_id"
  
read -r allocation_id < <(aws ec2 describe-addresses \
  --filter 'Name=tag:Name,Values=$eip_name' \
  --query 'Addresses[].AllocationId' \
  --output text) && echo "Allocation ID: $allocation_id"

aws ec2 associate-address \
  --allocation-id "$allocation_id" \
  --instance-id "$instance_id"
```

</details>
<details>
<summary><h2>Validate</h2></summary>


```bash
aws ec2 describe-addresses --filters "Name=tag:Name,Values=$eip_name" \
  --query "Addresses[].{AllocationId:AllocationId,InstanceId:InstanceId,PublicIp:PublicIp,Name:Tags[?Key=='Name'].Value|[0]}" \
  --output table
```

```bash
read -r allocation_id associated_instance public_ip < <(aws ec2 describe-addresses \
  --filter "Name=tag:Name,Values=$eip_name" \
  --query "Addresses[0].[AllocationId,InstanceId,PublicIp]" \
  --output text) && echo "Allocation ID: $allocation_id, Instance: $associated_instance, Public IP: $public_ip"

read -r instance_id < <(aws ec2 describe-instances \
  --filter "Name=tag:Name,Values=$instance_name" \
  --query "Reservations[].Instances[].InstanceId" \
  --output text) && echo "Instance ID: $instance_id"

eip_exists=false
association_valid=false

[[ -n "$allocation_id" && "$allocation_id" != "None" ]] && eip_exists=true
[[ "$associated_instance" == "$instance_id" ]] && association_valid=true

if [[ "$eip_exists" == true ]] && [[ "$association_valid" == true ]]; then
  echo "✓ Success"
  echo "  Allocation ID: $allocation_id"
  echo "  Instance ID: $instance_id"
  echo "  Public IP: $public_ip"
  echo "  EIP attached to instance: Yes"
else
  echo "✗ Fail"
  
  if [[ "$eip_exists" == false ]]; then
    echo "  ✗ Elastic IP not found"
  else
    echo "  ✓ Elastic IP exists"
  fi
  
  if [[ "$association_valid" == false ]]; then
    echo "  ✗ EIP association validation failed"
    echo "    Expected instance: $instance_id"
    echo "    Associated to: $associated_instance"
  else
    echo "  ✓ EIP association validation passed"
  fi
fi
```

</details>
