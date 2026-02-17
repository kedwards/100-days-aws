## Solution Guide: NAT Instance for Private Subnet Internet Access

### Step 1: Gather Existing Resource IDs

```bash
# Get VPC ID
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=reach-devops-priv-vpc" \
  --query 'Vpcs[0].VpcId' --output text) && echo "vpc_id: $VPC_ID"

# Get private subnet ID
PRIV_SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=reach-devops-priv-subnet" \
  --query 'Subnets[0].SubnetId' --output text) && echo "priv_subnet_id: $PRIV_SUBNET_ID"

# Get Internet Gateway ID
IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=tag:Name,Values=reach-devops-igw" \
  --query 'InternetGateways[0].InternetGatewayId' --output text) && echo "igw_id: $IGW_ID"

# Get the private subnet's route table (main route table)
PRIV_RTB_ID=$(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=association.main,Values=true" \
  --query 'RouteTables[0].RouteTableId' --output text) && echo "priv_rtb_id: $PRIV_RTB_ID"

# Get latest Amazon Linux 2 AMI
AMI_ID=$(aws ec2 describe-images --owners amazon \
  --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" "Name=state,Values=available" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' --output text) && echo "ami_id: $AMI_ID"

echo "VPC_ID=$VPC_ID"
echo "PRIV_SUBNET_ID=$PRIV_SUBNET_ID"
# echo "IGW_ID=$IGW_ID"
echo "PRIV_RTB_ID=$PRIV_RTB_ID"
echo "AMI_ID=$AMI_ID"
```

### Step 2: Create the Public Subnet

```bash
PUB_SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.0.2.0/24 \
  --availability-zone ca-central-1a \
  --query 'Subnet.SubnetId' --output text) && echo "pub_subnet_id: $PUB_SUBNET_ID"

aws ec2 create-tags --resources "$PUB_SUBNET_ID" \
  --tags Key=Name,Value=reach-devops-pub-subnet

# Enable auto-assign public IP for instances launched in this subnet
aws ec2 modify-subnet-attribute --subnet-id "$PUB_SUBNET_ID" \
  --map-public-ip-on-launch

echo "PUB_SUBNET_ID=$PUB_SUBNET_ID"
```

### Step 3: Create and Associate a Public Route Table

```bash
PUB_RTB_ID=$(aws ec2 create-route-table \
  --vpc-id "$VPC_ID" \
  --query 'RouteTable.RouteTableId' --output text) && echo "pub_rtb_id: $PUB_RTB_ID"

aws ec2 create-tags --resources "$PUB_RTB_ID" \
  --tags Key=Name,Value=reach-devops-pub-rtb

# Add route to Internet Gateway
aws ec2 create-route \
  --route-table-id "$PUB_RTB_ID" \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id "$IGW_ID"

# Associate with public subnet
aws ec2 associate-route-table \
  --route-table-id "$PUB_RTB_ID" \
  --subnet-id "$PUB_SUBNET_ID"

echo "PUB_RTB_ID=$PUB_RTB_ID"
```

### Step 4: Create a Security Group for the NAT Instance

```bash
NAT_SG_ID=$(aws ec2 create-security-group \
  --group-name reach-devops-nat-sg \
  --description "Security group for reach-devops NAT instance" \
  --vpc-id "$VPC_ID" \
  --query 'GroupId' --output text) && echo "nat_sg_id: $NAT_SG_ID"

aws ec2 create-tags --resources "$NAT_SG_ID" \
  --tags Key=Name,Value=reach-devops-nat-sg

# Allow all traffic from the private subnet (for NAT forwarding)
aws ec2 authorize-security-group-ingress \
  --group-id "$NAT_SG_ID" \
  --protocol -1 \
  --cidr 10.0.1.0/24

# Allow SSH from anywhere (optional, for troubleshooting)
aws ec2 authorize-security-group-ingress \
  --group-id "$NAT_SG_ID" \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

echo "NAT_SG_ID=$NAT_SG_ID"
```

### Step 5: Launch the NAT Instance with IP Forwarding Enabled

The user data script enables IP forwarding and configures iptables for NAT:

```bash
cat <<'USERDATA' > /tmp/nat-userdata.sh
#!/bin/bash
# Enable IP forwarding
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

# Configure iptables for NAT (masquerade traffic from private subnet)
yum install -y iptables-services
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -A FORWARD -i eth0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -j ACCEPT
service iptables save
systemctl enable iptables
USERDATA

NAT_INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type t2.micro \
  --subnet-id "$PUB_SUBNET_ID" \
  --security-group-ids "$NAT_SG_ID" \
  --user-data file:///tmp/nat-userdata.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=reach-devops-nat-instance}]' \
  --query 'Instances[0].InstanceId' --output text) && echo "nat_instance_id: $NAT_INSTANCE_ID"

echo "NAT_INSTANCE_ID=$NAT_INSTANCE_ID"

# Wait for instance to be running
aws ec2 wait instance-running --instance-ids "$NAT_INSTANCE_ID"
echo "NAT instance is running"
```

### Step 6: Disable Source/Destination Check

This is critical — by default EC2 instances drop traffic not destined for their own IP. A NAT instance must forward traffic, so this check must be disabled:

```bash
aws ec2 modify-instance-attribute \
  --instance-id "$NAT_INSTANCE_ID" \
  --no-source-dest-check

echo "Source/destination check disabled"
```

### Step 7: Update the Private Subnet Route Table

Route internet-bound traffic from the private subnet through the NAT instance:

```bash
aws ec2 create-route \
  --route-table-id "$PRIV_RTB_ID" \
  --destination-cidr-block 0.0.0.0/0 \
  --instance-id "$NAT_INSTANCE_ID"

echo "Private route table updated to use NAT instance"
```

### Step 8: Verify

Wait 1–2 minutes for the cron job to run, then check the bucket:

```bash
aws s3 ls s3://reach-devops-nat-15195/
```

Expected output:

```
<timestamp> <size> reach-devops-test.txt
```

You can also download and inspect the file:

```bash
aws s3 cp s3://reach-devops-nat-15195/reach-devops-test.txt -
```

### Key Concepts

| Concept | Explanation |
|---|---|
| **NAT Instance vs NAT Gateway** | NAT Gateway is a managed AWS service (higher cost, no maintenance). A NAT Instance is a regular EC2 instance configured to forward traffic (lower cost, requires manual setup). |
| **Source/Dest Check** | EC2 instances by default only accept traffic addressed to them. Disabling this allows the instance to forward traffic for other hosts — essential for NAT. |
| **IP Forwarding** | The Linux kernel must be told to forward packets between interfaces (`net.ipv4.ip_forward = 1`). |
| **iptables Masquerade** | The MASQUERADE rule in iptables rewrites outbound packets from private IPs to the NAT instance's public IP, and tracks connections to route replies back. |
| **Public vs Private Subnet** | A public subnet has a route to an Internet Gateway. A private subnet does not — it relies on NAT to reach the internet. |
