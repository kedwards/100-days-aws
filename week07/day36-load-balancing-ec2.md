# Day 36: Load Balancing EC2 Instances with Application Load Balancer

## Task

The Nautilus Development Team needs to set up a new EC2 instance and configure it to run a web server. This EC2 instance should be part of an Application Load Balancer (ALB) setup to ensure high availability and better traffic management. The task involves creating an EC2 instance, setting up an ALB, configuring a target group, and ensuring the web server is accessible via the ALB DNS.

Create a security group: Create a security group named xfusion-sg to open port 80 for the default security group (which will be attached to the ALB). Attach xfusion-sg security group to the EC2 instance.

Create an EC2 instance: Create an EC2 instance named xfusion-ec2. Use any available Ubuntu AMI to create this instance. Configure the instance to run a user data script during its launch.

This script should:

    Install the Nginx package.
    Start the Nginx service.

Set up an Application Load Balancer: Set up an Application Load Balancer named xfusion-alb. Attach default security group to the same.

Create a target group: Create a target group named xfusion-tg.

Route traffic: The ALB should route traffic on port 80 to port 80 of the xfusion-ec2 instance.

Security group adjustments: Make appropriate changes in the default security group attached to the ALB if necessary. Eventually, the Nginx server running under xfusion-ec2 instance must be accessible using the ALB DNS.

## Help

```bash
aws ec2 describe-vpcs help
aws ec2 describe-security-groups help
aws ec2 create-security-group help
aws ec2 authorize-security-group-ingress help
aws ec2 run-instances help
aws ec2 describe-instances help
aws ec2 describe-subnets help
aws elbv2 create-load-balancer help
aws elbv2 create-target-group help
aws elbv2 create-listener help
aws elbv2 register-targets help
aws elbv2 describe-load-balancers help
aws elbv2 describe-target-health help
```

<details>
<summary><h2>Solution</h2></summary>

```bash
prefix=devops
security_group_name="$prefix-sg"
instance_name="$prefix-ec2"
instance_type=t2.micro
load_balancer_name="$prefix-alb"
target_group_name="$prefix-tg"
region=us-east-1

read -r vpc_id < <(aws ec2 describe-vpcs \
  --query "Vpcs[].VpcId" \
  --output text) && echo "Vpc Id: $vpc_id"

read -r default_sg_id < <(aws ec2 describe-security-groups \
  --filter Name=vpc-id,Values=$vpc_id \
  --query "SecurityGroups[?GroupName=='default'].GroupId" \
  --output text) && echo "Default Security Group Id: $default_sg_id"

aws ec2 authorize-security-group-ingress \
  --group-id $default_sg_id \
  --protocol tcp \
  --port 80 \
  --cidr *******/0

read -r ec2_security_group_id < <(aws ec2 create-security-group \
  --group-name $security_group_name \
  --description "Security group for $prefix" \
  --vpc-id "$vpc_id" \
  --query "GroupId" \
  --output text) && echo "EC2 Security Group Id: $ec2_security_group_id"

aws ec2 authorize-security-group-ingress \
  --group-id "$ec2_security_group_id" \
  --protocol tcp \
  --port 80 \
  --source-group "$default_sg_id"

aws ec2 authorize-security-group-ingress \
  --group-id $default_sg_id \
  --protocol tcp \
  --port 80 \
  --source-group $ec2_security_group_id

# Ubuntu 24.04 - resolve:ssm:/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id
ubuntu_image=resolve:ssm:/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id

# Amazon Linux 2023 - resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 
amazon_image=resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64

read -r instance_id < <(aws ec2 run-instances \
  --image-id $ubuntu_image \
  --instance-type "$instance_type" \
  --region "$region" \
  --security-group-ids "$ec2_security_group_id" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance_name}]" \
  --user-data '#!/bin/bash
    apt-get update
    apt-get install -y nginx
    systemctl start nginx
    systemctl enable nginx' \
  --query "Instances[0].InstanceId" \
  --output text) && echo "Instance Id: $instance_id"

aws ec2 wait instance-running --instance-ids "$instance_id"

read -r subnets < <(aws ec2 describe-subnets \
  --filter Name=vpc-id,Values="$vpc_id" \
  --query "Subnets[].SubnetId" \
  --output text) && echo "Subnets: ${subnets[@]}"

read -r alb_arn < <(aws elbv2 create-load-balancer \
  --name $load_balancer_name \
  --subnets ${subnets} \
  --security-groups $default_sg_id \
  --query "LoadBalancers[0].LoadBalancerArn" \
  --output text) && echo "ALB ARN: $alb_arn"

read -r target_group_arn < <(aws elbv2 create-target-group \
  --name $target_group_name \
  --protocol HTTP \
  --port 80 \
  --target-type instance \
  --vpc-id $vpc_id \
  --query "TargetGroups[0].TargetGroupArn" \
  --output text) && echo "Target Group ARN: $target_group_arn"

aws elbv2 create-listener \
  --load-balancer-arn $alb_arn \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=$target_group_arn

read -r alb_dns_name < <(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?LoadBalancerName=='$load_balancer_name'].DNSName" \
  --output text) && echo "ALB DNS: $alb_dns_name"

aws elbv2 register-targets \
  --target-group-arn $target_group_arn \
  --targets Id=$instance_id

```

</details>

<details>
<summary><h2>Validate</h2></summary>

```bash
aws ec2 describe-instances --filters "Name=tag:Name,Values=$instance_name" \
  --query "Reservations[].Instances[].{InstanceId:InstanceId,State:State.Name,SecurityGroups:SecurityGroups[*].GroupName}" \
  --output table

aws elbv2 describe-load-balancers --names $load_balancer_name \
  --query "LoadBalancers[].{Name:LoadBalancerName,DNSName:DNSName,State:State.Code}" \
  --output table

aws elbv2 describe-target-health --target-group-arn $target_group_arn \
  --query "TargetHealthDescriptions[].{Target:Target.Id,Health:TargetHealth.State}" \
  --output table
```

```bash
prefix=xfusion
security_group_name="$prefix-sg"
instance_name="$prefix-ec2"
load_balancer_name="$prefix-alb"
target_group_name="$prefix-tg"

# Check EC2 instance
read -r ec2_id ec2_state ec2_sg < <(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$instance_name" \
  --query "Reservations[0].Instances[0].[InstanceId,State.Name,SecurityGroups[0].GroupName]" \
  --output text 2>/dev/null) && echo "EC2: $ec2_id, State: $ec2_state, Security Group: $ec2_sg"

# Check security group exists
read -r sg_id sg_name < <(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=$security_group_name" \
  --query "SecurityGroups[0].[GroupId,GroupName]" \
  --output text 2>/dev/null) && echo "Security Group: $sg_id, Name: $sg_name"

# Check ALB
read -r alb_name alb_state alb_dns < <(aws elbv2 describe-load-balancers \
  --names $load_balancer_name \
  --query "LoadBalancers[0].[LoadBalancerName,State.Code,DNSName]" \
  --output text 2>/dev/null) && echo "ALB: $alb_name, State: $alb_state, DNS: $alb_dns"

# Check target group
read -r tg_arn tg_name < <(aws elbv2 describe-target-groups \
  --names $target_group_name \
  --query "TargetGroups[0].[TargetGroupArn,TargetGroupName]" \
  --output text 2>/dev/null) && echo "Target Group: $tg_name"

# Check target health
target_health=""
if [[ -n "$tg_arn" && "$tg_arn" != "None" ]]; then
  read -r target_health < <(aws elbv2 describe-target-health \
    --target-group-arn $tg_arn \
    --query "TargetHealthDescriptions[0].TargetHealth.State" \
    --output text 2>/dev/null) && echo "Target Health: $target_health"
fi

# Test ALB connectivity
web_response=""
if [[ -n "$alb_dns" && "$alb_dns" != "None" ]]; then
  echo "Testing ALB endpoint: http://$alb_dns"
  web_response=$(curl -s --connect-timeout 10 "http://$alb_dns" 2>/dev/null)
  if [[ "$web_response" == *"nginx"* || "$web_response" == *"Welcome"* ]]; then
    echo "Web response: Nginx is responding"
  else
    echo "Web response: $web_response"
  fi
fi

# Validation checks
ec2_exists=false
ec2_running=false
ec2_sg_valid=false
sg_exists=false
alb_exists=false
alb_active=false
tg_exists=false
target_registered=false
nginx_accessible=false

[[ -n "$ec2_id" && "$ec2_id" != "None" ]] && ec2_exists=true
[[ "$ec2_state" == "running" ]] && ec2_running=true
[[ "$ec2_sg" == "$security_group_name" ]] && ec2_sg_valid=true
[[ -n "$sg_id" && "$sg_id" != "None" ]] && sg_exists=true
[[ -n "$alb_name" && "$alb_name" != "None" ]] && alb_exists=true
[[ "$alb_state" == "active" ]] && alb_active=true
[[ -n "$tg_arn" && "$tg_arn" != "None" ]] && tg_exists=true
[[ "$target_health" == "healthy" || "$target_health" == "initial" ]] && target_registered=true
[[ "$web_response" == *"nginx"* || "$web_response" == *"Welcome"* ]] && nginx_accessible=true

if [[ "$ec2_exists" == true ]] && [[ "$ec2_running" == true ]] && [[ "$ec2_sg_valid" == true ]] && [[ "$sg_exists" == true ]] && [[ "$alb_exists" == true ]] && [[ "$alb_active" == true ]] && [[ "$tg_exists" == true ]] && [[ "$target_registered" == true ]] && [[ "$nginx_accessible" == true ]]; then
  echo "✓ Success"
  echo "  EC2 Instance: $ec2_id ($ec2_state)"
  echo "  Security Group: $security_group_name"
  echo "  ALB: $alb_name ($alb_state)"
  echo "  ALB DNS: $alb_dns"
  echo "  Target Group: $tg_name"
  echo "  Target Health: $target_health"
  echo "  Nginx accessible via ALB: Yes"
else
  echo "✗ Fail"
  
  if [[ "$ec2_exists" == false ]]; then
    echo "  ✗ EC2 instance '$instance_name' not found"
  else
    echo "  ✓ EC2 instance exists"
  fi
  
  if [[ "$ec2_running" == false ]]; then
    echo "  ✗ EC2 instance not running"
    echo "    Got: $ec2_state"
  else
    echo "  ✓ EC2 instance is running"
  fi
  
  if [[ "$ec2_sg_valid" == false ]]; then
    echo "  ✗ EC2 security group validation failed"
    echo "    Expected: $security_group_name"
    echo "    Got: $ec2_sg"
  else
    echo "  ✓ EC2 has correct security group"
  fi
  
  if [[ "$sg_exists" == false ]]; then
    echo "  ✗ Security group '$security_group_name' not found"
  else
    echo "  ✓ Security group exists"
  fi
  
  if [[ "$alb_exists" == false ]]; then
    echo "  ✗ ALB '$load_balancer_name' not found"
  else
    echo "  ✓ ALB exists"
  fi
  
  if [[ "$alb_active" == false ]]; then
    echo "  ✗ ALB not active"
    echo "    Got: $alb_state"
  else
    echo "  ✓ ALB is active"
  fi
  
  if [[ "$tg_exists" == false ]]; then
    echo "  ✗ Target group '$target_group_name' not found"
  else
    echo "  ✓ Target group exists"
  fi
  
  if [[ "$target_registered" == false ]]; then
    echo "  ✗ Target health validation failed"
    echo "    Expected: healthy or initial"
    echo "    Got: $target_health"
  else
    echo "  ✓ Target is registered and healthy"
  fi
  
  if [[ "$nginx_accessible" == false ]]; then
    echo "  ✗ Nginx not accessible via ALB"
    echo "    ALB DNS: $alb_dns"
  else
    echo "  ✓ Nginx accessible via ALB"
  fi
fi
```

</details>
