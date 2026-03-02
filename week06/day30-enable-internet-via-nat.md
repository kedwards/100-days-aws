# Day 30: Enable Internet Access for Private EC2 using NAT Instance


## Task

The Nautilus DevOps team is tasked with enabling internet access for an EC2 instance running in a private subnet. This instance should be able to upload a test file to a public S3 bucket once it can access the internet. To minimize costs, the team has decided to use a NAT Instance instead of a NAT Gateway.

The following components already exist in the environment:
1) A VPC named xfusion-priv-vpc and a private subnet named xfusion-priv-subnet have been created.
2) An EC2 instance named xfusion-priv-ec2 is already running in the private subnet.
3) The EC2 instance is configured with a cron job that uploads a test file to the S3 bucket xfusion-nat-30282 every minute. Upload will only succeed once internet access is established.

Your task is to:

    Create a new public subnet named xfusion-pub-subnet in the existing VPC.
    Launch a NAT Instance in the public subnet using an Amazon Linux 2 AMI and name it xfusion-nat-instance. Configure this instance to act as a NAT instance. Make sure to use a custom security group for this instance.

After the configuration, verify that the test file xfusion-test.txt appears in the S3 bucket xfusion-nat-30282. This indicates successful internet access from the private EC2 instance via the NAT Instance.

requirements for the task.

## Help

```bash
aws ec2 describe-vpcs help
aws ec2 describe-subnets help
aws ec2 create-subnet help
aws ec2 create-security-group help
aws ec2 describe-security-groups help
aws ec2 authorize-security-group-ingress help
aws ec2 authorize-security-group-egress help
aws ec2 create-internet-gateway help
aws ec2 attach-internet-gateway help
aws ec2 describe-internet-gateways help
aws ec2 describe-route-tables help
aws ec2 create-route help
aws ec2 import-key-pair help
aws ec2 run-instances help
aws ec2 modify-instance-attribute help
aws ec2 describe-instances help
aws s3 ls help
```

<details>
<summary><h2>Solution</h2></summary>

```bash
vpc_name=xfusion-priv-vpc
private_subnet_name=xfusion-priv-subnet
private_instance_name=xfusion-priv-ec2
s3_bucket_name=xfusion-nat-30282
instance_type=t2.micro
public_subnet_name=xfusion-pub-subnet
nat_instance_name=xfusion-nat-instance
nat_sg_name=xfusion-nat-sg
igw_name=xfusion-igw
public_rt_name=xfusion-pub-rt
key_name=xfusion-nat-key

# Get existing VPC ID
vpc_id=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=$vpc_name" \
  --query "Vpcs[0].VpcId" \
  --output text) && echo "VPC ID: $vpc_id"

aws ec2 describe-vpcs --vpc-ids "$vpc_id" --output table

# Get existing private subnet
private_subnet_id=$(aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=$private_subnet_name" "Name=vpc-id,Values=$vpc_id" \
  --query "Subnets[0].SubnetId" \
  --output text) && echo "Private Subnet ID: $private_subnet_id"

# Get private route table (main route table for the VPC)
private_route_table_id=$(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$vpc_id" "Name=association.main,Values=true" \
  --query "RouteTables[0].RouteTableId" \
  --output text) && echo "Private Route Table ID: $private_route_table_id"

# Find available CIDR block for public subnet
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$vpc_id" \
  --query "Subnets[*].CidrBlock" \
  --output text && echo "(existing CIDR blocks)"

cidr_block=********/24

# Create public subnet
public_subnet_id=$(aws ec2 create-subnet \
  --vpc-id "$vpc_id" \
  --cidr-block "$cidr_block" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$public_subnet_name}]" \
  --query "Subnet.SubnetId" \
  --output text) && echo "Public Subnet ID: $public_subnet_id"

aws ec2 describe-subnets --subnet-ids "$public_subnet_id" --output table

# Enable auto-assign public IP for instances launched in this subnet
aws ec2 modify-subnet-attribute \
  --subnet-id "$public_subnet_id" \
  --map-public-ip-on-launch

# Create and attach Internet Gateway
igw_id=$(aws ec2 create-internet-gateway \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=$igw_name}]" \
  --query "InternetGateway.InternetGatewayId" \
  --output text) && echo "Internet Gateway ID: $igw_id"

aws ec2 attach-internet-gateway \
  --vpc-id "$vpc_id" \
  --internet-gateway-id "$igw_id"

aws ec2 describe-internet-gateways --internet-gateway-ids "$igw_id" --output table

# Create public route table
public_route_table_id=$(aws ec2 create-route-table \
  --vpc-id "$vpc_id" \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$public_rt_name}]" \
  --query "RouteTable.RouteTableId" \
  --output text) && echo "Public Route Table ID: $public_route_table_id"

# Add route to Internet Gateway
aws ec2 create-route \
  --route-table-id "$public_route_table_id" \
  --destination-cidr-block *******/0 \
  --gateway-id "$igw_id"

# Associate public route table with public subnet
aws ec2 associate-route-table \
  --route-table-id "$public_route_table_id" \
  --subnet-id "$public_subnet_id"

aws ec2 describe-route-tables --route-table-ids "$public_route_table_id" --output table

# Create security group for NAT instance
nat_sg_id=$(aws ec2 create-security-group \
  --vpc-id "$vpc_id" \
  --group-name "$nat_sg_name" \
  --description "Security group for NAT instance" \
  --query "GroupId" \
  --output text) && echo "NAT Security Group ID: $nat_sg_id"

# Allow all traffic from VPC CIDR (for NAT forwarding)
vpc_cidr=$(aws ec2 describe-vpcs \
  --vpc-ids "$vpc_id" \
  --query "Vpcs[0].CidrBlock" \
  --output text)

aws ec2 authorize-security-group-ingress \
  --group-id "$nat_sg_id" \
  --protocol -1 \
  --cidr "$vpc_cidr"

# Allow SSH from anywhere (optional, for troubleshooting)
aws ec2 authorize-security-group-ingress \
  --group-id "$nat_sg_id" \
  --protocol tcp \
  --port 22 \
  --cidr *******/0

aws ec2 describe-security-groups --group-ids "$nat_sg_id" --output table

# Import SSH key pair
if [[ ! -f ~/.ssh/id_rsa.pub ]]; then
  ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N ""
fi

aws ec2 import-key-pair \
  --key-name "$key_name" \
  --public-key-material fileb://~/.ssh/id_rsa.pub

# Create NAT instance user data script
cat > user-data.sh <<'USERDATA'
#!/bin/bash
set -eux

yum install iptables-services -y
systemctl enable iptables
systemctl start iptables

echo "net.ipv4.ip_forward=1" | tee /etc/sysctl.d/custom-ip-forwarding.conf
sysctl -p /etc/sysctl.d/custom-ip-forwarding.conf

primary_interface=$(ip route show default | awk '{print $5}')

/sbin/iptables -t nat -A POSTROUTING -o "$primary_interface" -j MASQUERADE
/sbin/iptables -F FORWARD
service iptables save
USERDATA

# Launch NAT instance
nat_instance_id=$(aws ec2 run-instances \
  --image-id resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --instance-type "$instance_type" \
  --subnet-id "$public_subnet_id" \
  --security-group-ids "$nat_sg_id" \
  --key-name "$key_name" \
  --associate-public-ip-address \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$nat_instance_name}]" \
  --user-data file://user-data.sh \
  --query "Instances[0].InstanceId" \
  --output text) && echo "NAT Instance ID: $nat_instance_id"

aws ec2 wait instance-running --instance-ids "$nat_instance_id" && echo "NAT instance is running"

aws ec2 describe-instances --instance-ids "$nat_instance_id" \
  --query "Reservations[].Instances[].{Name:Tags[?Key=='Name']|[0].Value,State:State.Name,InstanceId:InstanceId,PublicIp:PublicIpAddress}" \
  --output table

# Disable source/destination check for NAT
aws ec2 modify-instance-attribute \
  --instance-id "$nat_instance_id" \
  --no-source-dest-check

# Add route in private route table to NAT instance
aws ec2 create-route \
  --route-table-id "$private_route_table_id" \
  --destination-cidr-block *******/0 \
  --instance-id "$nat_instance_id"

aws ec2 describe-route-tables --route-table-ids "$private_route_table_id" --output table

# Allow outbound traffic on default security group
default_security_group_id=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=default" "Name=vpc-id,Values=$vpc_id" \
  --query "SecurityGroups[0].GroupId" \
  --output text) && echo "Default Security Group ID: $default_security_group_id"

aws ec2 authorize-security-group-egress \
  --group-id "$default_security_group_id" \
  --protocol -1 \
  --cidr *******/0 2>/dev/null || echo "Egress rule already exists"

# Wait for cron job to upload test file to S3
echo "Waiting for cron job to upload test file to S3..."
sleep 120

aws s3 ls "s3://${s3_bucket_name}/" && echo "✓ Test file found in S3 bucket"

# Cleanup
rm -f user-data.sh
```

</details>

<details>
<summary><h2>Validate</h2></summary>


```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=xfusion-nat-instance" \
  --query "Reservations[].Instances[].{Name:Tags[?Key=='Name']|[0].Value,State:State.Name,SubnetId:SubnetId,SourceDestCheck:SourceDestCheck}" \
  --output table
```

```bash
vpc_name=xfusion-priv-vpc
public_subnet_name=xfusion-pub-subnet
nat_instance_name=xfusion-nat-instance
private_instance_name=xfusion-priv-ec2
s3_bucket_name=xfusion-nat-30013
test_file=xfusion-test.txt

# Get VPC ID
vpc_id=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=$vpc_name" \
  --query "Vpcs[0].VpcId" \
  --output text) && echo "VPC ID: $vpc_id"

# Check public subnet
read -r public_subnet_id public_subnet_map_ip <<< "$(aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=$public_subnet_name" "Name=vpc-id,Values=$vpc_id" \
  --query "Subnets[0].[SubnetId,MapPublicIpOnLaunch]" \
  --output text)" && echo "Public Subnet ID: $public_subnet_id, Auto-assign IP: $public_subnet_map_ip"

# Check NAT instance
read -r nat_instance_id nat_instance_state nat_source_dest_check nat_public_ip <<< "$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$nat_instance_name" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].[InstanceId,State.Name,SourceDestCheck,PublicIpAddress]" \
  --output text)" && echo "NAT Instance: $nat_instance_id, State: $nat_instance_state, SourceDestCheck: $nat_source_dest_check, Public IP: $nat_public_ip"

# Check NAT instance security group
nat_sg_id=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$nat_instance_name" \
  --query "Reservations[0].Instances[0].SecurityGroups[0].GroupId" \
  --output text) && echo "NAT Security Group ID: $nat_sg_id"

nat_sg_name=$(aws ec2 describe-security-groups \
  --group-ids "$nat_sg_id" \
  --query "SecurityGroups[0].GroupName" \
  --output text 2>/dev/null) && echo "NAT Security Group Name: $nat_sg_name"

# Check Internet Gateway
read -r igw_id igw_attached_vpc <<< "$(aws ec2 describe-internet-gateways \
  --filters "Name=attachment.vpc-id,Values=$vpc_id" \
  --query "InternetGateways[0].[InternetGatewayId,Attachments[0].VpcId]" \
  --output text)" && echo "Internet Gateway: $igw_id, Attached to: $igw_attached_vpc"

# Check private route table has route to NAT instance
private_subnet_id=$(aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=xfusion-priv-subnet" "Name=vpc-id,Values=$vpc_id" \
  --query "Subnets[0].SubnetId" \
  --output text) && echo "Private Subnet ID: $private_subnet_id"

private_route_table_id=$(aws ec2 describe-route-tables \
  --filters "Name=association.subnet-id,Values=$private_subnet_id" \
  --query "RouteTables[0].RouteTableId" \
  --output text)

# If no explicit association, check main route table
if [[ -z "$private_route_table_id" || "$private_route_table_id" == "None" ]]; then
  private_route_table_id=$(aws ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=$vpc_id" "Name=association.main,Values=true" \
    --query "RouteTables[0].RouteTableId" \
    --output text)
fi
echo "Private Route Table ID: $private_route_table_id"

nat_route_target=$(aws ec2 describe-route-tables \
  --route-table-ids "$private_route_table_id" \
  --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].InstanceId" \
  --output text) && echo "NAT route target: $nat_route_target"

# Check private EC2 instance
read -r private_instance_id private_instance_state <<< "$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$private_instance_name" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].[InstanceId,State.Name]" \
  --output text)" && echo "Private Instance: $private_instance_id, State: $private_instance_state"

# Check S3 bucket for test file (indicates successful internet access)
file_exists=false
file_info=""
if aws s3 ls "s3://$s3_bucket_name/$test_file" 2>/dev/null; then
  file_exists=true
  file_info=$(aws s3 ls "s3://$s3_bucket_name/$test_file" 2>/dev/null)
  echo "Test file found in S3: $file_info"
else
  echo "Test file not found in S3 bucket"
fi

# Validation checks
public_subnet_exists=false
nat_instance_exists=false
nat_instance_running=false
source_dest_disabled=false
custom_sg_used=false
igw_attached=false
nat_route_configured=false
private_instance_exists=false
s3_upload_success=false

[[ -n "$public_subnet_id" && "$public_subnet_id" != "None" ]] && public_subnet_exists=true
[[ -n "$nat_instance_id" && "$nat_instance_id" != "None" ]] && nat_instance_exists=true
[[ "$nat_instance_state" == "running" ]] && nat_instance_running=true
[[ "$nat_source_dest_check" == "False" || "$nat_source_dest_check" == "false" ]] && source_dest_disabled=true
[[ -n "$nat_sg_name" && "$nat_sg_name" != "None" && "$nat_sg_name" != "default" ]] && custom_sg_used=true
[[ "$igw_attached_vpc" == "$vpc_id" ]] && igw_attached=true
[[ "$nat_route_target" == "$nat_instance_id" ]] && nat_route_configured=true
[[ -n "$private_instance_id" && "$private_instance_id" != "None" ]] && private_instance_exists=true
[[ "$file_exists" == true ]] && s3_upload_success=true

if [[ "$public_subnet_exists" == true ]] && [[ "$nat_instance_exists" == true ]] && [[ "$nat_instance_running" == true ]] && [[ "$source_dest_disabled" == true ]] && [[ "$custom_sg_used" == true ]] && [[ "$igw_attached" == true ]] && [[ "$nat_route_configured" == true ]] && [[ "$private_instance_exists" == true ]] && [[ "$s3_upload_success" == true ]]; then
  echo "✓ Success - NAT Instance fully configured and internet access verified"
  echo "  Public subnet: $public_subnet_id"
  echo "  NAT instance: $nat_instance_id ($nat_instance_state)"
  echo "  NAT public IP: $nat_public_ip"
  echo "  Source/Dest check: Disabled"
  echo "  Custom security group: $nat_sg_name"
  echo "  Internet gateway: $igw_id"
  echo "  Private instance: $private_instance_id"
  echo "  S3 upload: Verified ($test_file found in bucket)"
else
  echo "✗ Fail"
  
  if [[ "$public_subnet_exists" == false ]]; then
    echo "  ✗ Public subnet '$public_subnet_name' not found"
  else
    echo "  ✓ Public subnet exists"
  fi
  
  if [[ "$nat_instance_exists" == false ]]; then
    echo "  ✗ NAT instance '$nat_instance_name' not found"
  else
    echo "  ✓ NAT instance exists"
  fi
  
  if [[ "$nat_instance_running" == false ]]; then
    echo "  ✗ NAT instance not running"
    echo "    Expected: running"
    echo "    Got: $nat_instance_state"
  else
    echo "  ✓ NAT instance is running"
  fi
  
  if [[ "$source_dest_disabled" == false ]]; then
    echo "  ✗ Source/Dest check not disabled on NAT instance"
    echo "    Expected: false"
    echo "    Got: $nat_source_dest_check"
  else
    echo "  ✓ Source/Dest check disabled"
  fi
  
  if [[ "$custom_sg_used" == false ]]; then
    echo "  ✗ NAT instance not using custom security group"
    echo "    Got: $nat_sg_name"
  else
    echo "  ✓ Custom security group used: $nat_sg_name"
  fi
  
  if [[ "$igw_attached" == false ]]; then
    echo "  ✗ Internet gateway not attached to VPC"
  else
    echo "  ✓ Internet gateway attached"
  fi
  
  if [[ "$nat_route_configured" == false ]]; then
    echo "  ✗ Private route table missing route to NAT instance"
    echo "    Expected target: $nat_instance_id"
    echo "    Got: $nat_route_target"
  else
    echo "  ✓ Private route table has route to NAT instance"
  fi
  
  if [[ "$private_instance_exists" == false ]]; then
    echo "  ✗ Private instance '$private_instance_name' not found or not running"
  else
    echo "  ✓ Private instance exists and running"
  fi
  
  if [[ "$s3_upload_success" == false ]]; then
    echo "  ✗ Test file '$test_file' not found in S3 bucket '$s3_bucket_name'"
    echo "    This indicates internet access is not working from private instance"
  else
    echo "  ✓ Test file uploaded to S3 (internet access verified)"
  fi
fi
```

</details>
