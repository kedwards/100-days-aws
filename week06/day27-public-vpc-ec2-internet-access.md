# Day 27 - Configuring a Public VPC and EC2 Instance with Internet Access

## Task

The Nautilus DevOps Team has received a request from the Networking Team to set up a new public VPC to support a set of public-facing services. This VPC will host various resources that need to be accessible over the internet. As part of this setup, you need to ensure the VPC has public subnets with automatic IP assignment for resources. Additionally, a new EC2 instance will be launched within this VPC to host public applications that require SSH access. This setup will enable the Networking Team to deploy and manage public-facing applications.

Create a public VPC named datacenter-pub-vpc, and a subnet named datacenter-pub-subnet under the same, make sure public IP is being auto assigned to resources under this subnet. Further, create an EC2 instance named datacenter-pub-ec2 under this VPC with instance type t2.micro. Make sure SSH port 22 is open for this instance and accessible over the internet.

## Help

```bash
aws create-vpc help
aws describe-vpcs help
aws create-subnet help
aws ec2 create-internet-gateway help
```

<details>
<summary><h2>Solution</h2></summary>


```bash
vpc_name=xfusion-pub-vpc
subnet_name=xfusion-pub-subnet
key_name=aws-client-key
region=us-east-1
instance_type=t2.micro
instance_name=xfusion-pub-ec2

if [[ ! -f ~/.ssh/id_rsa.pub ]]; then
  ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N ""
fi

aws ec2 import-key-pair \
  --key-name "$key_name" \
  --public-key-material fileb://~/.ssh/id_rsa.pub \
  --region "$region"

read -r vpc_id < <(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$vpc_name}]" \
  --query "Vpc.VpcId" \
  --output text) && echo "VPC ID: $vpc_id"

read -r igw_id < <(aws ec2 create-internet-gateway \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=my-igw}]" \
  --query "InternetGateway.InternetGatewayId" \
  --output text) && echo "Internet Gateway ID: $igw_id"

aws ec2 attach-internet-gateway \
  --vpc-id "$vpc_id" \
  --internet-gateway-id "$igw_id"

read -r route_table_id < <(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$vpc_id" \
  --query "RouteTables[0].RouteTableId" \
  --output text) && echo "Route Table ID: $route_table_id"

aws ec2 create-route \
  --route-table-id $route_table_id \
  --destination-cidr-block '0.0.0.0/0' \
  --gateway-id $igw_id

read -r subnet_id < <(aws ec2 create-subnet \
  --vpc-id $vpc_id \
  --cidr-block 10.0.0.0/24 \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$subnet_name}]" \
  --query "Subnet.SubnetId" \
  --output text) && echo "Subnet ID: $subnet_id"

aws ec2 modify-subnet-attribute --subnet-id $subnet_id --map-public-ip-on-launch

read -r security_group_id < <(aws ec2 create-security-group \
  --group-name MySecurityGroup \
  --description "My security group" \
  --vpc-id $vpc_id \
  --query "GroupId" \
  --output text) && echo "Security Group ID: $security_group_id"

aws ec2 authorize-security-group-ingress \
  --group-id "$security_group_id" \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

read -r image_id < <(aws ec2 describe-images \
  --region "$region" \
  --owners amazon \
  --filters 'Name=name,Values=al2023-ami-2023.*-x86_64' \
  --query 'reverse(sort_by(Images, &CreationDate))[:1] | [0].ImageId' \
  --output text) && echo "Image ID: $image_id"

aws ec2 run-instances \
  --image-id "$image_id" \
  --instance-type "$instance_type" \
  --region "$region" \
  --security-group-ids "$security_group_id" \
  --subnet $subnet_id \
  --key-name "$key_name" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance_name}]"

```

</details>
<details>
<summary><h2>Validate</h2></summary>


```bash
read -r instance_id instance_key instance_sg instance_state public_ip < <(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$instance_name" \
  --query "Reservations[0].Instances[0].[InstanceId,KeyName,SecurityGroups[0].GroupId,State.Name,PublicIpAddress]" \
  --output text) && echo "Instance ID: $instance_id, Key: $instance_key, SG: $instance_sg, State: $instance_state, IP: $public_ip"

read -r ssh_rule < <(aws ec2 describe-security-group-rules \
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
