# Day 13: Create AMI from EC2 Instance

## Task

The Nautilus DevOps team is strategizing the migration of a portion of their infrastructure to the AWS cloud. Recognizing the scale of this undertaking, they have opted to approach the migration in incremental steps rather than as a single massive transition. To achieve this, they have segmented large tasks into smaller, more manageable units. This granular approach enables the team to execute the migration in gradual phases, ensuring smoother implementation and minimizing disruption to ongoing operations. By breaking down the migration into smaller tasks, the Nautilus DevOps team can systematically progress through each stage, allowing for better control, risk mitigation, and optimization of resources throughout the migration process.

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

instance_id=$(aws ec2 describe-instances \
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
read -r image_id image_name state <<< "$(aws ec2 describe-images --owners self \
  --filters "Name=name,Values=$ami_name" \
  --query "Images[0].[ImageId,Name,State]" \
  --output text)" && echo "Image ID: $image_id, Name: $image_name, State: $state"

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
