# Day 13 - Create Image (AMI)

## Task

For this task, create an AMI from an existing EC2 instance named datacenter-ec2 with the following requirement:

Name of the AMI should be datacenter-ec2-ami, make sure AMI is in available state.

## Help

```bash
aws ec2 describe-instances help
aws ec2 create-image help
aws ec2 describe-images help
```

<details>
<summary><h2>Solution</h2></summary>


```bash
instance_name=datacenter-ec2
ami_name=datacenter-ec2-ami

read -r instance_id < <(aws ec2 describe-instances \
  --filter "Name=tag:Name,Values=$instance_name" \
  --query "Reservations[].Instances[].InstanceId" \
  --output text) && echo "Instance ID: $instance_id"

aws ec2 create-image \
  --instance-id "$instance_id" \
  --name "$ami_name" \
  --description "AMI created from $instance_name"

aws ec2 wait image-available \
  --filters "Name=name,Values=$ami_name"
```

</details>
<details>
<summary><h2>Validate</h2></summary>


```bash
aws ec2 describe-images --owners self \
  --filters "Name=name,Values=$ami_name" \
  --query "Images[].{ImageId:ImageId,Name:Name,State:State,CreationDate:CreationDate}" \
  --output table
```

```bash
read -r image_id image_name state < <(aws ec2 describe-images --owners self \
  --filters "Name=name,Values=$ami_name" \
  --query "Images[0].[ImageId,Name,State]" \
  --output text) && echo "Image ID: $image_id, Name: $image_name, State: $state"

image_exists=false
name_valid=false
state_valid=false

[[ -n "$image_id" && "$image_id" != "None" ]] && image_exists=true
[[ "$image_name" == "$ami_name" ]] && name_valid=true
[[ "$state" == "available" || "$state" == "pending" ]] && state_valid=true

if [[ "$image_exists" == true ]] && [[ "$name_valid" == true ]] && [[ "$state_valid" == true ]]; then
  echo "✓ Success"
  echo "  Image ID: $image_id"
  echo "  Image name: $image_name"
  echo "  State: $state"
else
  echo "✗ Fail"
  
  if [[ "$image_exists" == false ]]; then
    echo "  ✗ AMI not found"
  else
    echo "  ✓ AMI exists"
  fi
  
  if [[ "$name_valid" == false ]]; then
    echo "  ✗ AMI name validation failed"
    echo "    Expected: $ami_name"
    echo "    Got: $image_name"
  else
    echo "  ✓ AMI name validation passed"
  fi
  
  if [[ "$state_valid" == false ]]; then
    echo "  ✗ AMI state validation failed"
    echo "    Expected: available or pending"
    echo "    Got: $state"
  else
    echo "  ✓ AMI state validation passed"
  fi
fi
```

</details>
