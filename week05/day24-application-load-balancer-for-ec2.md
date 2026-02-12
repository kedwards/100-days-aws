# Day 24 - Create Application Load Balancer

## Task

The Nautilus DevOps team is currently working on setting up a simple application on the AWS cloud. They aim to establish an Application Load Balancer (ALB) in front of an EC2 instance where an Nginx server is currently running. While the Nginx server currently serves a sample page, the team plans to deploy the actual application later.

1. Set up an Application Load Balancer named datacenter-alb.
2. Create a target group named datacenter-tg.
3. Create a security group named datacenter-sg to open port 80 for the public.
4. Attach this security group to the ALB.
5. The ALB should route traffic on port 80 to port 80 of the datacenter-ec2 instance.
6. Make appropriate changes in the default security group attached to the EC2 instance if necessary.

## Help

```bash
aws ec2 describe-vpcs help
aws ec2 describe-instances help
aws ec2 describe-security-groups help
aws ec2 create-security-group help
aws ec2 authorize-security-group-ingress help
aws ec2 describe-subnets help
aws elbv2 create-target-group help
aws elbv2 register-targets help
aws elbv2 create-load-balancer help
aws elbv2 create-listener help
aws elbv2 describe-load-balancers help
aws elbv2 describe-target-health help
aws elbv2 describe-listeners help
```

<details>
<summary><h2>Solution</h2></summary>


```bash
instance_name=datacenter-ec2
alb_name=datacenter-alb
tg_name=datacenter-tg
sg_name=datacenter-sg

read -r vpc_id < <(aws ec2 describe-vpcs \
  --query "Vpcs[?IsDefault].VpcId" \
  --output text) && echo "VPC ID: $vpc_id"

# Get instance ID
read -r instance_id < <(aws ec2 describe-instances \
  --filter "Name=tag:Name,Values=$instance_name" \
  --query "Reservations[*].Instances[*].InstanceId" \
  --output text) && echo "Instance ID: $instance_id"

# Get default security group
read -r default_sg < <(aws ec2 describe-security-groups \
  --query "SecurityGroups[?GroupName=='default'].GroupId" \
  --output text) && echo "Default SG: $default_sg"

# Create security group for ALB
read -r alb_sg < <(aws ec2 create-security-group \
  --group-name "$sg_name" \
  --description "Security group for $alb_name" \
  --vpc-id "$vpc_id" \
  --query "GroupId" \
  --output text) && echo "ALB SG: $alb_sg"

# Allow HTTP traffic to ALB
aws ec2 authorize-security-group-ingress \
  --group-id "$alb_sg" \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

# Allow ALB to communicate with instance
aws ec2 authorize-security-group-ingress \
  --group-id "$default_sg" \
  --protocol tcp \
  --port 80 \
  --source-group "$alb_sg"

# Create target group
read -r tg_arn < <(aws elbv2 create-target-group \
  --name "$tg_name" \
  --protocol HTTP \
  --port 80 \
  --target-type instance \
  --vpc-id "$vpc_id" \
  --query "TargetGroups[0].TargetGroupArn" \
  --output text) && echo "Target group created: $tg_arn"

# Register instance to target group
aws elbv2 register-targets \
  --target-group-arn "$tg_arn" \
  --targets "Id=$instance_id,Port=80"

# Get subnets for ALB (need at least 2 in different AZs)
read -r subnet1 subnet2 < <(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$vpc_id" \
  --query "Subnets[0:2].SubnetId" \
  --output text) && echo "Subnets: $subnet1, $subnet2"

# Create Application Load Balancer
read -r alb_arn < <(aws elbv2 create-load-balancer \
  --name "$alb_name" \
  --security-groups "$alb_sg" \
  --subnets "$subnet1" "$subnet2" \
  --query "LoadBalancers[0].LoadBalancerArn" \
  --output text) && echo "ALB created: $alb_arn"

aws elbv2 wait load-balancer-exists \
  --load-balancer-arns "$alb_arn" && echo "ALB is now available"

# Create listener
aws elbv2 create-listener \
  --load-balancer-arn "$alb_arn" \
  --protocol HTTP \
  --port 80 \
  --default-actions "Type=forward,TargetGroupArn=$tg_arn"
```

</details>

<details>
<summary><h2>Validate</h2></summary>


```bash
aws elbv2 describe-load-balancers --names "$alb_name" \
  --query "LoadBalancers[].{Name:LoadBalancerName,DNSName:DNSName,State:State.Code}" \
  --output table

aws elbv2 describe-target-health --target-group-arn "$tg_arn" \
  --query "TargetHealthDescriptions[].{Target:Target.Id,Health:TargetHealth.State}" \
  --output table
```

```bash
instance_name=datacenter-ec2
alb_name=datacenter-alb
tg_name=datacenter
sg_name=datacenter-sg

read -r alb_state alb_dns < <(aws elbv2 describe-load-balancers --names "$alb_name" \
  --query "LoadBalancers[0].[State.Code,DNSName]" \
  --output text) && echo "ALB state: $alb_state, DNS: $alb_dns"

read -r target_health < <(aws elbv2 describe-target-health --target-group-arn "$tg_arn" \
  --query "TargetHealthDescriptions[?Target.Id=='$instance_id'].TargetHealth.State" \
  --output text) && echo "Target health: $target_health"

read -r listener_count < <(aws elbv2 describe-listeners --load-balancer-arn "$alb_arn" \
  --query "length(Listeners)" \
  --output text) && echo "Listeners: $listener_count"

# Check validation
alb_exists=false
alb_active=false
target_registered=false
listener_configured=false

[[ -n "$alb_state" && "$alb_state" != "None" ]] && alb_exists=true
[[ "$alb_state" == "active" ]] && alb_active=true
[[ "$target_health" == "healthy" || "$target_health" == "initial" ]] && target_registered=true
[[ "$listener_count" -gt 0 ]] && listener_configured=true

if [[ "$alb_exists" == true ]] && [[ "$alb_active" == true ]] && [[ "$target_registered" == true ]] && [[ "$listener_configured" == true ]]; then
  echo "✓ Success"
  echo "  ALB name: $alb_name"
  echo "  ALB DNS: $alb_dns"
  echo "  ALB state: $alb_state"
  echo "  Target health: $target_health"
  echo "  Listeners: $listener_count"
else
  echo "✗ Fail"
  
  if [[ "$alb_exists" == false ]]; then
    echo "  ✗ ALB not found"
  else
    echo "  ✓ ALB exists"
  fi
  
  if [[ "$alb_active" == false ]]; then
    echo "  ✗ ALB state validation failed"
    echo "    Expected: active"
    echo "    Got: $alb_state"
  else
    echo "  ✓ ALB state validation passed"
  fi
  
  if [[ "$target_registered" == false ]]; then
    echo "  ✗ Target health validation failed"
    echo "    Expected: healthy or initial"
    echo "    Got: $target_health"
  else
    echo "  ✓ Target health validation passed"
  fi
  
  if [[ "$listener_configured" == false ]]; then
    echo "  ✗ No listener configured"
  else
    echo "  ✓ Listener configured"
  fi
fi
```

</details>
