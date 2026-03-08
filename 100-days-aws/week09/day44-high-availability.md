# Day 44: Implementing Auto Scaling for High Availability in AWS

## Task

The DevOps team is tasked with setting up a highly available web application using AWS. To achieve this, they plan to use an Auto Scaling Group (ASG) to ensure that the required number of EC2 instances are always running, and an Application Load Balancer (ALB) to distribute traffic across these instances. The goal of this task is to set up an ASG that automatically scales EC2 instances based on CPU utilization, and an ALB that directs incoming traffic to the instances. The EC2 instances should have Nginx installed and running to serve web traffic.

    Create an EC2 launch template named xfusion-launch-template that specifies the configuration for the EC2 instances, including the Amazon Linux 2 AMI, t2.micro instance type, and a security group that allows HTTP traffic on port 80.
    Add a User Data script to the launch template to install Nginx on the EC2 instances when they are launched. The script should install Nginx, start the Nginx service, and enable it to start on boot.
    Create an Auto Scaling Group named xfusion-asg that uses the launch template and ensures a minimum of 1 instance, desired capacity is 1 instance and a maximum of 2 instances are running based on CPU utilization. Set the target CPU utilization to 50%.
    Create a target group named xfusion-tg, an Application Load Balancer named xfusion-alb and configure it to listen on port 80. Ensure the ALB is associated with the Auto Scaling Group and distributes traffic across the instances.
    Configure health checks on the ALB to ensure it routes traffic only to healthy instances.
    Verify that the ALB's DNS name is accessible and that it displays the default Nginx page served by the EC2 instances.

## Help

```bash
aws ec2 create-launch-template help
aws ec2 describe-launch-templates help
aws autoscaling create-auto-scaling-group help
aws autoscaling describe-auto-scaling-groups help
aws autoscaling put-scaling-policy help
aws elbv2 create-load-balancer help
aws elbv2 create-target-group help
aws elbv2 create-listener help
aws elbv2 describe-load-balancers help
aws elbv2 describe-target-health help
```

<details>
<summary><h2>Solution</h2></summary>

```bash
prefix=xfusion
launch_template_name="${prefix}-launch-template"
ec2_instance_type=t2.micro
auto_scaling_group_name="${prefix}-asg"
load_balancer_name="${prefix}-alb"
target_group_name="${prefix}-tg"
min_size=1
max_size=2

# ── Get VPC and subnets ──────────────────────────────────────
vpc_id=$(aws ec2 describe-vpcs \
  --query "Vpcs[0].VpcId" \
  --output text) && echo "VPC ID: $vpc_id"

subnet_ids=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$vpc_id" \
    "Name=availability-zone,Values=us-east-1a,us-east-1b" \
  --query "Subnets[*].SubnetId" \
  --output text) && echo "Subnet IDs: $subnet_ids"

# ── Configure security group ─────────────────────────────────
security_group_id=$(aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=$vpc_id" \
    "Name=group-name,Values=default" \
  --query "SecurityGroups[0].GroupId" \
  --output text) && echo "Security Group ID: $security_group_id"

aws ec2 authorize-security-group-ingress \
  --group-id $security_group_id \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

# ── Create launch template ───────────────────────────────────
amazon_image=resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64

cat<<EOF > launch_template.json
{
  "ImageId": "$amazon_image",
  "InstanceType": "$ec2_instance_type",
  "SecurityGroupIds": ["$security_group_id"],
  "UserData": "$(base64 -w 0 <<'EOL'
#!/bin/bash
yum update -y
yum install -y nginx
systemctl start nginx
systemctl enable nginx
EOL
)"
}
EOF

launch_template_id=$(aws ec2 create-launch-template \
  --launch-template-name "$launch_template_name" \
  --launch-template-data file://launch_template.json \
  --query "LaunchTemplate.LaunchTemplateId" \
  --output text) && echo "Launch Template ID: $launch_template_id"

# ── Create load balancer ─────────────────────────────────────
alb_arn=$(aws elbv2 create-load-balancer \
  --name $load_balancer_name \
  --subnets ${subnet_ids} \
  --security-groups $security_group_id \
  --query "LoadBalancers[0].LoadBalancerArn" \
  --output text) && echo "ALB ARN: $alb_arn"

# ── Create target group ──────────────────────────────────────
target_group_arn=$(aws elbv2 create-target-group \
  --name $target_group_name \
  --protocol HTTP \
  --port 80 \
  --target-type instance \
  --vpc-id $vpc_id \
  --query "TargetGroups[0].TargetGroupArn" \
  --output text) && echo "Target Group ARN: $target_group_arn"

# ── Create Auto Scaling Group ────────────────────────────────
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name "$auto_scaling_group_name" \
  --launch-template LaunchTemplateId=$launch_template_id \
  --target-group-arns "$target_group_arn" \
  --min-size "$min_size" \
  --max-size "$max_size" \
  --health-check-type 'ELB' \
  --health-check-grace-period '300' \
  --desired-capacity "$min_size" \
  --vpc-zone-identifier "$(echo "$subnet_ids" | tr '\t ' ',')"

# ── Configure scaling policy ─────────────────────────────────
cat<<EOF > scaling_policy.json
{
  "DisableScaleIn": false,
  "PredefinedMetricSpecification": {
    "PredefinedMetricType": "ASGAverageCPUUtilization"
  },
  "TargetValue": 50
}
EOF

aws autoscaling put-scaling-policy \
  --auto-scaling-group-name "$auto_scaling_group_name" \
  --policy-name 'Target Tracking Policy' \
  --policy-type 'TargetTrackingScaling' \
  --target-tracking-configuration file://scaling_policy.json

# ── Create listener and test ─────────────────────────────────
aws elbv2 create-listener \
  --load-balancer-arn $alb_arn \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=$target_group_arn

alb_dns_name=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?LoadBalancerName=='$load_balancer_name'].DNSName" \
  --output text) && echo "ALB DNS: $alb_dns_name"

curl -s http://$alb_dns_name 
```
</details>

<details>
<summary><h2>Validate</h2></summary>

```bash
aws ec2 describe-launch-templates --launch-template-names xfusion-launch-template --output table
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names xfusion-asg --output table
aws elbv2 describe-load-balancers --names xfusion-alb --output table
aws elbv2 describe-target-groups --names xfusion-tg --output table
```

```bash
prefix=devops
launch_template_name=$prefix-launch-template
auto_scaling_group_name=$prefix-asg
load_balancer_name=$prefix-alb
target_group_name=$prefix-tg
expected_min_size=1
expected_max_size=2

# Check launch template exists
read -r template_id template_version <<< "$(aws ec2 describe-launch-templates \
  --launch-template-names "$launch_template_name" \
  --query "LaunchTemplates[0].[LaunchTemplateId,LatestVersionNumber]" \
  --output text 2>/dev/null)"&& echo "Launch Template: $template_id, Version: $template_version"

# Check ASG configuration
read -r asg_min asg_max asg_desired health_check <<< "$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$auto_scaling_group_name" \
  --query "AutoScalingGroups[0].[MinSize,MaxSize,DesiredCapacity,HealthCheckType]" \
  --output text 2>/dev/null)"&& echo "ASG Min: $asg_min, Max: $asg_max, Desired: $asg_desired, Health: $health_check"

# Check ALB status
read -r alb_state alb_dns <<< "$(aws elbv2 describe-load-balancers \
  --names "$load_balancer_name" \
  --query "LoadBalancers[0].[State.Code,DNSName]" \
  --output text 2>/dev/null)"&& echo "ALB State: $alb_state, DNS: $alb_dns"

# Check target group
tg_port=$(aws elbv2 describe-target-groups \
  --names "$target_group_name" \
  --query "TargetGroups[0].Port" \
  --output text 2>/dev/null) && echo "Target Group Port: $tg_port"

# Check target health
target_health=$(aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --names "$target_group_name" \
    --query "TargetGroups[0].TargetGroupArn" \
    --output text 2>/dev/null) \
  --query "TargetHealthDescriptions[0].TargetHealth.State" \
  --output text 2>/dev/null) && echo "Target Health: $target_health"

# Validation checks
template_valid=false
asg_min_valid=false
asg_max_valid=false
health_check_valid=false
alb_valid=false
tg_valid=false

[[ -n "$template_id" ]] && template_valid=true
[[ "$asg_min" == "$expected_min_size" ]] && asg_min_valid=true
[[ "$asg_max" == "$expected_max_size" ]] && asg_max_valid=true
[[ "$health_check" == "ELB" ]] && health_check_valid=true
[[ "$alb_state" == "active" ]] && alb_valid=true
[[ "$tg_port" == "80" ]] && tg_valid=true

if [[ "$template_valid" == true ]] && [[ "$asg_min_valid" == true ]] && [[ "$asg_max_valid" == true ]] && [[ "$health_check_valid" == true ]] && [[ "$alb_valid" == true ]] && [[ "$tg_valid" == true ]]; then
  echo "✓ Success"
  echo "  Launch Template: $launch_template_name ($template_id)"
  echo "  ASG: $auto_scaling_group_name (Min: $asg_min, Max: $asg_max, Desired: $asg_desired)"
  echo "  Health Check Type: $health_check"
  echo "  ALB: $load_balancer_name ($alb_state)"
  echo "  ALB DNS: $alb_dns"
  echo "  Target Group: $target_group_name (Port: $tg_port)"
  echo "  Target Health: $target_health"
else
  echo "✗ Fail"
  
  if [[ "$template_valid" == false ]]; then
    echo "  ✗ Launch template not found"
    echo "    Expected: $launch_template_name"
  else
    echo "  ✓ Launch template exists"
  fi
  
  if [[ "$asg_min_valid" == false ]]; then
    echo "  ✗ ASG min size incorrect"
    echo "    Expected: $expected_min_size"
    echo "    Got: $asg_min"
  else
    echo "  ✓ ASG min size correct"
  fi
  
  if [[ "$asg_max_valid" == false ]]; then
    echo "  ✗ ASG max size incorrect"
    echo "    Expected: $expected_max_size"
    echo "    Got: $asg_max"
  else
    echo "  ✓ ASG max size correct"
  fi
  
  if [[ "$health_check_valid" == false ]]; then
    echo "  ✗ Health check type incorrect"
    echo "    Expected: ELB"
    echo "    Got: $health_check"
  else
    echo "  ✓ Health check type is ELB"
  fi
  
  if [[ "$alb_valid" == false ]]; then
    echo "  ✗ ALB not active"
    echo "    State: $alb_state"
  else
    echo "  ✓ ALB is active"
  fi
  
  if [[ "$tg_valid" == false ]]; then
    echo "  ✗ Target group port incorrect"
    echo "    Expected: 80"
    echo "    Got: $tg_port"
  else
    echo "  ✓ Target group port is 80"
  fi
fi
```

</details>
