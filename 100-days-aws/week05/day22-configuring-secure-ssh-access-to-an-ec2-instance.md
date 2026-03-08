# Day 22: Configuring Secure SSH Access to an EC2 Instance

## Task

The Nautilus DevOps team needs to set up a new EC2 instance that can be accessed securely from their landing host (aws-client). The instance should be of type t2.micro and named nautilus-ec2. A new SSH key with name id_rsa should be created on the aws-client host under the/root/.ssh/ folder, if it doesn't already exist. This key should then be added to the root user's authorised keys on the EC2 instance, allowing passwordless SSH access from the aws-client host.

## Help

```bash
aws ec2 describe-images help
aws ec2 import-key-pair help
aws ec2 describe-security-groups help
aws ec2 authorize-security-group-ingress help
aws ec2 run-instances help
aws ec2 describe-instances help
aws ec2 describe-security-group-rules help
```

<details>
<summary><h2>Solution</h2></summary>


```bash
key_name=aws-client-key
instance_name=nautilus-ec2
instance_type=t2.micro
region=us-east-1

# ── Generate SSH key ──────────────────────────────────────────
if [[ ! -f ~/.ssh/id_rsa.pub ]]; then
  ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N ""
fi

# ── Import key pair ───────────────────────────────────────────
aws ec2 import-key-pair \
  --key-name "$key_name" \
  --public-key-material fileb://~/.ssh/id_rsa.pub \
  --region "$region"

# ── Get default security group ────────────────────────────────
default_sg=$(aws ec2 describe-security-groups \
  --query "SecurityGroups[?GroupName=='default'].GroupId" \
  --output text) && echo "Default security group: $default_sg"

# ── Add SSH rule to security group ────────────────────────────
aws ec2 authorize-security-group-ingress \
  --group-id "$default_sg" \
  --protocol tcp \
  --port 22 \
  --cidr *******/0

# ── Get latest Amazon Linux AMI ────────────────────────────────
image_id=$(aws ec2 describe-images \
  --region "$region" \
  --owners amazon \
  --filters 'Name=name,Values=al2023-ami-2023.*-x86_64' \
  --query 'reverse(sort_by(Images, &CreationDate))[:1] | [0].ImageId' \
  --output text) && echo "Image ID: $image_id"

# ── Launch EC2 instance ───────────────────────────────────────
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
instance_name=nautilus-ec2
instance_type=t2.micro
region=us-east-1
key_name=aws-client-key

read -r instance_id instance_key instance_sg instance_state public_ip <<< "$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$instance_name" \
  --query "Reservations[0].Instances[0].[InstanceId,KeyName,SecurityGroups[0].GroupId,State.Name,PublicIpAddress]" \
  --output text)" && echo "Instance ID: $instance_id, Key: $instance_key, SG: $instance_sg, State: $instance_state, IP: $public_ip"

ssh_rule=$(aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=$instance_sg" \
  --query "SecurityGroupRules[?IsEgress==\`false\` && IpProtocol==\`tcp\` && FromPort==\`22\` && ToPort==\`22\`].SecurityGroupRuleId" \
  --output text) && echo "SSH rule ID: $ssh_rule"

# Test actual SSH connectivity
ssh_ready=false
if [[ -n "$public_ip" && "$public_ip" != "None" ]]; then
  echo "Testing SSH connection to $public_ip..."
  
  # Wait for SSH to be ready (instance might still be initializing)
  timeout=60
  elapsed=0
  
  while [[ $elapsed -lt $timeout ]]; do
    if ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes ec2-user@$public_ip "echo 'SSH connection successful'" 2>/dev/null; then
      ssh_ready=true
      echo "  ✓ SSH connection test passed"
      break
    fi
    sleep 5
    elapsed=$((elapsed + 5))
  done
  
  if [[ "$ssh_ready" == false ]]; then
    echo "  ✗ SSH connection test failed (timeout after ${timeout}s)"
  fi
else
  echo "  ✗ No public IP available for SSH test"
fi

# Check validation
instance_exists=false
key_valid=false
ssh_enabled=false
state_valid=false

[[ -n "$instance_id" && "$instance_id" != "None" ]] && instance_exists=true
[[ "$instance_key" == "$key_name" ]] && key_valid=true
[[ -n "$ssh_rule" ]] && ssh_enabled=true
[[ "$instance_state" == "running" ]] && state_valid=true

if [[ "$instance_exists" == true ]] && [[ "$key_valid" == true ]] && [[ "$ssh_enabled" == true ]] && [[ "$state_valid" == true ]] && [[ "$ssh_ready" == true ]]; then
  echo "✓ Success - SSH access fully confirmed"
  echo "  Instance ID: $instance_id"
  echo "  Key name: $instance_key"
  echo "  State: $instance_state"
  echo "  Public IP: $public_ip"
  echo "  SSH access: Enabled and tested"
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
  
  if [[ "$ssh_ready" == false ]]; then
    echo "  ✗ SSH connectivity test failed"
  else
    echo "  ✓ SSH connectivity test passed"
  fi
fi
```

</details>
