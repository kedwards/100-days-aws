#!/bin/bash
# Cleanup: Remove ONLY the resources created by the solver (reset for reattempt)
# Leaves the scenario infrastructure intact (VPC, private subnet, IGW, private EC2, S3 bucket, IAM role)

set -euo pipefail
export AWS_REGION=ca-central-1

echo "=== Resetting solved resources for reattempt ==="

# Get NAT instance ID
NAT_INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=reach-devops-nat-instance" "Name=instance-state-name,Values=running,stopped" \
  --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null || echo "None")

if [ "$NAT_INSTANCE_ID" != "None" ] && [ -n "$NAT_INSTANCE_ID" ]; then
  echo "Terminating NAT instance: $NAT_INSTANCE_ID"
  aws ec2 terminate-instances --instance-ids "$NAT_INSTANCE_ID"
  aws ec2 wait instance-terminated --instance-ids "$NAT_INSTANCE_ID"
  echo "NAT instance terminated"
else
  echo "No NAT instance found, skipping"
fi

# Get VPC ID
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=reach-devops-priv-vpc" \
  --query 'Vpcs[0].VpcId' --output text)

# Remove the 0.0.0.0/0 route from the private route table (main)
PRIV_RTB_ID=$(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=association.main,Values=true" \
  --query 'RouteTables[0].RouteTableId' --output text)

echo "Removing NAT route from private route table: $PRIV_RTB_ID"
aws ec2 delete-route --route-table-id "$PRIV_RTB_ID" --destination-cidr-block 0.0.0.0/0 2>/dev/null || echo "No NAT route to remove"

# Get public route table
PUB_RTB_ID=$(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=association.main,Values=false" \
  --query 'RouteTables[0].RouteTableId' --output text 2>/dev/null || echo "None")

if [ "$PUB_RTB_ID" != "None" ] && [ -n "$PUB_RTB_ID" ]; then
  # Disassociate the public route table
  ASSOC_ID=$(aws ec2 describe-route-tables --route-table-ids "$PUB_RTB_ID" \
    --query 'RouteTables[0].Associations[?!Main].RouteTableAssociationId | [0]' --output text 2>/dev/null || echo "None")
  if [ "$ASSOC_ID" != "None" ] && [ -n "$ASSOC_ID" ]; then
    echo "Disassociating public route table"
    aws ec2 disassociate-route-table --association-id "$ASSOC_ID"
  fi
  echo "Deleting public route table: $PUB_RTB_ID"
  aws ec2 delete-route-table --route-table-id "$PUB_RTB_ID"
else
  echo "No public route table found, skipping"
fi

# Delete the public subnet
PUB_SUBNET_ID=$(aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=reach-devops-pub-subnet" \
  --query 'Subnets[0].SubnetId' --output text 2>/dev/null || echo "None")

if [ "$PUB_SUBNET_ID" != "None" ] && [ -n "$PUB_SUBNET_ID" ]; then
  echo "Deleting public subnet: $PUB_SUBNET_ID"
  aws ec2 delete-subnet --subnet-id "$PUB_SUBNET_ID"
else
  echo "No public subnet found, skipping"
fi

# Delete the NAT security group
NAT_SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=reach-devops-nat-sg" "Name=vpc-id,Values=$VPC_ID" \
  --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "None")

if [ "$NAT_SG_ID" != "None" ] && [ -n "$NAT_SG_ID" ]; then
  echo "Deleting NAT security group: $NAT_SG_ID"
  aws ec2 delete-security-group --group-id "$NAT_SG_ID"
else
  echo "No NAT security group found, skipping"
fi

# Clear the S3 bucket so the next attempt starts fresh
echo "Emptying S3 bucket"
aws s3 rm s3://reach-devops-nat-15195/ --recursive 2>/dev/null || echo "Bucket already empty"

echo ""
echo "=== Reset complete. Scenario is ready for reattempt ==="
