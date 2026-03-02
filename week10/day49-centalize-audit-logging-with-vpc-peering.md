# Day 49: Centralized Audit Logging with VPC Peering

## Task

The Nautilus DevOps team needs to build a secure and scalable log aggregation setup within their AWS environment. The goal is to gather log files from an internal EC2 instance running in a private VPC, transfer them securely to another EC2 instance in a public VPC, and then push those logs to a secure S3 bucket.

1) A VPC named xfusion-priv-vpc already exists with a private subnet named xfusion-priv-subnet, a route table named xfusion-priv-rt, and an EC2 instance named xfusion-priv-ec2 (using ubuntu image). This instance uses the SSH key pair xfusion-key.pem already available on the AWS client host at /root/.ssh/.

2) Your task is to:

    Create a new VPC named xfusion-pub-vpc.
    Create a subnet named xfusion-pub-subnet and a route table named xfusion-pub-rt under this public VPC.
    Attach an internet gateway to xfusion-pub-vpc and configure the public route table to enable internet access.
    Launch an EC2 instance named xfusion-pub-ec2 into the public subnet using the same key pair as the private instance.
    Create an IAM role named xfusion-s3-role with PutObject permission to an S3 bucket and attach it to the public EC2 instance.
    Create a new private S3 bucket named xfusion-s3-logs-28694.
    Configure a VPC Peering named xfusion-vpc-peering between the private and public VPCs.
    Modify both xfusion-priv-rt and xfusion-pub-rt to route each other's CIDR blocks through the peering connection.
    On the private instance, configure a cron job to push the /var/log/boots.log file to the public instance (using scp or rsync).
    On the public instance, configure a cron job to push that same file to the created S3 bucket.
    The uploaded file must be stored in the S3 bucket under the path xfusion-priv-vpc/boot/boots.log.

## Help

```bash
aws ec2 create-vpc help
aws ec2 create-subnet help
aws ec2 create-route-table help
aws ec2 create-internet-gateway help
aws ec2 attach-internet-gateway help
aws ec2 create-route help
aws ec2 associate-route-table help
aws ec2 run-instances help
aws ec2 create-vpc-peering-connection help
aws ec2 accept-vpc-peering-connection help
aws ec2 create-security-group help
aws ec2 authorize-security-group-ingress help
aws iam create-role help
aws iam create-policy help
aws iam create-instance-profile help
aws s3api create-bucket help
aws s3 ls help
```

<details>
<summary><h2>Solution</h2></summary>

```bash
prefix="xfusion"
bucket_postfix=19793
priv_vpc_name="$prefix-priv-vpc"
priv_subnet_name="$prefix-priv-subnet"
priv_rt_name="$prefix-priv-rt"
priv_ec2_name="$prefix-priv-ec2"
pub_vpc_name="$prefix-pub-vpc"
pub_subnet_name="$prefix-pub-subnet"
pub_rt_name="$prefix-pub-rt"
pub_ec2_name="$prefix-pub-ec2"
peering_name="$prefix-vpc-peering"
s3_role_name="$prefix-s3-role"

s3_bucket_name="$prefix-s3-logs-${bucket_prefix}"
pub_vpc_cidr="10.1.0.0/16"
pub_subnet_cidr="10.1.1.0/24"
key_file="/root/.ssh/${prefix}-key.pem"

# ── Query existing private VPC resources ─────────────────────────
priv_vpc_id=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=$priv_vpc_name" \
  --query "Vpcs[0].VpcId" \
  --output text) && echo "Private VPC ID: $priv_vpc_id"

priv_vpc_cidr=$(aws ec2 describe-vpcs \
  --vpc-ids "$priv_vpc_id" \
  --query "Vpcs[0].CidrBlock" \
  --output text) && echo "Private VPC CIDR: $priv_vpc_cidr"

priv_rt_id=$(aws ec2 describe-route-tables \
  --filters "Name=tag:Name,Values=$priv_rt_name" \
  --query "RouteTables[0].RouteTableId" \
  --output text) && echo "Private Route Table ID: $priv_rt_id"

read -r priv_instance_id priv_private_ip priv_sg_id key_name <<< "$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$priv_ec2_name" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].[InstanceId,PrivateIpAddress,SecurityGroups[0].GroupId,KeyName]" \
  --output text)" && echo "Private EC2: $priv_instance_id, IP: $priv_private_ip, SG: $priv_sg_id, Key: $key_name"

# ── Create public VPC ────────────────────────────────────────────
pub_vpc_id=$(aws ec2 create-vpc \
  --cidr-block "$pub_vpc_cidr" \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$pub_vpc_name}]" \
  --query "Vpc.VpcId" \
  --output text) && echo "Public VPC ID: $pub_vpc_id"

# ── Create public subnet ────────────────────────────────────────
pub_subnet_id=$(aws ec2 create-subnet \
  --vpc-id "$pub_vpc_id" \
  --cidr-block "$pub_subnet_cidr" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$pub_subnet_name}]" \
  --query "Subnet.SubnetId" \
  --output text) && echo "Public Subnet ID: $pub_subnet_id"

aws ec2 modify-subnet-attribute \
  --subnet-id "$pub_subnet_id" \
  --map-public-ip-on-launch

# ── Create public route table ───────────────────────────────────
pub_rt_id=$(aws ec2 create-route-table \
  --vpc-id "$pub_vpc_id" \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$pub_rt_name}]" \
  --query "RouteTable.RouteTableId" \
  --output text) && echo "Public Route Table ID: $pub_rt_id"

aws ec2 associate-route-table \
  --route-table-id "$pub_rt_id" \
  --subnet-id "$pub_subnet_id" && echo "Associated route table with subnet"

# ── Create and attach Internet Gateway ───────────────────────────
igw_id=$(aws ec2 create-internet-gateway \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=$prefix-igw}]" \
  --query "InternetGateway.InternetGatewayId" \
  --output text) && echo "Internet Gateway ID: $igw_id"

aws ec2 attach-internet-gateway \
  --vpc-id "$pub_vpc_id" \
  --internet-gateway-id "$igw_id" && echo "Attached IGW to public VPC"

aws ec2 create-route \
  --route-table-id "$pub_rt_id" \
  --destination-cidr-block "0.0.0.0/0" \
  --gateway-id "$igw_id" && echo "Added internet route to public RT"

# ── Create security group for public EC2 ─────────────────────────
pub_sg_id=$(aws ec2 create-security-group \
  --group-name "$prefix-pub-sg" \
  --description "Public EC2 security group" \
  --vpc-id "$pub_vpc_id" \
  --query "GroupId" \
  --output text) && echo "Public Security Group ID: $pub_sg_id"

aws ec2 authorize-security-group-ingress \
  --group-id "$pub_sg_id" \
  --protocol tcp \
  --port 22 \
  --cidr "0.0.0.0/0" && echo "Allowed SSH from anywhere"

# ── Create IAM role with S3 PutObject permission ────────────────
cat <<EOF > /tmp/ec2-trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "ec2.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws iam create-role \
  --role-name "$s3_role_name" \
  --assume-role-policy-document file:///tmp/ec2-trust-policy.json && echo "Created role: $s3_role_name"

cat <<EOF > /tmp/s3-put-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::$s3_bucket_name/*"
    }
  ]
}
EOF

policy_arn=$(aws iam create-policy \
  --policy-name "$prefix-s3-put-policy" \
  --policy-document file:///tmp/s3-put-policy.json \
  --query "Policy.Arn" \
  --output text) && echo "Policy ARN: $policy_arn"

aws iam attach-role-policy \
  --role-name "$s3_role_name" \
  --policy-arn "$policy_arn" && echo "Attached policy to role"

aws iam create-instance-profile \
  --instance-profile-name "$s3_role_name" && echo "Created instance profile"

aws iam add-role-to-instance-profile \
  --instance-profile-name "$s3_role_name" \
  --role-name "$s3_role_name" && echo "Added role to instance profile"

# Allow time for IAM propagation
sleep 10

# ── Launch public EC2 instance ───────────────────────────────────
cat <<EOF > user-data.sh
#!/bin/bash
set -eux

apt update
apt install -y unzip curl
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
apt install chronie -y
systemctl enable chronie
systemctl start chronie

echo "* * * * * sleep 10 && /usr/local/bin/aws s3 cp /var/log/boots.log s3://$s3_bucket_name/$priv_vpc_name/boot/boots.log" \
  | crontab -
EOF

#
# Ubuntu 24.04 - resolve:ssm:/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id
# Amazon Linux 2023 - resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 
#
pub_instance_id=$(aws ec2 run-instances \
  --image-id \
    resolve:ssm:/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id \
  --instance-type t2.micro \
  --subnet-id "$pub_subnet_id" \
  --security-group-ids "$pub_sg_id" \
  --key-name "$key_name" \
  --iam-instance-profile Name="$s3_role_name" \
  --user-data file://user-data.sh \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$pub_ec2_name}]" \
  --query "Instances[0].InstanceId" \
  --output text) && echo "Public Instance ID: $pub_instance_id"

aws ec2 wait instance-running \
  --instance-ids "$pub_instance_id" && echo "Public instance is running"

read -r pub_public_ip pub_private_ip <<< "$(aws ec2 describe-instances \
  --instance-ids "$pub_instance_id" \
  --query "Reservations[0].Instances[0].[PublicIpAddress,PrivateIpAddress]" \
  --output text)" && echo "Public EC2 - Public IP: $pub_public_ip, Private IP: $pub_private_ip"

# ── Create private S3 bucket ────────────────────────────────────
aws s3api create-bucket \
  --bucket "$s3_bucket_name" \
  --region us-east-1 && echo "Created S3 bucket: $s3_bucket_name"

# ── Create VPC Peering ──────────────────────────────────────────
peering_id=$(aws ec2 create-vpc-peering-connection \
  --vpc-id "$priv_vpc_id" \
  --peer-vpc-id "$pub_vpc_id" \
  --tag-specifications "ResourceType=vpc-peering-connection,Tags=[{Key=Name,Value=$peering_name}]" \
  --query "VpcPeeringConnection.VpcPeeringConnectionId" \
  --output text) && echo "Peering Connection ID: $peering_id"

aws ec2 accept-vpc-peering-connection \
  --vpc-peering-connection-id "$peering_id" && echo "Accepted peering connection"

# ── Update route tables for peering ──────────────────────────────
aws ec2 create-route \
  --route-table-id "$priv_rt_id" \
  --destination-cidr-block "$pub_vpc_cidr" \
  --vpc-peering-connection-id "$peering_id" && echo "Added route: priv RT → pub VPC via peering"

aws ec2 create-route \
  --route-table-id "$pub_rt_id" \
  --destination-cidr-block "$priv_vpc_cidr" \
  --vpc-peering-connection-id "$peering_id" && echo "Added route: pub RT → priv VPC via peering"

# ── Allow SSH from public VPC to private EC2 security group ──────
aws ec2 authorize-security-group-ingress \
  --group-id "$priv_sg_id" \
  --protocol tcp \
  --port 22 \
  --cidr "$pub_vpc_cidr" && echo "Allowed SSH from public VPC to private EC2"

# Wait for instances to be fully initialized
sleep 30

# ── Copy SSH key to private instance via public jump host ────────
username="ubuntu"

chmod 600 "$key_file"

scp -i "$key_file" \
  -o "ProxyCommand=ssh -i $key_file -W %h:%p -o StrictHostKeyChecking=no $username@$pub_public_ip" \
  -o StrictHostKeyChecking=no \
  "$key_file" \
  ubuntu@"$priv_private_ip":/home/ubuntu/.ssh/${prefix}-key.pem

ssh -i "$key_file" \
  -o "ProxyCommand=ssh -i $key_file -W %h:%p -o StrictHostKeyChecking=no $username@$pub_public_ip" \
  -o StrictHostKeyChecking=no \
  $username@"$priv_private_ip" \
  "chmod 600 /home/ubuntu/.ssh/${prefix}-key.pem"

# ── Configure cron on private instance to SCP boots.log to public instance ─
ssh -i "$key_file" \
  -o "ProxyCommand=ssh -i $key_file -W %h:%p -o StrictHostKeyChecking=no $username@$pub_public_ip" \
  -o StrictHostKeyChecking=no \
  $username@"$priv_private_ip" \
  "echo '* * * * * /usr/bin/scp -i /home/ubuntu/.ssh/${prefix}-key.pem -o StrictHostKeyChecking=no /var/log/boots.log $username@$pub_private_ip:/tmp/boots.log' | crontab -"

# ── Configure cron on public instance to push boots.log to S3 ───
ssh -i "$key_file" \
  -o StrictHostKeyChecking=no \
  $username@"$pub_public_ip" \
  "echo '* * * * * sleep 30 && /usr/bin/aws s3 cp /tmp/boots.log s3://$s3_bucket_name/${prefix}-priv-vpc/boot/boots.log' | crontab -"

# ── Wait for cron jobs to execute and verify ─────────────────────
echo "Waiting 2 minutes for cron jobs to execute..."
sleep 120

aws s3 ls "s3://$s3_bucket_name/${prefix}-priv-vpc/boot/boots.log" && echo "✓ File successfully uploaded to S3"
```

</details>

<details>
<summary><h2>Validate</h2></summary>

```bash
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=xfusion-pub-vpc" --output table
aws ec2 describe-subnets --filters "Name=tag:Name,Values=xfusion-pub-subnet" --output table
aws ec2 describe-instances --filters "Name=tag:Name,Values=xfusion-pub-ec2" --output table
aws ec2 describe-vpc-peering-connections --filters "Name=tag:Name,Values=xfusion-vpc-peering" --output table
aws iam get-role --role-name xfusion-s3-role --output table
aws s3 ls s3://xfusion-s3-logs-28694/xfusion-priv-vpc/boot/
```

```bash
prefix="xfusion"
bucket_postfix=19793
priv_vpc_name="$prefix-priv-vpc"
priv_subnet_name="$prefix-priv-subnet"
priv_rt_name="$prefix-priv-rt"
priv_ec2_name="$prefix-priv-ec2"
pub_vpc_name="$prefix-pub-vpc"
pub_subnet_name="$prefix-pub-subnet"
pub_rt_name="$prefix-pub-rt"
pub_ec2_name="$prefix-pub-ec2"
peering_name="$prefix-vpc-peering"
s3_role_name="$prefix-s3-role"
s3_object_key="$prefix-priv-vpc/boot/boots.log"

s3_bucket_name="$prefix-s3-logs-${bucket_postfix}"
pub_vpc_cidr="10.1.0.0/16"
pub_subnet_cidr="10.1.1.0/24"
key_file="/root/.ssh/${prefix}-key.pem"

# Check public VPC
pub_vpc_id=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=$pub_vpc_name" \
  --query "Vpcs[0].VpcId" \
  --output text 2>/dev/null) && echo "Public VPC ID: $pub_vpc_id"

# Check public subnet
pub_subnet_id=$(aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=$pub_subnet_name" \
  --query "Subnets[0].SubnetId" \
  --output text 2>/dev/null) && echo "Public Subnet: $pub_subnet_id"

# Check public route table
pub_rt_id=$(aws ec2 describe-route-tables \
  --filters "Name=tag:Name,Values=$pub_rt_name" \
  --query "RouteTables[0].RouteTableId" \
  --output text 2>/dev/null) && echo "Public Route Table: $pub_rt_id"

# Check IGW attached to public VPC
igw_id=$(aws ec2 describe-internet-gateways \
  --filters "Name=attachment.vpc-id,Values=$pub_vpc_id" \
  --query "InternetGateways[0].InternetGatewayId" \
  --output text 2>/dev/null) && echo "Internet Gateway: $igw_id"

# Check internet route in public route table
igw_route=$(aws ec2 describe-route-tables \
  --route-table-ids "$pub_rt_id" \
  --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].GatewayId" \
  --output text 2>/dev/null) && echo "IGW route: $igw_route"

# Check public EC2 instance
read -r pub_instance_id pub_instance_state pub_instance_key <<< "$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$pub_ec2_name" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].[InstanceId,State.Name,KeyName]" \
  --output text 2>/dev/null)" && echo "Public EC2: $pub_instance_id, State: $pub_instance_state, Key: $pub_instance_key"

# Check IAM role exists
role_arn=$(aws iam get-role \
  --role-name "$s3_role_name" \
  --query "Role.Arn" \
  --output text 2>/dev/null) && echo "IAM Role ARN: $role_arn"

# Check instance profile attached to public EC2
instance_profile=$(aws ec2 describe-instances \
  --instance-ids "$pub_instance_id" \
  --query "Reservations[0].Instances[0].IamInstanceProfile.Arn" \
  --output text 2>/dev/null) && echo "Instance Profile: $instance_profile"

# Check S3 bucket exists
bucket_check=$(aws s3api head-bucket --bucket "$s3_bucket_name" 2>&1; echo $?)
echo "S3 Bucket check: $bucket_check"

# Check VPC peering
read -r peering_id peering_status <<< "$(aws ec2 describe-vpc-peering-connections \
  --filters "Name=tag:Name,Values=$peering_name" \
  --query "VpcPeeringConnections[0].[VpcPeeringConnectionId,Status.Code]" \
  --output text 2>/dev/null)" && echo "Peering: $peering_id, Status: $peering_status"

# Check peering routes in both route tables
priv_rt_id=$(aws ec2 describe-route-tables \
  --filters "Name=tag:Name,Values=$priv_rt_name" \
  --query "RouteTables[0].RouteTableId" \
  --output text 2>/dev/null) && echo "Private Route Table: $priv_rt_id"

priv_peering_route=$(aws ec2 describe-route-tables \
  --route-table-ids "$priv_rt_id" \
  --query "RouteTables[0].Routes[?VpcPeeringConnectionId=='$peering_id'].VpcPeeringConnectionId" \
  --output text 2>/dev/null) && echo "Private RT peering route: $priv_peering_route"

pub_peering_route=$(aws ec2 describe-route-tables \
  --route-table-ids "$pub_rt_id" \
  --query "RouteTables[0].Routes[?VpcPeeringConnectionId=='$peering_id'].VpcPeeringConnectionId" \
  --output text 2>/dev/null) && echo "Public RT peering route: $pub_peering_route"

# Check S3 file at expected path
s3_file_exists=false
if aws s3 ls "s3://$s3_bucket_name/$s3_object_key" 2>/dev/null; then
  s3_file_exists=true
  echo "S3 file found: $s3_object_key"
else
  echo "S3 file not found: $s3_object_key"
fi

# Validation checks
pub_vpc_valid=false
pub_subnet_valid=false
pub_rt_valid=false
igw_valid=false
igw_route_valid=false
pub_ec2_valid=false
role_valid=false
profile_valid=false
bucket_valid=false
peering_valid=false
priv_route_valid=false
pub_route_valid=false
s3_file_valid=false

[[ -n "$pub_vpc_id" && "$pub_vpc_id" != "None" ]] && pub_vpc_valid=true
[[ -n "$pub_subnet_id" && "$pub_subnet_id" != "None" ]] && pub_subnet_valid=true
[[ -n "$pub_rt_id" && "$pub_rt_id" != "None" ]] && pub_rt_valid=true
[[ -n "$igw_id" && "$igw_id" != "None" ]] && igw_valid=true
[[ "$igw_route" == igw-* ]] && igw_route_valid=true
[[ "$pub_instance_state" == "running" ]] && pub_ec2_valid=true
[[ -n "$role_arn" && "$role_arn" != "None" ]] && role_valid=true
[[ -n "$instance_profile" && "$instance_profile" == *"$s3_role_name"* ]] && profile_valid=true
bucket_valid=true
[[ "$peering_status" == "active" ]] && peering_valid=true
[[ -n "$priv_peering_route" && "$priv_peering_route" != "None" ]] && priv_route_valid=true
[[ -n "$pub_peering_route" && "$pub_peering_route" != "None" ]] && pub_route_valid=true
[[ "$s3_file_exists" == true ]] && s3_file_valid=true

if [[ "$pub_vpc_valid" == true ]] && [[ "$pub_subnet_valid" == true ]] && [[ "$pub_rt_valid" == true ]] && [[ "$igw_valid" == true ]] && [[ "$igw_route_valid" == true ]] && [[ "$pub_ec2_valid" == true ]] && [[ "$role_valid" == true ]] && [[ "$profile_valid" == true ]] && [[ "$bucket_valid" == true ]] && [[ "$peering_valid" == true ]] && [[ "$priv_route_valid" == true ]] && [[ "$pub_route_valid" == true ]] && [[ "$s3_file_valid" == true ]]; then
  echo "✓ Success"
  echo "  Public VPC: $pub_vpc_name ($pub_vpc_id)"
  echo "  Public Subnet: $pub_subnet_name ($pub_subnet_id)"
  echo "  Public Route Table: $pub_rt_name ($pub_rt_id)"
  echo "  Internet Gateway: $igw_id (route: $igw_route)"
  echo "  Public EC2: $pub_ec2_name ($pub_instance_id, $pub_instance_state)"
  echo "  IAM Role: $s3_role_name"
  echo "  Instance Profile: attached to $pub_ec2_name"
  echo "  S3 Bucket: $s3_bucket_name"
  echo "  VPC Peering: $peering_name ($peering_id, $peering_status)"
  echo "  Peering Routes: configured in both route tables"
  echo "  S3 File: $s3_object_key found in bucket"
else
  echo "✗ Fail"

  if [[ "$pub_vpc_valid" == false ]]; then
    echo "  ✗ Public VPC '$pub_vpc_name' not found"
  else
    echo "  ✓ Public VPC exists ($pub_vpc_id)"
  fi

  if [[ "$pub_subnet_valid" == false ]]; then
    echo "  ✗ Public subnet '$pub_subnet_name' not found"
  else
    echo "  ✓ Public subnet exists ($pub_subnet_id)"
  fi

  if [[ "$pub_rt_valid" == false ]]; then
    echo "  ✗ Public route table '$pub_rt_name' not found"
  else
    echo "  ✓ Public route table exists ($pub_rt_id)"
  fi

  if [[ "$igw_valid" == false ]]; then
    echo "  ✗ Internet gateway not attached to public VPC"
  else
    echo "  ✓ Internet gateway attached ($igw_id)"
  fi

  if [[ "$igw_route_valid" == false ]]; then
    echo "  ✗ No internet route in public route table"
    echo "    Expected: 0.0.0.0/0 → igw-*"
    echo "    Got: $igw_route"
  else
    echo "  ✓ Internet route configured"
  fi

  if [[ "$pub_ec2_valid" == false ]]; then
    echo "  ✗ Public EC2 '$pub_ec2_name' not found or not running"
    echo "    State: $pub_instance_state"
  else
    echo "  ✓ Public EC2 is running ($pub_instance_id)"
  fi

  if [[ "$role_valid" == false ]]; then
    echo "  ✗ IAM role '$s3_role_name' not found"
  else
    echo "  ✓ IAM role exists"
  fi

  if [[ "$profile_valid" == false ]]; then
    echo "  ✗ Instance profile not attached to public EC2"
    echo "    Got: $instance_profile"
  else
    echo "  ✓ Instance profile attached"
  fi

  if [[ "$bucket_valid" == false ]]; then
    echo "  ✗ S3 bucket '$s3_bucket_name' not found"
  else
    echo "  ✓ S3 bucket exists"
  fi

  if [[ "$peering_valid" == false ]]; then
    echo "  ✗ VPC peering '$peering_name' not active"
    echo "    Expected: active"
    echo "    Got: $peering_status"
  else
    echo "  ✓ VPC peering is active ($peering_id)"
  fi

  if [[ "$priv_route_valid" == false ]]; then
    echo "  ✗ Private route table missing peering route"
  else
    echo "  ✓ Private route table has peering route"
  fi

  if [[ "$pub_route_valid" == false ]]; then
    echo "  ✗ Public route table missing peering route"
  else
    echo "  ✓ Public route table has peering route"
  fi

  if [[ "$s3_file_valid" == false ]]; then
    echo "  ✗ File '$s3_object_key' not found in S3 bucket"
    echo "    This indicates the cron-based log transfer is not working"
  else
    echo "  ✓ File uploaded to S3"
  fi
fi
```

</details>
