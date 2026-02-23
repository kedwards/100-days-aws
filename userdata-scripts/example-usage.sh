#!/bin/bash
# Example: Using userdata scripts with AWS EC2

# Common variables
prefix=myapp
region=us-east-1
instance_type=t2.micro
security_group_name="$prefix-sg"
instance_name="$prefix-ec2"

# Get VPC and create security group
vpc_id=$(aws ec2 describe-vpcs \
  --query "Vpcs[].VpcId" \
  --output text) && echo "VPC: $vpc_id"

ec2_security_group_id=$(aws ec2 create-security-group \
  --group-name $security_group_name \
  --description "Security group for $prefix" \
  --vpc-id "$vpc_id" \
  --query "GroupId" \
  --output text) && echo "Security Group: $ec2_security_group_id"

aws ec2 authorize-security-group-ingress \
  --group-id "$ec2_security_group_id" \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

# Ubuntu AMI
ubuntu_image=resolve:ssm:/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id

# =============================================================================
# Example 1: Python Flask Application
# =============================================================================
echo "Creating Python Flask EC2 instance..."
userdata_script=$(cat userdata-scripts/userdata-python.sh)

python_instance_id=$(aws ec2 run-instances \
  --image-id $ubuntu_image \
  --instance-type "$instance_type" \
  --region "$region" \
  --security-group-ids "$ec2_security_group_id" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance_name-python}]" \
  --user-data "$userdata_script" \
  --query "Instances[0].InstanceId" \
  --output text) && echo "Python Instance: $python_instance_id"

# =============================================================================
# Example 2: Golang Application
# =============================================================================
echo "Creating Golang EC2 instance..."
userdata_script=$(cat userdata-scripts/userdata-golang.sh)

go_instance_id=$(aws ec2 run-instances \
  --image-id $ubuntu_image \
  --instance-type "$instance_type" \
  --region "$region" \
  --security-group-ids "$ec2_security_group_id" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance_name-golang}]" \
  --user-data "$userdata_script" \
  --query "Instances[0].InstanceId" \
  --output text) && echo "Go Instance: $go_instance_id"

# =============================================================================
# Example 3: Node.js Application
# =============================================================================
echo "Creating Node.js EC2 instance..."
userdata_script=$(cat userdata-scripts/userdata-node.sh)

node_instance_id=$(aws ec2 run-instances \
  --image-id $ubuntu_image \
  --instance-type "$instance_type" \
  --region "$region" \
  --security-group-ids "$ec2_security_group_id" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance_name-node}]" \
  --user-data "$userdata_script" \
  --query "Instances[0].InstanceId" \
  --output text) && echo "Node Instance: $node_instance_id"

# =============================================================================
# Example 4: Using with file:// reference (alternative method)
# =============================================================================
# aws ec2 run-instances \
#   --image-id $ubuntu_image \
#   --instance-type "$instance_type" \
#   --region "$region" \
#   --security-group-ids "$ec2_security_group_id" \
#   --user-data file://userdata-scripts/userdata-python.sh \
#   --query "Instances[0].InstanceId" \
#   --output text

# Wait for instances
echo "Waiting for instances to start..."
aws ec2 wait instance-running --instance-ids "$python_instance_id" "$go_instance_id" "$node_instance_id"

# Get public IPs
python_ip=$(aws ec2 describe-instances \
  --instance-ids "$python_instance_id" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

go_ip=$(aws ec2 describe-instances \
  --instance-ids "$go_instance_id" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

node_ip=$(aws ec2 describe-instances \
  --instance-ids "$node_instance_id" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

echo ""
echo "==================================================================="
echo "Instances created successfully!"
echo "==================================================================="
echo "Python Flask: http://$python_ip"
echo "Golang:       http://$go_ip"
echo "Node.js:      http://$node_ip"
echo ""
echo "Note: Wait 2-3 minutes for userdata scripts to complete setup"
echo "Test health: curl http://$python_ip/health"
echo "==================================================================="
