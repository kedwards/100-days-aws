# Day 25 - EC2 Instance with CloudWatch Alarm

## Task

The Nautilus DevOps team has been tasked with setting up an EC2 instance for their application. To ensure the application performs optimally, they also need to create a CloudWatch alarm to monitor the instance's CPU utilization. The alarm should trigger if the CPU utilization exceeds 90% for one consecutive 5-minute period. To send notifications, use the SNS topic named xfusion-sns-topic which is already created.

1. Launch EC2 Instance: Create an EC2 instance named xfusion-ec2 using any appropriate Ubuntu AMI.
2. Create CloudWatch Alarm: Create a CloudWatch alarm named xfusion-alarm with the following specifications:
  - Statistic: Average
  - Metric: CPU Utilization
  - Threshold: >= 90% for 1 consecutive 5-minute period.
  - Alarm Actions: Send a notification to xfusion-sns-topic.

## Help

```bash
aws ec2 describe-images help
aws ec2 run-instances help
aws ec2 describe-instances help
aws sns create-topic help
aws sns subscribe help
aws sns list-topics help
aws cloudwatch put-metric-alarm help
aws cloudwatch describe-alarms help
```

<details>
<summary><h2>Solution</h2></summary>


```bash
instance_name=xfusion-ec2
instance_type=t2.micro
region=us-east-1
alarm_name=xfusion-alarm
alarm_metric=CPUUtilization
alarm_statistic=Average
alarm_topic=xfusion-sns-topic

alarm_topic_arn=$(aws sns create-topic \
  --name xfusion-sns-topic \
  --query "TopicArn" \
  --output text) && echo "SNS Topic ARN: $alarm_topic_arn"

aws sns subscribe \
  --protocol 'email' \
  --topic-arn "$alarm_topic_arn" \
  --endpoint 'devops@withreach.com' \
  --attributes '{}' \
  --return-subscription-arn

cat <<'EOF' > user-data.sh
#!/bin/bash
set -eux

# Burn CPU on all cores
CORES=$(nproc)

for i in $(seq 1 "$CORES"); do
  nohup bash -c "while :; do :; done" &
done
EOF

#
# Ubuntu 24.04 - resolve:ssm:/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id
# Amazon Linux 2023 - resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 
#
aws ec2 run-instances \
  --image-id \
    resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --instance-type "$instance_type" \
  --region "$region" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value="$instance_name"}]" \
  --user-data file://user-data.sh

sns_topic_arn=$(aws sns list-topics \
  --query "Topics[?contains(TopicArn, '$alarm_topic')].TopicArn" \
  --output text) && echo "SNS Topic ARN: $sns_topic_arn"

aws cloudwatch put-metric-alarm \
  --alarm-name "$alarm_name" \
  --metric-name "$alarm_metric" \
  --namespace AWS/EC2 \
  --statistic "$alarm_statistic" \
  --period 300 \
  --threshold 90 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --evaluation-periods 1 \
  --alarm-actions "$sns_topic_arn" \
  --dimensions Name=InstanceId,Value=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$instance_name" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text) \
  --region "$region"

```

</details>

<details>
<summary><h2>Validate</h2></summary>


```bash
aws ec2 describe-instances --filters "Name=tag:Name,Values=$instance_name" \
  --query "Reservations[].Instances[].{InstanceId:InstanceId,State:State.Name,Type:InstanceType}" \
  --output table

aws cloudwatch describe-alarms --alarm-names "$alarm_name" \
  --query "MetricAlarms[].{Name:AlarmName,Metric:MetricName,Threshold:Threshold,State:StateValue}" \
  --output table
```

```bash
read -r instance_id instance_state <<< "$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$instance_name" \
  --query "Reservations[0].Instances[0].[InstanceId,State.Name]" \
  --output text)" && echo "Instance ID: $instance_id, State: $instance_state"

read -r alarm_state alarm_threshold alarm_metric alarm_namespace <<< "$(aws cloudwatch describe-alarms \
  --alarm-names "$alarm_name" \
  --query "MetricAlarms[0].[StateValue,Threshold,MetricName,Namespace]" \
  --output text)" && echo "Alarm state: $alarm_state, Threshold: $alarm_threshold, Metric: $alarm_metric, Namespace: $alarm_namespace"

alarm_dimensions=$(aws cloudwatch describe-alarms \
  --alarm-names "$alarm_name" \
  --query "MetricAlarms[0].Dimensions[?Name=='InstanceId'].Value" \
  --output text) && echo "Alarm monitoring instance: $alarm_dimensions"

alarm_actions=$(aws cloudwatch describe-alarms \
  --alarm-names "$alarm_name" \
  --query "MetricAlarms[0].AlarmActions[0]" \
  --output text) && echo "Alarm action: $alarm_actions"

# Check validation
instance_exists=false
instance_running=false
alarm_exists=false
alarm_configured=false
instance_monitored=false
sns_configured=false

[[ -n "$instance_id" && "$instance_id" != "None" ]] && instance_exists=true
[[ "$instance_state" == "running" ]] && instance_running=true
[[ -n "$alarm_state" && "$alarm_state" != "None" ]] && alarm_exists=true
[[ "$alarm_threshold" == "90.0" && "$alarm_metric" == "CPUUtilization" && "$alarm_namespace" == "AWS/EC2" ]] && alarm_configured=true
[[ "$alarm_dimensions" == "$instance_id" ]] && instance_monitored=true
[[ "$alarm_actions" == *"$alarm_topic"* ]] && sns_configured=true

if [[ "$instance_exists" == true ]] && [[ "$instance_running" == true ]] && [[ "$alarm_exists" == true ]] && [[ "$alarm_configured" == true ]] && [[ "$instance_monitored" == true ]] && [[ "$sns_configured" == true ]]; then
  echo "✓ Success"
  echo "  Instance ID: $instance_id"
  echo "  Instance state: $instance_state"
  echo "  Alarm name: $alarm_name"
  echo "  Alarm state: $alarm_state"
  echo "  Metric: $alarm_metric (Threshold: $alarm_threshold%)"
  echo "  Monitoring instance: $alarm_dimensions"
  echo "  SNS topic: Configured"
else
  echo "✗ Fail"
  
  if [[ "$instance_exists" == false ]]; then
    echo "  ✗ Instance not found"
  else
    echo "  ✓ Instance exists"
  fi
  
  if [[ "$instance_running" == false ]]; then
    echo "  ✗ Instance state validation failed"
    echo "    Expected: running"
    echo "    Got: $instance_state"
  else
    echo "  ✓ Instance state validation passed"
  fi
  
  if [[ "$alarm_exists" == false ]]; then
    echo "  ✗ Alarm not found"
  else
    echo "  ✓ Alarm exists"
  fi
  
  if [[ "$alarm_configured" == false ]]; then
    echo "  ✗ Alarm configuration validation failed"
    echo "    Expected: Threshold=90.0, Metric=CPUUtilization, Namespace=AWS/EC2"
    echo "    Got: Threshold=$alarm_threshold, Metric=$alarm_metric, Namespace=$alarm_namespace"
  else
    echo "  ✓ Alarm configuration validation passed"
  fi
  
  if [[ "$instance_monitored" == false ]]; then
    echo "  ✗ Alarm not monitoring the correct instance"
    echo "    Expected: $instance_id"
    echo "    Got: $alarm_dimensions"
  else
    echo "  ✓ Alarm monitoring correct instance"
  fi
  
  if [[ "$sns_configured" == false ]]; then
    echo "  ✗ SNS topic not configured"
    echo "    Expected: reach-sns-topic in alarm actions"
    echo "    Got: $alarm_actions"
  else
    echo "  ✓ SNS topic configured"
  fi
fi
```

</details>
