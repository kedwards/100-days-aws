# Day 22 - Create EC2 with SSH Access

## Task

Create an EC2 instance with SSH access using an imported key pair.

## Help

```bash
aws ec2 import-key-pair help
aws ec2 authorize-security-group-ingress help
aws ec2 run-instances help
```

<details>
<summary><h2>Solution</h2></summary>


```bash
key_name=aws-client-key
instance_name=nautilus-ec2
instance_type=t2.micro
region=us-east-1

# Generate SSH key if not exists
if [[ ! -f ~/.ssh/id_rsa.pub ]]; then
  ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N ""
fi

# Import key pair
aws ec2 import-key-pair \
  --key-name "$key_name" \
  --public-key-material fileb://~/.ssh/id_rsa.pub \
  --region "$region"

# Get default security group
read -r default_sg < <(aws ec2 describe-security-groups \
  --query "SecurityGroups[?GroupName=='default'].GroupId" \
  --output text) && echo "Default security group: $default_sg"

# Add SSH rule to default security group
aws ec2 authorize-security-group-ingress \
  --group-id "$default_sg" \
  --protocol tcp \
  --port 22 \
  --cidr *******/0

# Get latest Amazon Linux 2023 AMI
read -r image_id < <(aws ec2 describe-images \
  --region "$region" \
  --owners amazon \
  --filters 'Name=name,Values=al2023-ami-2023.*-x86_64' \
  --query 'reverse(sort_by(Images, &CreationDate))[:1] | [0].ImageId' \
  --output text) && echo "Image ID: $image_id"

# Launch instance
aws ec2 run-instances \
  --image-id "$image_id" \
  --instance-type "$instance_type" \
  --region "$region" \
  --security-group-ids "$default_sg" \
  --key-name "$key_name" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance_name}]"
```

</details>
<details>
<summary><h2>Validate</h2></summary>


```bash
aws ec2 describe-instances --filters "Name=tag:Name,Values=$instance_name" \
  --query "Reservations[].Instances[].{InstanceId:InstanceId,State:State.Name,KeyName:KeyName,PublicIP:PublicIpAddress}" \
  --output table
```

```bash
read -r instance_id instance_key instance_sg instance_state public_ip < <(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$instance_name" \
  --query "Reservations[0].Instances[0].[InstanceId,KeyName,SecurityGroups[0].GroupId,State.Name,PublicIpAddress]" \
  --output text) && echo "Instance ID: $instance_id, Key: $instance_key, SG: $instance_sg, State: $instance_state, IP: $public_ip"

read -r ssh_rule < <(aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=$instance_sg" \
  --query "SecurityGroupRules[?IsEgress==\`false\` && IpProtocol==\`tcp\` && FromPort==\`22\` && ToPort==\`22\`].SecurityGroupRuleId" \
  --output text) && echo "SSH rule ID: $ssh_rule"

# Check validation
instance_exists=false
key_valid=false
ssh_enabled=false
state_valid=false

[[ -n "$instance_id" && "$instance_id" != "None" ]] && instance_exists=true
[[ "$instance_key" == "$key_name" ]] && key_valid=true
[[ -n "$ssh_rule" ]] && ssh_enabled=true
[[ "$instance_state" == "running" ]] && state_valid=true

if [[ "$instance_exists" == true ]] && [[ "$key_valid" == true ]] && [[ "$ssh_enabled" == true ]] && [[ "$state_valid" == true ]]; then
  echo "✓ Success"
  echo "  Instance ID: $instance_id"
  echo "  Key name: $instance_key"
  echo "  State: $instance_state"
  echo "  Public IP: $public_ip"
  echo "  SSH access: Enabled"
else
  echo "✗ Fail"
  
  if [[ "$instance_exists" == false ]]; then
    echo "  ✗ Instance not found"
  else
    echo "  ✓ Instance exists"
  fi
  
  if [[ "$key_valid" == false ]]; then
    echo "  ✗ Key pair validation failed"
    echo "    Expected: $key_name"
    echo "    Got: $instance_key"
  else
    echo "  ✓ Key pair validation passed"
  fi
  
  if [[ "$ssh_enabled" == false ]]; then
    echo "  ✗ SSH access not enabled in security group"
  else
    echo "  ✓ SSH access enabled"
  fi
  
  if [[ "$state_valid" == false ]]; then
    echo "  ✗ Instance state validation failed"
    echo "    Expected: running"
    echo "    Got: $instance_state"
  else
    echo "  ✓ Instance state validation passed"
  fi
fi
```

</details>
