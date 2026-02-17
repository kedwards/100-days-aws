#!/bin/bash
# Cleanup: Remove EVERYTHING — the full scenario and any solved resources
# Run this when you're completely done with the exercise

set -euo pipefail
export AWS_REGION=ca-central-1

echo "=== Tearing down entire Day 30 scenario ==="

VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=reach-devops-priv-vpc" \
  --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "None")

if [ "$VPC_ID" == "None" ] || [ -z "$VPC_ID" ]; then
  echo "VPC not found, nothing to clean up"
  exit 0
fi

echo "VPC: $VPC_ID"

# --- Terminate ALL instances in the VPC ---
INSTANCE_IDS=$(aws ec2 describe-instances \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=instance-state-name,Values=running,stopped,pending" \
  --query 'Reservations[].Instances[].InstanceId' --output text)

if [ -n "$INSTANCE_IDS" ] && [ "$INSTANCE_IDS" != "None" ]; then
  echo "Terminating instances: $INSTANCE_IDS"
  aws ec2 terminate-instances --instance-ids $INSTANCE_IDS
  echo "Waiting for instances to terminate..."
  aws ec2 wait instance-terminated --instance-ids $INSTANCE_IDS
  echo "All instances terminated"
else
  echo "No instances to terminate"
fi

# --- Delete S3 bucket ---
echo "Deleting S3 bucket reach-devops-nat-15195"
aws s3 rb s3://reach-devops-nat-15195 --force 2>/dev/null || echo "Bucket already gone or empty"

# --- Delete IAM resources ---
echo "Cleaning up IAM role and instance profile"
aws iam remove-role-from-instance-profile \
  --instance-profile-name reach-devops-ec2-s3-profile \
  --role-name reach-devops-ec2-s3-role 2>/dev/null || true
aws iam delete-instance-profile \
  --instance-profile-name reach-devops-ec2-s3-profile 2>/dev/null || true
aws iam delete-role-policy \
  --role-name reach-devops-ec2-s3-role \
  --policy-name s3-upload-policy 2>/dev/null || true
aws iam delete-role \
  --role-name reach-devops-ec2-s3-role 2>/dev/null || true
echo "IAM resources cleaned up"

# --- Delete non-default security groups ---
SG_IDS=$(aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text)

for SG_ID in $SG_IDS; do
  echo "Deleting security group: $SG_ID"
  aws ec2 delete-security-group --group-id "$SG_ID" 2>/dev/null || echo "  Failed (may have dependencies), skipping"
done

# --- Delete subnets ---
SUBNET_IDS=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[].SubnetId' --output text)

for SUBNET_ID in $SUBNET_IDS; do
  echo "Deleting subnet: $SUBNET_ID"
  aws ec2 delete-subnet --subnet-id "$SUBNET_ID" 2>/dev/null || echo "  Failed, skipping"
done

# --- Delete non-main route tables ---
RTB_IDS=$(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text)

for RTB_ID in $RTB_IDS; do
  # Disassociate first
  ASSOC_IDS=$(aws ec2 describe-route-tables --route-table-ids "$RTB_ID" \
    --query 'RouteTables[0].Associations[?!Main].RouteTableAssociationId' --output text 2>/dev/null)
  for ASSOC_ID in $ASSOC_IDS; do
    aws ec2 disassociate-route-table --association-id "$ASSOC_ID" 2>/dev/null || true
  done
  echo "Deleting route table: $RTB_ID"
  aws ec2 delete-route-table --route-table-id "$RTB_ID" 2>/dev/null || echo "  Failed, skipping"
done

# --- Detach and delete Internet Gateway ---
IGW_ID=$(aws ec2 describe-internet-gateways \
  --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
  --query 'InternetGateways[0].InternetGatewayId' --output text 2>/dev/null || echo "None")

if [ "$IGW_ID" != "None" ] && [ -n "$IGW_ID" ]; then
  echo "Detaching and deleting IGW: $IGW_ID"
  aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"
  aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID"
else
  echo "No IGW found"
fi

# --- Delete the VPC ---
echo "Deleting VPC: $VPC_ID"
aws ec2 delete-vpc --vpc-id "$VPC_ID"

echo ""
echo "=== Full teardown complete ==="
