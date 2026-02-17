#!/bin/bash
# Setup: Create the existing environment for the Day 30 NAT Instance scenario
# This builds everything described under "Existing Environment" in day30-reach.md

set -euo pipefail
export AWS_REGION=ca-central-1

BUCKET_NAME="reach-devops-nat-15195"

echo "=== Setting up Day 30 scenario environment ==="

# --- Step 1: Create VPC ---
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --query 'Vpc.VpcId' --output text) && echo "VPC: $VPC_ID"

aws ec2 create-tags --resources "$VPC_ID" \
  --tags Key=Name,Value=reach-devops-priv-vpc

# Enable DNS support and hostnames
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-support '{"Value":true}'
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames '{"Value":true}'

# --- Step 2: Create private subnet ---
PRIV_SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.0.1.0/24 \
  --availability-zone ca-central-1a \
  --query 'Subnet.SubnetId' --output text) && echo "Private subnet: $PRIV_SUBNET_ID"

aws ec2 create-tags --resources "$PRIV_SUBNET_ID" \
  --tags Key=Name,Value=reach-devops-priv-subnet

# --- Step 3: Create and attach Internet Gateway (not routed yet) ---
IGW_ID=$(aws ec2 create-internet-gateway \
  --query 'InternetGateway.InternetGatewayId' --output text) && echo "IGW: $IGW_ID"

aws ec2 create-tags --resources "$IGW_ID" \
  --tags Key=Name,Value=reach-devops-igw

aws ec2 attach-internet-gateway \
  --internet-gateway-id "$IGW_ID" \
  --vpc-id "$VPC_ID"

# --- Step 4: Create S3 bucket ---
aws s3 mb "s3://$BUCKET_NAME" --region "$AWS_REGION" && echo "S3 bucket: $BUCKET_NAME"

# --- Step 5: Create IAM role for EC2 to write to S3 ---
echo "Creating IAM role and instance profile..."

aws iam create-role \
  --role-name reach-devops-ec2-s3-role \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "ec2.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }' --output text --query 'Role.Arn'

aws iam put-role-policy \
  --role-name reach-devops-ec2-s3-role \
  --policy-name s3-upload-policy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:GetObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::'"$BUCKET_NAME"'",
        "arn:aws:s3:::'"$BUCKET_NAME"'/*"
      ]
    }]
  }'

aws iam create-instance-profile \
  --instance-profile-name reach-devops-ec2-s3-profile \
  --output text --query 'InstanceProfile.Arn'

aws iam add-role-to-instance-profile \
  --instance-profile-name reach-devops-ec2-s3-profile \
  --role-name reach-devops-ec2-s3-role

# Wait for instance profile to propagate
echo "Waiting for instance profile to propagate..."
sleep 10

# --- Step 6: Get Amazon Linux 2 AMI ---
AMI_ID=$(aws ec2 describe-images --owners amazon \
  --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" "Name=state,Values=available" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' --output text) && echo "AMI: $AMI_ID"

# --- Step 7: Launch private EC2 instance with cron job user data ---
# The cron job attempts to upload a test file to S3 every 30 seconds.
# It will only succeed once the team configures NAT for internet access.
USERDATA=$(cat <<'EOF'
#!/bin/bash
BUCKET="reach-devops-nat-15195"
FILE="/tmp/reach-devops-test.txt"

# Create the test file
echo "NAT instance connectivity test - $(hostname) - $(date)" > "$FILE"

# Create a script that uploads to S3
cat <<'SCRIPT' > /usr/local/bin/s3-upload.sh
#!/bin/bash
BUCKET="reach-devops-nat-15195"
FILE="/tmp/reach-devops-test.txt"
echo "NAT instance connectivity test - $(hostname) - $(date)" > "$FILE"
aws s3 cp "$FILE" "s3://$BUCKET/reach-devops-test.txt" 2>>/var/log/s3-upload.log
SCRIPT

chmod +x /usr/local/bin/s3-upload.sh

# Run every 30 seconds using a cron job + a 30-second delayed copy
echo "* * * * * root /usr/local/bin/s3-upload.sh" > /etc/cron.d/s3-upload
echo "* * * * * root sleep 30 && /usr/local/bin/s3-upload.sh" >> /etc/cron.d/s3-upload
chmod 0644 /etc/cron.d/s3-upload
EOF
)

INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type t2.micro \
  --subnet-id "$PRIV_SUBNET_ID" \
  --iam-instance-profile Name=reach-devops-ec2-s3-profile \
  --user-data "$USERDATA" \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=reach-devops-priv-ec2}]' \
  --query 'Instances[0].InstanceId' --output text) && echo "EC2 instance: $INSTANCE_ID"

echo "Waiting for instance to be running..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

echo ""
echo "=== Scenario environment ready ==="
echo ""
echo "Resources created:"
echo "  VPC:             $VPC_ID (reach-devops-priv-vpc, 10.0.0.0/16)"
echo "  Private subnet:  $PRIV_SUBNET_ID (reach-devops-priv-subnet, 10.0.1.0/24)"
echo "  Internet GW:     $IGW_ID (reach-devops-igw, attached but not routed)"
echo "  S3 bucket:       $BUCKET_NAME"
echo "  EC2 instance:    $INSTANCE_ID (reach-devops-priv-ec2, cron uploading every 30s)"
echo "  IAM role:        reach-devops-ec2-s3-role"
echo ""
echo "The EC2 instance has a cron job trying to upload to S3 every 30 seconds."
echo "It will fail until the team configures a NAT instance for internet access."
