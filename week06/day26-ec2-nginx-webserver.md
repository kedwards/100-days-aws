# Day 26 - Configuring an EC2 Instance as a Web Server with Nginx

## Task

The Nautilus DevOps Team is working on setting up a new web server for a critical application. The team lead has requested you to create an EC2 instance that will serve as a web server using Nginx. This instance will be part of the initial infrastructure setup for the Nautilus project. Ensuring that the server is correctly configured and accessible from the internet is crucial for the upcoming deployment phase.

As a member of the Nautilus DevOps Team, your task is to create an EC2 instance with the following specifications:

Instance Name: The EC2 instance must be named devops-ec2.

AMI: Use any available Ubuntu AMI to create this instance.

User Data Script: Configure the instance to run a user data script during its launch. This script should:

    Install the Nginx package.
    Start the Nginx service.

Security Group: Ensure that the instance allows HTTP traffic on port 80 from the internet.

## Help

```bash
aws ec2 describe-images help
aws ec2 describe-security-groups help
aws ec2 import-key-pair help
aws ec2 authorize-security-group-ingress help
aws ec2 run-instances help
aws ec2 describe-instances help
aws ec2 describe-security-group-rules help
```

<details>
<summary><h2>Solution</h2></summary>


```bash
instance_name=devops-ec2
instance_type=t2.micro
key_name=aws-client-key
region=us-east-1

if [[ ! -f ~/.ssh/id_rsa.pub ]]; then
  ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N ""
fi

aws ec2 import-key-pair \
  --key-name "$key_name" \
  --public-key-material fileb://~/.ssh/id_rsa.pub \
  --region "$region"

image_id=$(aws ec2 describe-images \
  --region "$region" \
  --owners amazon \
  --filters 'Name=name,Values=ubuntu-*-24.04-amd64*' \
  --query 'reverse(sort_by(Images, &CreationDate))[:1] | [0].ImageId' \
  --output text) && echo "Image ID: $image_id"

default_sg=$(aws ec2 describe-security-groups \
  --query "SecurityGroups[?GroupName=='default'].GroupId" \
  --output text) && echo "Default security group: $default_sg"

aws ec2 authorize-security-group-ingress \
  --group-id "$default_sg" \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
  --group-id "$default_sg" \
  --ip-permissions 'IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges=[{CidrIp=0.0.0.0/0}]'

aws ec2 run-instances \
  --image-id "$image_id" \
  --instance-type "$instance_type" \
  --region "$region" \
  --security-group-ids "$default_sg" \
  --key-name "$key_name" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance_name}]" \
  --user-data '#!/bin/bash
    apt-get update
    apt-get install -y nginx
    systemctl start nginx
    systemctl enable nginx' 

```

</details>

<details>
<summary><h2>Validate</h2></summary>


```bash
aws ec2 describe-instances --filters "Name=tag:Name,Values=$instance_name" \
  --query "Reservations[].Instances[].{InstanceId:InstanceId,State:State.Name,Type:InstanceType,PublicIP:PublicIpAddress}" \
  --output table
```

```bash
instance_name=devops-ec2
instance_type=t2.micro

read -r instance_id instance_state public_ip <<< "$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$instance_name" \
  --query "Reservations[0].Instances[0].[InstanceId,State.Name,PublicIpAddress]" \
  --output text)" && echo "Instance ID: $instance_id, State: $instance_state, Public IP: $public_ip"

http_rule=$(aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=$default_sg" \
  --query "SecurityGroupRules[?IsEgress==\`false\` && IpProtocol==\`tcp\` && FromPort==\`80\` && ToPort==\`80\`].SecurityGroupRuleId" \
  --output text) && echo "HTTP rule ID: $http_rule"

# Test HTTP connectivity
http_ready=false
if [[ -n "$public_ip" && "$public_ip" != "None" ]]; then
  echo "Testing HTTP connection to $public_ip..."
  if curl -s --connect-timeout 5 "http://$public_ip" | grep -q "nginx\|Welcome"; then
    http_ready=true
    echo "  ✓ Nginx is responding"
  fi
fi

# Check validation
instance_exists=false
state_valid=false
http_enabled=false

[[ -n "$instance_id" && "$instance_id" != "None" ]] && instance_exists=true
[[ "$instance_state" == "running" ]] && state_valid=true
[[ -n "$http_rule" ]] && http_enabled=true

if [[ "$instance_exists" == true ]] && [[ "$state_valid" == true ]] && [[ "$http_enabled" == true ]] && [[ "$http_ready" == true ]]; then
  echo "✓ Success"
  echo "  Instance ID: $instance_id"
  echo "  Instance state: $instance_state"
  echo "  Public IP: $public_ip"
  echo "  HTTP port 80: Open"
  echo "  Nginx: Running"
else
  echo "✗ Fail"
  
  if [[ "$instance_exists" == false ]]; then
    echo "  ✗ Instance not found"
  else
    echo "  ✓ Instance exists"
  fi
  
  if [[ "$state_valid" == false ]]; then
    echo "  ✗ Instance state validation failed"
    echo "    Expected: running"
    echo "    Got: $instance_state"
  else
    echo "  ✓ Instance state validation passed"
  fi
  
  if [[ "$http_enabled" == false ]]; then
    echo "  ✗ HTTP port 80 not open in security group"
  else
    echo "  ✓ HTTP port 80 open"
  fi
  
  if [[ "$http_ready" == false ]]; then
    echo "  ✗ Nginx not responding on HTTP"
  else
    echo "  ✓ Nginx responding"
  fi
fi
```

</details>
