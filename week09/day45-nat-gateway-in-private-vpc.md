# Day 45: Configure NAT Gateway for Internet Access in a Private VPC

## Task

The Nautilus DevOps team is tasked with enabling internet access for an EC2 instance running in a private subnet. This instance should be able to upload a test file to a public S3 bucket once it can access the internet. To achieve this, the team must set up a NAT Gateway in a public subnet within the same VPC.

1) A VPC named devops-priv-vpc and a private subnet devops-priv-subnet have already been created.
2) An EC2 instance named devops-priv-ec2 is already running in the private subnet.
3) The EC2 instance is configured with a cron job that uploads a test file to a bucket devops-nat-18891 once internet is accessible.

Your task is to:

    Create a public subnet named devops-pub-subnet in the same VPC.
    Create an Internet Gateway and attach it to the VPC.
    Create a route table devops-pub-rt and associate it with the public subnet.
    Allocate an Elastic IP and create a NAT Gateway named devops-natgw.
    Update the private route table to route 0.0.0.0/0 traffic via the NAT Gateway.

Once complete, verify that the EC2 instance can reach the internet by confirming the presence of the test file in the S3 bucket devops-nat-18891. After completing all the configuration, please wait a few minutes for the test file to appear in the bucket, as it may take 2–3 minutes.

## Help

```bash
aws ec2 create-subnet help
aws ec2 create-internet-gateway help
aws ec2 attach-internet-gateway help
aws ec2 create-route-table help
aws ec2 create-route help
aws ec2 associate-route-table help
aws ec2 allocate-address help
aws ec2 create-nat-gateway help
aws ec2 describe-nat-gateways help
aws ec2 describe-route-tables help
aws s3 ls help
```

<details>
<summary><h2>Solution</h2></summary>

```bash
prefix=datacenter
vpc_name="${prefix}-priv-vpc"
private_subnet_name="${prefix}-priv-subnet"
public_subnet_name="${prefix}-pub-subnet"
public_route_table_name="${prefix}-pub-rt"
nat_gateway_name="${prefix}-natgw"
ec2_instance_name="${prefix}-priv-ec2"
s3_bucket_name="${prefix}-nat-16554"

vpc_id=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=$vpc_name" \
  --query "Vpcs[0].VpcId" \
  --output text) && echo "VPC ID: $vpc_id"

private_subnet_id=$(aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=$private_subnet_name" \
            "Name=vpc-id,Values=$vpc_id" \
  --query "Subnets[0].SubnetId" \
  --output text) && echo "Private Subnet ID: $private_subnet_id"

# Get VPC CIDR to determine available subnet range
vpc_cidr=$(aws ec2 describe-vpcs \
  --vpc-ids "$vpc_id" \
  --query "Vpcs[0].CidrBlock" \
  --output text) && echo "VPC CIDR: $vpc_cidr"

# Create public subnet (using next available /24 in VPC range)
public_subnet_id=$(aws ec2 create-subnet \
  --vpc-id "$vpc_id" \
  --cidr-block "${vpc_cidr%.*}.1/24" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value='$public_subnet_name'}]" \
  --query "Subnet.SubnetId" \
  --output text) && echo "Public Subnet ID: $public_subnet_id"

igw_id=$(aws ec2 create-internet-gateway \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value='${prefix}-igw'}]" \
  --query "InternetGateway.InternetGatewayId" \
  --output text) && echo "Internet Gateway ID: $igw_id"

aws ec2 attach-internet-gateway \
  --vpc-id "$vpc_id" \
  --internet-gateway-id "$igw_id" && echo "Attached IGW to VPC"

public_route_table_id=$(aws ec2 create-route-table \
  --vpc-id "$vpc_id" \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value='$public_route_table_name'}]" \
  --query "RouteTable.RouteTableId" \
  --output text) && echo "Public Route Table ID: $public_route_table_id"

aws ec2 create-route \
  --route-table-id "$public_route_table_id" \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id "$igw_id" && echo "Created route to IGW"

aws ec2 associate-route-table \
  --route-table-id "$public_route_table_id" \
  --subnet-id "$public_subnet_id" && echo "Associated route table with public subnet"

allocation_id=$(aws ec2 allocate-address \
  --domain vpc \
  --query "AllocationId" \
  --output text) && echo "Elastic IP Allocation ID: $allocation_id"

nat_gateway_id=$(aws ec2 create-nat-gateway \
  --subnet-id "$public_subnet_id" \
  --allocation-id "$allocation_id" \
  --tag-specifications "ResourceType=natgateway,Tags=[{Key=Name,Value='$nat_gateway_name'}]" \
  --query "NatGateway.NatGatewayId" \
  --output text) && echo "NAT Gateway ID: $nat_gateway_id"

# Wait for NAT Gateway to be available
echo "Waiting for NAT Gateway to become available..."
aws ec2 wait nat-gateway-available --nat-gateway-ids "$nat_gateway_id" && echo "NAT Gateway is available"

# Get private route table (the one without IGW route)
private_route_table_id=$(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$vpc_id" \
  --query "RouteTables[?!Routes[?starts_with(GatewayId, 'igw-')]].RouteTableId" \
  --output text) && echo "Private Route Table ID: $private_route_table_id"

private_route_table_id=rtb-086acc213c539e997
aws ec2 associate-route-table \
  --route-table-id "$private_route_table_id" \
  --subnet-id "$private_subnet_id" && echo "Associated route table with private subnet"

aws ec2 create-route \
  --route-table-id "$private_route_table_id" \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id "$nat_gateway_id" && echo "Created route to NAT Gateway"

# Wait a few minutes for the cron job to upload the test file
echo "Waiting for cron job to upload test file to S3..."
sleep 180

# Verify the test file exists in S3
echo "Checking S3 bucket for test file:"
aws s3 ls "s3://${s3_bucket_name}/" && echo "✓ Test file found in S3 bucket"
```

</details>

<details>
<summary><h2>Validate</h2></summary>

```bash
aws ec2 describe-subnets --filters "Name=tag:Name,Values=devops-pub-subnet" --output table
aws ec2 describe-internet-gateways --filters "Name=tag:Name,Values=devops-igw" --output table
aws ec2 describe-route-tables --filters "Name=tag:Name,Values=devops-pub-rt" --output table
aws ec2 describe-nat-gateways --filters "Name=tag:Name,Values=devops-natgw" --output table
aws s3 ls s3://devops-nat-18891/
```

```bash
prefix=datacenter
vpc_name="${prefix}-priv-vpc"
public_subnet_name="${prefix}-pub-subnet"
public_route_table_name="${prefix}-public-rt"
nat_gateway_name="${prefix}-natgw"
s3_bucket_name="${prefix}-nat-16554"

# Get VPC ID
vpc_id=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=$vpc_name" \
  --query "Vpcs[0].VpcId" \
  --output text 2>/dev/null) && echo "VPC ID: $vpc_id"

# Check public subnet exists
public_subnet_id=$(aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=$public_subnet_name" \
            "Name=vpc-id,Values=$vpc_id" \
  --query "Subnets[0].SubnetId" \
  --output text 2>/dev/null) && echo "Public Subnet ID: $public_subnet_id"

# Check Internet Gateway exists and is attached
read -r igw_id igw_state <<< "$(aws ec2 describe-internet-gateways \
  --filters "Name=attachment.vpc-id,Values=$vpc_id" \
  --query "InternetGateways[0].[InternetGatewayId,Attachments[0].State]" \
  --output text 2>/dev/null)"&& echo "IGW ID: $igw_id, State: $igw_state"

# Check public route table exists and has IGW route
public_rt_id=$(aws ec2 describe-route-tables \
  --filters "Name=tag:Name,Values=$public_route_table_name" \
  --query "RouteTables[0].RouteTableId" \
  --output text 2>/dev/null) && echo "Public Route Table ID: $public_rt_id"

public_has_igw_route=$(aws ec2 describe-route-tables \
  --route-table-ids "$public_rt_id" \
  --query "RouteTables[0].Routes[?DestinationCidrBlock=='*******/0' && starts_with(GatewayId, \`igw-\`)].GatewayId" \
  --output text 2>/dev/null) && echo "Public Route IGW: $public_has_igw_route"

# Check NAT Gateway exists and is available
read -r nat_gw_id nat_gw_state <<< "$(aws ec2 describe-nat-gateways \
  --query "NatGateways[0].[NatGatewayId,State]" \
  --output text 2>/dev/null)"&& echo "NAT Gateway ID: $nat_gw_id, State: $nat_gw_state"

# Check private route table has NAT Gateway route
private_rt_id=$(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$vpc_id" \
  --query "RouteTables[?!Routes[?starts_with(GatewayId, 'igw-')]].RouteTableId" \
  --output text 2>/dev/null) && echo "Private Route Table ID: $private_rt_id"

private_has_nat_route=$(aws ec2 describe-route-tables \
  --route-table-ids "$private_rt_id" \
  --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0' && starts_with(NatGatewayId, 'nat-')].NatGatewayId" \
  --output text 2>/dev/null) && echo "Private Route NAT: $private_has_nat_route"

# Check S3 bucket has files (indicating internet access works)
s3_file_count=$(aws s3 ls "s3://${s3_bucket_name}/" 2>/dev/null | wc -l) && echo "S3 file count: $s3_file_count"

# Validation checks
subnet_valid=false
igw_valid=false
public_rt_valid=false
nat_gw_valid=false
private_rt_valid=false
s3_valid=false

[[ -n "$public_subnet_id" ]] && subnet_valid=true
[[ "$igw_state" == "available" ]] && igw_valid=true
[[ -n "$public_has_igw_route" ]] && public_rt_valid=true
[[ "$nat_gw_state" == "available" ]] && nat_gw_valid=true
[[ -n "$private_has_nat_route" ]] && private_rt_valid=true
[[ "$s3_file_count" -gt 0 ]] && s3_valid=true

if [[ "$subnet_valid" == true ]] && [[ "$igw_valid" == true ]] && [[ "$public_rt_valid" == true ]] && [[ "$nat_gw_valid" == true ]] && [[ "$private_rt_valid" == true ]] && [[ "$s3_valid" == true ]]; then
  echo "✓ Success"
  echo "  Public Subnet: $public_subnet_name ($public_subnet_id)"
  echo "  Internet Gateway: $igw_id ($igw_state)"
  echo "  Public Route Table: $public_rt_id (has IGW route)"
  echo "  NAT Gateway: $nat_gateway_name ($nat_gw_id, $nat_gw_state)"
  echo "  Private Route Table: $private_rt_id (has NAT route)"
  echo "  S3 Bucket: $s3_bucket_name ($s3_file_count files found)"
  echo "  ✓ EC2 instance has internet access via NAT Gateway"
else
  echo "✗ Fail"
  
  if [[ "$subnet_valid" == false ]]; then
    echo "  ✗ Public subnet not found"
    echo "    Expected: $public_subnet_name"
  else
    echo "  ✓ Public subnet exists"
  fi
  
  if [[ "$igw_valid" == false ]]; then
    echo "  ✗ Internet Gateway not attached or not available"
    echo "    State: $igw_state"
  else
    echo "  ✓ Internet Gateway attached and available"
  fi
  
  if [[ "$public_rt_valid" == false ]]; then
    echo "  ✗ Public route table missing IGW route"
  else
    echo "  ✓ Public route table has IGW route"
  fi
  
  if [[ "$nat_gw_valid" == false ]]; then
    echo "  ✗ NAT Gateway not available"
    echo "    Expected: $nat_gateway_name"
    echo "    State: $nat_gw_state"
  else
    echo "  ✓ NAT Gateway is available"
  fi
  
  if [[ "$private_rt_valid" == false ]]; then
    echo "  ✗ Private route table missing NAT Gateway route"
  else
    echo "  ✓ Private route table has NAT Gateway route"
  fi
  
  if [[ "$s3_valid" == false ]]; then
    echo "  ✗ No files found in S3 bucket (internet access not working)"
    echo "    Expected files in: $s3_bucket_name"
    echo "    Note: Wait 2-3 minutes for cron job to upload test file"
  else
    echo "  ✓ Test file found in S3 bucket"
  fi
fi
```

</details>
