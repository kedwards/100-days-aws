# Day 40: Troubleshooting Internet Accessibility for an EC2-Hosted Application

## Task

The Nautilus Development Team recently deployed a new web application hosted on an EC2 instance within a public VPC named xfusion-vpc. The application, running on an Nginx server, should be accessible from the internet on port 80. Despite configuring the security group xfusion-sg to allow traffic on port 80 and verifying the EC2 instance settings, the application remains inaccessible from the internet. The team suspects that the issue might be related to the VPC configuration, as all other components appear to be set up correctly. The DevOps team has been asked to troubleshoot and resolve the issue to ensure the application is accessible to external users.

As a member of the Nautilus DevOps Team, your task is to perform the following:

    Verify VPC Configuration: Ensure that the VPC xfusion-vpc is properly configured to allow internet access.

    Ensure Accessibility: Make sure the EC2 instance xfusion-ec2 running the Nginx server is accessible from the internet on port 80.

## Help

```bash
aws ec2 describe-vpcs help
aws ec2 describe-subnets help
aws ec2 describe-internet-gateways help
aws ec2 describe-route-tables help
aws ec2 describe-instances help
aws ec2 describe-security-groups help
aws ec2 describe-security-group-rules help
aws ec2 create-internet-gateway help
aws ec2 attach-internet-gateway help
aws ec2 create-route help
aws ec2 modify-subnet-attribute help
aws ec2 allocate-address help
aws ec2 associate-address help
```

<details>
<summary><h2>Solution</h2></summary>

```bash
prefix=xfusion
vpc_name=$prefix-vpc
instance_name=$prefix-ec2
sg_name=$prefix-sg

# ── Get VPC ID ────────────────────────────────────────────────
vpc_id=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=$vpc_name" \
  --query "Vpcs[0].VpcId" \
  --output text) && echo "VPC ID: $vpc_id"

# ── Check subnets ─────────────────────────────────────────────
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" \
  --query "Subnets[].{ID:SubnetId,CIDR:CidrBlock,AZ:AvailabilityZone,MapPublicIP:MapPublicIpOnLaunch}" \
  --output table

# ── Check and create Internet Gateway ─────────────────────────
igw_id=$(aws ec2 describe-internet-gateways \
  --filters "Name=attachment.vpc-id,Values=$vpc_id" \
  --query "InternetGateways[0].InternetGatewayId" \
  --output text) && echo "Internet Gateway ID: $igw_id"

if [[ -z "$igw_id" || "$igw_id" == "None" ]]; then
  echo "No Internet Gateway found. Creating one..."
  igw_id=$(aws ec2 create-internet-gateway \
    --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=$prefix-igw}]" \
    --query "InternetGateway.InternetGatewayId" \
    --output text) && echo "Created Internet Gateway: $igw_id"
  
  aws ec2 attach-internet-gateway \
    --internet-gateway-id $igw_id \
    --vpc-id $vpc_id && echo "Attached IGW to VPC"
fi

# ── Check and create route to IGW ──────────────────────────────
route_table_id=$(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$vpc_id" \
  --query "RouteTables[0].RouteTableId" \
  --output text) && echo "Route Table ID: $route_table_id"

igw_route=$(aws ec2 describe-route-tables \
  --route-table-ids $route_table_id \
  --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].GatewayId" \
  --output text) && echo "IGW Route: $igw_route"

if [[ -z "$igw_route" || "$igw_route" == "None" ]]; then
  echo "No route to Internet Gateway. Creating route..."
  aws ec2 create-route \
    --route-table-id $route_table_id \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $igw_id && echo "Created route to IGW"
fi

# ── Get EC2 instance details ──────────────────────────────────
read -r instance_id subnet_id public_ip instance_sg
  --filters "Name=tag:Name,Values=$instance_name" \
  --query "Reservations[0].Instances[0].[InstanceId,SubnetId,PublicIpAddress,SecurityGroups[0].GroupId]" \
  --output text)" && echo "Instance: $instance_id, Subnet: $subnet_id, Public IP: $public_ip, SG: $instance_sg"

# ── Allocate Elastic IP if needed ──────────────────────────────
if [[ -z "$public_ip" || "$public_ip" == "None" ]]; then
  echo "No public IP. Allocating Elastic IP..."
  read -r allocation_id eip <<< "$(aws ec2 allocate-address \
    --query "[AllocationId,PublicIp]" \
    --output text)" && echo "Allocated EIP: $eip (Allocation ID: $allocation_id)"
  
  aws ec2 associate-address \
    --instance-id $instance_id \
    --allocation-id $allocation_id && echo "Associated EIP with instance"
  
  public_ip=$eip
fi

# ── Verify security group rules ───────────────────────────────
port_80_rule=$(aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=$instance_sg" \
  --query "SecurityGroupRules[?IsEgress==\`false\` && IpProtocol==\`tcp\` && FromPort==\`80\`].SecurityGroupRuleId" \
  --output text) && echo "Port 80 rule: $port_80_rule"

if [[ -z "$port_80_rule" || "$port_80_rule" == "None" ]]; then
  echo "Port 80 not open. Adding ingress rule..."
  aws ec2 authorize-security-group-ingress \
    --group-id $instance_sg \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 && echo "Added port 80 ingress rule"
fi

# ── Test connectivity ─────────────────────────────────────────
echo "Testing HTTP connectivity to $public_ip..."
curl -s --connect-timeout 10 "http://$public_ip" | head -5
```

</details>

<details>
<summary><h2>Validate</h2></summary>

```bash
aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$vpc_id" \
  --query "InternetGateways[].{ID:InternetGatewayId}" --output table

aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$vpc_id" \
  --query "RouteTables[].{ID:RouteTableId,Routes:Routes[?DestinationCidrBlock=='0.0.0.0/0']}" --output table

aws ec2 describe-instances --filters "Name=tag:Name,Values=$instance_name" \
  --query "Reservations[].Instances[].{ID:InstanceId,PublicIP:PublicIpAddress,State:State.Name}" --output table

curl -I http://$public_ip
```

```bash
prefix=datacenter
vpc_name=$prefix-vpc
instance_name=$prefix-ec2
sg_name=$prefix-sg

# Get VPC ID
vpc_id=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=$vpc_name" \
  --query "Vpcs[0].VpcId" \
  --output text 2>/dev/null) && echo "VPC ID: $vpc_id"

# Check Internet Gateway
read -r igw_id igw_attached <<< "$(aws ec2 describe-internet-gateways \
  --filters "Name=attachment.vpc-id,Values=$vpc_id" \
  --query "InternetGateways[0].[InternetGatewayId,Attachments[0].State]" \
  --output text 2>/dev/null)"&& echo "IGW: $igw_id, Attached: $igw_attached"

# Check route to IGW
route_table_id=$(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$vpc_id" "Name=association.main,Values=true" \
  --query "RouteTables[0].RouteTableId" \
  --output text 2>/dev/null) && echo "Main Route Table: $route_table_id"

igw_route=$(aws ec2 describe-route-tables \
  --route-table-ids $route_table_id \
  --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].GatewayId" \
  --output text 2>/dev/null) && echo "Route to IGW: $igw_route"

# Check EC2 instance
read -r instance_id instance_state public_ip sg_id <<< "$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$instance_name" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].[InstanceId,State.Name,PublicIpAddress,SecurityGroups[0].GroupId]" \
  --output text 2>/dev/null)"&& echo "Instance: $instance_id, State: $instance_state, Public IP: $public_ip"

# Check security group port 80 rule
port_80_rule=$(aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=$sg_id" \
  --query "SecurityGroupRules[?IsEgress==\`false\` && IpProtocol==\`tcp\` && FromPort==\`80\` && ToPort==\`80\`].SecurityGroupRuleId" \
  --output text 2>/dev/null) && echo "Port 80 rule: $port_80_rule"

# Test HTTP connectivity
http_status=""
if [[ -n "$public_ip" && "$public_ip" != "None" ]]; then
  echo "Testing HTTP connectivity to $public_ip..."
  http_status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "http://$public_ip" 2>/dev/null)
  echo "HTTP Status: $http_status"
fi

# Validation checks
vpc_exists=false
igw_attached_valid=false
route_to_igw=false
instance_running=false
has_public_ip=false
port_80_open=false
http_success=false

[[ -n "$vpc_id" && "$vpc_id" != "None" ]] && vpc_exists=true
[[ "$igw_attached" == "available" ]] && igw_attached_valid=true
[[ -n "$igw_route" && "$igw_route" != "None" && "$igw_route" == igw-* ]] && route_to_igw=true
[[ "$instance_state" == "running" ]] && instance_running=true
[[ -n "$public_ip" && "$public_ip" != "None" ]] && has_public_ip=true
[[ -n "$port_80_rule" && "$port_80_rule" != "None" ]] && port_80_open=true
[[ "$http_status" == "200" ]] && http_success=true

if [[ "$vpc_exists" == true ]] && [[ "$igw_attached_valid" == true ]] && [[ "$route_to_igw" == true ]] && [[ "$instance_running" == true ]] && [[ "$has_public_ip" == true ]] && [[ "$port_80_open" == true ]] && [[ "$http_success" == true ]]; then
  echo "✓ Success - Application is accessible from the internet"
  echo "  VPC: $vpc_name ($vpc_id)"
  echo "  Internet Gateway: $igw_id (attached)"
  echo "  Route to IGW: Configured"
  echo "  EC2 Instance: $instance_id ($instance_state)"
  echo "  Public IP: $public_ip"
  echo "  Port 80: Open"
  echo "  HTTP Status: $http_status (OK)"
else
  echo "✗ Fail - Troubleshooting checklist:"
  
  if [[ "$vpc_exists" == false ]]; then
    echo "  ✗ VPC '$vpc_name' not found"
  else
    echo "  ✓ VPC exists ($vpc_id)"
  fi
  
  if [[ "$igw_attached_valid" == false ]]; then
    echo "  ✗ Internet Gateway not attached to VPC"
    echo "    IGW ID: $igw_id"
    echo "    Status: $igw_attached"
    echo "    FIX: Create and attach an Internet Gateway"
  else
    echo "  ✓ Internet Gateway attached ($igw_id)"
  fi
  
  if [[ "$route_to_igw" == false ]]; then
    echo "  ✗ No route to Internet Gateway in route table"
    echo "    Route Table: $route_table_id"
    echo "    Current route: $igw_route"
    echo "    FIX: Add route 0.0.0.0/0 -> IGW"
  else
    echo "  ✓ Route to Internet Gateway exists"
  fi
  
  if [[ "$instance_running" == false ]]; then
    echo "  ✗ EC2 instance not running"
    echo "    State: $instance_state"
  else
    echo "  ✓ EC2 instance is running"
  fi
  
  if [[ "$has_public_ip" == false ]]; then
    echo "  ✗ EC2 instance has no public IP"
    echo "    FIX: Allocate and associate an Elastic IP"
  else
    echo "  ✓ EC2 instance has public IP ($public_ip)"
  fi
  
  if [[ "$port_80_open" == false ]]; then
    echo "  ✗ Port 80 not open in security group"
    echo "    Security Group: $sg_id"
    echo "    FIX: Add inbound rule for TCP port 80 from 0.0.0.0/0"
  else
    echo "  ✓ Port 80 is open"
  fi
  
  if [[ "$http_success" == false ]]; then
    echo "  ✗ HTTP request failed"
    echo "    URL: http://$public_ip"
    echo "    Expected: 200"
    echo "    Got: $http_status"
  else
    echo "  ✓ HTTP request successful (200)"
  fi
fi
```

</details>
