# Day 29: Establishing Secure Communication Between Public and Private VPCs via VPC Peering

## Task

The Nautilus DevOps team has been tasked with demonstrating the use of VPC Peering to enable communication between two VPCs. One VPC will be a private VPC that contains a private EC2 instance, while the other will be the default public VPC containing a publicly accessible EC2 instance.

1) There is already an existing EC2 instance in the public vpc/subnet:

    Name: datacenter-public-ec2

2) There is already an existing Private VPC:

    Name: datacenter-private-vpc
    CIDR: 10.1.0.0/16

3) There is already an existing Subnet in datacenter-private-vpc:

    Name: datacenter-private-subnet
    CIDR: 10.1.1.0/24

4) There is already an existing EC2 instance in the private subnet:

    Name: datacenter-private-ec2

5) Create a Peering Connection between the Default VPC and the Private VPC:

    VPC Peering Connection Name: datacenter-vpc-peering

6) Configure Route Tables to enable communication between the two VPCs.

    Ensure the private EC2 instance is accessible from the public EC2 instance.

7) Test the Connection:

    Add /root/.ssh/id_rsa.pub public key to the public EC2 instance's ec2-user's authorized_keys to make sure we are able to ssh into this instance from AWS client host. You may also need to update the security group of the private EC2 instance to allow ICMP traffic from the public/default VPC CIDR. This will enable you to ping the private instance from the public instance.
    SSH into the public EC2 instance and ensure that you can ping the private EC2 instance.

## Help

```bash
aws ec2 describe-vpcs help
aws ec2 describe-instances help
aws ec2 create-vpc-peering-connection help
aws ec2 accept-vpc-peering-connection help
aws ec2 describe-vpc-peering-connections help
aws ec2 describe-route-tables help
aws ec2 create-route help
aws ec2 authorize-security-group-ingress help
aws ec2 describe-security-group-rules help
```

<details>
<summary><h2>Solution</h2></summary>

```bash
public_ec2_name=datacenter-public-ec2
private_ec2_name=datacenter-private-ec2
peer_conn_name=datacenter-vpc-peering
private_vpc_name=datacenter-private-vpc


# ── Get VPC IDs ───────────────────────────────────────────────
default_vpc_id=$(aws ec2 describe-vpcs \
  --query "Vpcs[?IsDefault].VpcId" \
  --output text) && echo "Default VPC ID: $default_vpc_id"

private_vpc_id=$(aws ec2 describe-vpcs \
  --filter "Name=tag:Name,Values=$private_vpc_name" \
  --query "Vpcs[0].VpcId" \
  --output text) && echo "Private VPC ID: $private_vpc_id"

# ── Create and accept VPC peering connection ─────────────────
peering_conn_id=$(aws ec2 create-vpc-peering-connection \
  --vpc-id $default_vpc_id \
  --peer-vpc-id $private_vpc_id \
  --tag-specifications "ResourceType=vpc-peering-connection,Tags=[{Key=Name,Value=$peering_conn_name}]" \
  --query 'VpcPeeringConnection.VpcPeeringConnectionId' \
  --output text) && echo "Created VPC Peering Connection: $peering_conn_id"

aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id $peering_conn_id

aws ec2 describe-vpc-peering-connections --vpc-peering-connection-ids $peering_conn_id \
  --query "VpcPeeringConnections[0].{Id:VpcPeeringConnectionId,Status:Status.Code}" \
  --output table

# ── Configure route tables for peering ───────────────────────
pub_route_table_id=$(aws ec2 describe-route-tables \
  --filters Name=vpc-id,Values=$default_vpc_id \
  --query RouteTables[].RouteTableId \
  --output text) && echo "Public rtb_id: $pub_route_table_id"

priv_route_table_id=$(aws ec2 describe-route-tables \
  --filters Name=vpc-id,Values=$private_vpc_id \
  --query RouteTables[].RouteTableId \
  --output text) && echo "Private rtb_id : $priv_route_table_id"

aws ec2 create-route \
  --route-table-id $pub_route_table_id \
  --destination-cidr-block 10.1.0.0/16 \
  --vpc-peering-connection-id $peering_conn_id

aws ec2 create-route \
  --route-table-id $priv_route_table_id \
  --destination-cidr-block 172.31.0.0/16 \
  --vpc-peering-connection-id $peering_conn_id

# ── Configure security group rules ─────────────────────────────
public_security_group_id=$(aws ec2 describe-instances --filters Name=tag:Name,Values=$public_ec2_name --query Reservations[0].Instances[0].SecurityGroups[].GroupId --output text) && echo "Public Security Group Id: $public_security_group_id"

aws ec2 authorize-security-group-ingress \
  --group-id $public_security_group_id \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

private_security_group_id=$(aws ec2 describe-instances --filters Name=tag:Name,Values=$private_ec2_name --query Reservations[0].Instances[0].SecurityGroups[].GroupId --output text) && echo "Private Security Group Id: $private_security_group_id"

aws ec2 authorize-security-group-ingress \
  --group-id $private_security_group_id \
  --protocol icmp \
  --port -1 \
  --cidr 0.0.0.0/0

# ── Connect and test ──────────────────────────────────────────
public_ip=$(aws ec2 describe-instances --filters Name=tag:Name,Values=$public_ec2_name --query Reservations[0].Instances[0].PublicIpAddress --output text) && echo "Public ip: $public_ip"

ssh -i ~/.ssh/id_rsa ec2-user@$public_ip

private_ip=$(aws ec2 describe-instances --filters Name=tag:Name,Values=$private_ec2_name --query Reservations[0].Instances[0].PrivateIpAddress --output text) && echo "Private ip: $private_ip"

```

</details>

<details>
<summary><h2>Validate</h2></summary>


```bash
aws ec2 describe-vpc-peering-connections \
  --filters "Name=tag:Name,Values=datacenter-vpc-peering" \
  --query "VpcPeeringConnections[].{Name:Tags[?Key=='Name']|[0].Value,Status:Status.Code,Requester:RequesterVpcInfo.VpcId,Accepter:AccepterVpcInfo.VpcId}" \
  --output table
```

```bash
public_ec2_name=datacenter-public-ec2
private_ec2_name=datacenter-private-ec2
peer_conn_name=datacenter-vpc-peering
private_vpc_name=datacenter-private-vpc

# Get VPC IDs
default_vpc_id=$(aws ec2 describe-vpcs \
  --query "Vpcs[?IsDefault].VpcId" \
  --output text) && echo "Default VPC ID: $default_vpc_id"

private_vpc_id=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=$private_vpc_name" \
  --query "Vpcs[0].VpcId" \
  --output text) && echo "Private VPC ID: $private_vpc_id"

# Get peering connection info
read -r peering_id peering_status <<< "$(aws ec2 describe-vpc-peering-connections \
  --filters "Name=tag:Name,Values=$peer_conn_name" \
  --query "VpcPeeringConnections[0].[VpcPeeringConnectionId,Status.Code]" \
  --output text)" && echo "Peering ID: $peering_id, Status: $peering_status"

# Get route tables and check for peering routes
pub_route_table_id=$(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$default_vpc_id" "Name=association.main,Values=true" \
  --query "RouteTables[0].RouteTableId" \
  --output text) && echo "Public route table: $pub_route_table_id"

priv_route_table_id=$(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$private_vpc_id" \
  --query "RouteTables[0].RouteTableId" \
  --output text) && echo "Private route table: $priv_route_table_id"

# Check if peering routes exist
pub_peering_route=$(aws ec2 describe-route-tables \
  --route-table-ids "$pub_route_table_id" \
  --query "RouteTables[0].Routes[?VpcPeeringConnectionId=='$peering_id'].VpcPeeringConnectionId" \
  --output text) && echo "Public VPC peering route: $pub_peering_route"

priv_peering_route=$(aws ec2 describe-route-tables \
  --route-table-ids "$priv_route_table_id" \
  --query "RouteTables[0].Routes[?VpcPeeringConnectionId=='$peering_id'].VpcPeeringConnectionId" \
  --output text) && echo "Private VPC peering route: $priv_peering_route"

# Get EC2 instance info
read -r public_instance_id public_ip <<< "$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$public_ec2_name" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].[InstanceId,PublicIpAddress]" \
  --output text)" && echo "Public EC2: $public_instance_id, IP: $public_ip"

read -r private_instance_id private_ip <<< "$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$private_ec2_name" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].[InstanceId,PrivateIpAddress]" \
  --output text)" && echo "Private EC2: $private_instance_id, IP: $private_ip"

# Check private instance security group for ICMP rule
private_sg_id=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$private_ec2_name" \
  --query "Reservations[0].Instances[0].SecurityGroups[0].GroupId" \
  --output text) && echo "Private SG ID: $private_sg_id"

icmp_rule=$(aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=$private_sg_id" \
  --query "SecurityGroupRules[?IsEgress==\`false\` && IpProtocol==\`icmp\`].SecurityGroupRuleId" \
  --output text) && echo "ICMP rule ID: $icmp_rule"

# Test connectivity from public to private instance
ping_success=false
if [[ -n "$public_ip" && "$public_ip" != "None" && -n "$private_ip" && "$private_ip" != "None" ]]; then
  echo "Testing ping from public EC2 ($public_ip) to private EC2 ($private_ip)..."
  
  if ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes ec2-user@$public_ip "ping -c 3 $private_ip" 2>/dev/null; then
    ping_success=true
    echo "  ✓ Ping test passed"
  else
    echo "  ✗ Ping test failed"
  fi
fi

# Validation checks
peering_exists=false
peering_active=false
pub_route_exists=false
priv_route_exists=false
public_ec2_exists=false
private_ec2_exists=false
icmp_enabled=false

[[ -n "$peering_id" && "$peering_id" != "None" ]] && peering_exists=true
[[ "$peering_status" == "active" ]] && peering_active=true
[[ -n "$pub_peering_route" && "$pub_peering_route" != "None" ]] && pub_route_exists=true
[[ -n "$priv_peering_route" && "$priv_peering_route" != "None" ]] && priv_route_exists=true
[[ -n "$public_instance_id" && "$public_instance_id" != "None" ]] && public_ec2_exists=true
[[ -n "$private_instance_id" && "$private_instance_id" != "None" ]] && private_ec2_exists=true
[[ -n "$icmp_rule" && "$icmp_rule" != "None" ]] && icmp_enabled=true

if [[ "$peering_exists" == true ]] && [[ "$peering_active" == true ]] && [[ "$pub_route_exists" == true ]] && [[ "$priv_route_exists" == true ]] && [[ "$public_ec2_exists" == true ]] && [[ "$private_ec2_exists" == true ]] && [[ "$icmp_enabled" == true ]] && [[ "$ping_success" == true ]]; then
  echo "✓ Success - VPC Peering fully configured and tested"
  echo "  Peering connection: $peering_id ($peering_status)"
  echo "  Public EC2: $public_instance_id ($public_ip)"
  echo "  Private EC2: $private_instance_id ($private_ip)"
  echo "  Route tables configured: Yes"
  echo "  ICMP enabled: Yes"
  echo "  Connectivity test: Passed"
else
  echo "✗ Fail"
  
  if [[ "$peering_exists" == false ]]; then
    echo "  ✗ VPC Peering connection '$peer_conn_name' not found"
  else
    echo "  ✓ VPC Peering connection exists"
  fi
  
  if [[ "$peering_active" == false ]]; then
    echo "  ✗ VPC Peering connection not active"
    echo "    Expected: active"
    echo "    Got: $peering_status"
  else
    echo "  ✓ VPC Peering connection is active"
  fi
  
  if [[ "$pub_route_exists" == false ]]; then
    echo "  ✗ Public VPC route table missing peering route"
  else
    echo "  ✓ Public VPC route table has peering route"
  fi
  
  if [[ "$priv_route_exists" == false ]]; then
    echo "  ✗ Private VPC route table missing peering route"
  else
    echo "  ✓ Private VPC route table has peering route"
  fi
  
  if [[ "$public_ec2_exists" == false ]]; then
    echo "  ✗ Public EC2 instance '$public_ec2_name' not found or not running"
  else
    echo "  ✓ Public EC2 instance exists and running"
  fi
  
  if [[ "$private_ec2_exists" == false ]]; then
    echo "  ✗ Private EC2 instance '$private_ec2_name' not found or not running"
  else
    echo "  ✓ Private EC2 instance exists and running"
  fi
  
  if [[ "$icmp_enabled" == false ]]; then
    echo "  ✗ ICMP not enabled on private instance security group"
  else
    echo "  ✓ ICMP enabled on private instance security group"
  fi
  
  if [[ "$ping_success" == false ]]; then
    echo "  ✗ Ping connectivity test failed"
  else
    echo "  ✓ Ping connectivity test passed"
  fi
fi
```

</details>
