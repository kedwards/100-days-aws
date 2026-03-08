# Day 35: Deploying and Managing Applications on AWS

## Task

The Nautilus DevOps team needs a new private RDS instance for their application. They need to set up a MySQL database and ensure that their existing EC2 instance can connect to it. This will help in managing their database needs efficiently and securely.

1) Task Details:

    Create a private RDS instance named xfusion-rds using a sandbox template.
    The engine type must be MySQL v8.4.5, and it must be a db.t3.micro type instance.
    The master username must be xfusion_admin with an appropriate password.
    The RDS storage type must be gp2, and the storage size must be 5GiB.
    Create a database named xfusion_db.
    Keep the rest of the configurations as default. Ensure the instance is in available state.
    Adjust the security groups so that the xfusion-ec2 instance can connect to the RDS on port 3306 and also open port 80 for the instance.

2) An EC2 instance named xfusion-ec2 exists. Connect to this instance from the AWS console. Create an SSH key (/root/.ssh/id_rsa) on the aws-client host if it doesn't already exist. Add the public key to the authorized keys of the root user on the EC2 instance for password-less SSH access.

3) There is a file named index.php under the /root directory on the aws-client host. Copy this file to the xfusion-ec2 instance under the /var/www/html/ directory. Make the appropriate changes in the file to connect to the RDS.

4) You should see a Connected successfully message in the browser once you access the instance using the public IP.

## Help

```bash
aws ec2 describe-vpcs help
aws ec2 describe-security-groups help
aws ec2 authorize-security-group-ingress help
aws ec2 describe-instances help
aws rds create-db-instance help
aws rds describe-db-instances help
```

<details>
<summary><h2>Solution</h2></summary>

```bash
prefix=datacenter
db_instance_identifier=$prefix-rds
db_instance_class="db.t3.micro"
db_name=${prefix}_db
db_engine="mysql"
db_engine_version="8.4.5"
db_master_username=${prefix}_admin
db_master_password=password
db_storage_type="gp2"
ec2_instance_name=$prefix-ec2

# ── Get VPC details ──────────────────────────────────────────
vpc_id=$(aws ec2 describe-vpcs \
  --query "Vpcs[0].VpcId" \
  --output text) && echo "VPC ID: $vpc_id"

# ── Create route table and subnets ─────────────────────────────
db_route_table_id=$(aws ec2 create-route-table \
  --vpc-id $vpc_id \
  --query "RouteTable.RouteTableId" \
  --output text) && echo "Created Route Table: $db_route_table_id"

aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$vpc_id" \
  --query "Subnets[].CidrBlock"

subnet_ids=()
octets=(128 144)
azs=("us-east-1a" "us-east-1b")

for i in "${!octets[@]}"; do
  read -r subnet_id < <(
    aws ec2 create-subnet \
      --vpc-id "$vpc_id" \
      --cidr-block "172.31.${octets[$i]}.0/20" \
      --availability-zone "${azs[$i]}" \
      --query "Subnet.SubnetId" \
      --output text
  )

  subnet_ids+=("$subnet_id")
  echo "Created Subnet: $subnet_id in ${azs[$i]}"
done

for subnet_id in "${subnet_ids[@]}"; do
  aws ec2 associate-route-table \
    --route-table-id $db_route_table_id \
    --subnet-id $subnet_id
done

# ── Create DB subnet group ────────────────────────────────────
db_subnet_group_name=$(aws rds create-db-subnet-group \
  --db-subnet-group-name DevOpsDBSubnetGroup \
  --db-subnet-group-description "Subnet group for DevOps RDS instance" \
  --subnet-ids ${subnet_ids[0]} ${subnet_ids[1]} \
  --query "DBSubnetGroup.DBSubnetGroupName" \
  --output text) && echo "Created DB Subnet Group: $db_subnet_group_name"

# ── Configure security groups ─────────────────────────────────
read db_security_group_id < <(aws ec2 create-security-group \
  --group-name DbSecurityGroup \
  --description "Database security group" \
  --vpc-id $vpc_id \
  --query "GroupId" \
  --output text) && echo "Created Security Group: $db_security_group_id"

ec2_security_group_id=$(aws ec2 describe-instances \
  --filter Name=tag:Name,Values=$ec2_instance_name \
  --query "Reservations[].Instances[].SecurityGroups[].GroupId" \
  --output text) && echo "EC2 Security Group: $ec2_security_group_id"

aws ec2 authorize-security-group-ingress \
  --group-id $db_security_group_id \
  --protocol tcp \
  --port 3306 \
  --source-group $ec2_security_group_id

ec2_security_group_id=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=default" \
  --query "SecurityGroups[].GroupId" \
  --output text) && echo "Security Group: $ec2_security_group_id"

aws ec2 authorize-security-group-egress \
  --group-id $ec2_security_group_id \
  --protocol tcp \
  --port 3306 \
  --source-group $db_security_group_id

aws ec2 authorize-security-group-ingress \
  --group-id $ec2_security_group_id \
  --ip-permissions "IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges=[{CidrIp=0.0.0.0/0}]" "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=0.0.0.0/0}]"

# ── Create RDS instance ───────────────────────────────────────
aws rds create-db-instance \
  --db-name $db_name \
  --db-instance-identifier $db_instance_identifier \
  --db-instance-class $db_instance_class \
  --db-subnet-group-name $db_subnet_group_name \
  --engine $db_engine \
  --engine-version $db_engine_version \
  --master-username $db_master_username \
  --master-user-password $db_master_password \
  --allocated-storage 5 \
  --storage-type $db_storage_type \
  --vpc-security-group-ids $db_security_group_id

# ── Generate SSH key ──────────────────────────────────────────
if [[ ! -f ~/.ssh/id_rsa ]]; then
  ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N "" -q
fi
cat ~/.ssh/id_rsa.pub

# ── Wait for RDS and get endpoint ──────────────────────────────
aws rds wait db-instance-available --db-instance-identifier $db_instance_identifier

db_endpoint=$(aws rds describe-db-instances \
  --db-instance-identifier $db_instance_identifier \
  --query "DBInstances[0].Endpoint.Address" \
  --output text) && echo "RDS Endpoint: $db_endpoint"

# ── Deploy application to EC2 ─────────────────────────────────
sed -i \
  -e "s|<dbname>|${db_name}|g" \
  -e "s|<dbuser>|${db_master_username}|g" \
  -e "s|<dbpass>|${db_master_password}|g" \
  -e "s|<dbhost>|${db_endpoint}|g" index.php

public_ip_address=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$ec2_instance_name" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text) && echo "Public IP: $public_ip_address"

scp -i ~/.ssh/id_rsa
ssh -i ~/.ssh/id_rsa root@$public_ip_address "sudo mv ~/index.php /var/www/html/index.php"

curl http://$public_ip_address/index.php
```

</details>

<details>
<summary><h2>Validate</h2></summary>

```bash
aws rds describe-db-instances --db-instance-identifier xfusion-rds \
  --query "DBInstances[].{DBInstanceIdentifier:DBInstanceIdentifier,Engine:Engine,DBInstanceClass:DBInstanceClass,DBInstanceStatus:DBInstanceStatus,Endpoint:Endpoint.Address}" \
  --output table

aws ec2 describe-instances --filters "Name=tag:Name,Values=xfusion-ec2" \
  --query "Reservations[].Instances[].{InstanceId:InstanceId,PublicIP:PublicIpAddress,State:State.Name}" \
  --output table
```

```bash
prefix=datacenter
db_instance_identifier=$prefix-rds
db_instance_class="db.t3.micro"
db_name=${prefix}_db
db_engine="mysql"
db_engine_version="8.4.5"
db_master_username=${prefix}_admin
db_master_password=password
db_storage_type="gp2"
ec2_instance_name=$prefix-ec2

# Check RDS instance
read -r rds_id rds_engine rds_version rds_class rds_status rds_storage_type rds_endpoint <<< "$(aws rds describe-db-instances \
  --db-instance-identifier $db_instance_identifier \
  --query "DBInstances[0].[DBInstanceIdentifier,Engine,EngineVersion,DBInstanceClass,DBInstanceStatus,StorageType,Endpoint.Address]" \
  --output text 2>/dev/null)"&& echo "RDS: $rds_id, Engine: $rds_engine $rds_version, Class: $rds_class, Status: $rds_status, Endpoint: $rds_endpoint"

# Check EC2 instance
read -r ec2_id ec2_state ec2_public_ip <<< "$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$ec2_instance_name" \
  --query "Reservations[0].Instances[0].[InstanceId,State.Name,PublicIpAddress]" \
  --output text 2>/dev/null)"&& echo "EC2: $ec2_id, State: $ec2_state, Public IP: $ec2_public_ip"

# Check security group rules for port 3306 and 80
security_group_id=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$ec2_instance_name" \
  --query "Reservations[0].Instances[0].SecurityGroups[0].GroupId" \
  --output text 2>/dev/null) && echo "Security Group: $security_group_id"

port_3306_rule=$(aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=$db_security_group_id" \
  --query "SecurityGroupRules[?IsEgress==\`false\` && IpProtocol==\`tcp\` && FromPort==\`3306\`].SecurityGroupRuleId" \
  --output text 2>/dev/null)

port_80_rule=$(aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=$ec2_security_group_id" \
  --query "SecurityGroupRules[?IsEgress==\`false\` && IpProtocol==\`tcp\` && FromPort==\`80\`].SecurityGroupRuleId" \
  --output text 2>/dev/null)

echo "Port 3306 rule: $port_3306_rule"
echo "Port 80 rule: $port_80_rule"

# Test web connectivity
web_response=""
if [[ -n "$ec2_public_ip" && "$ec2_public_ip" != "None" ]]; then
  web_response=$(curl -s --connect-timeout 10 "http://$ec2_public_ip/index.php" 2>/dev/null)
  echo "Web response: $web_response"
fi

# Validation checks
rds_exists=false
rds_engine_valid=false
rds_version_valid=false
rds_class_valid=false
rds_status_valid=false
rds_storage_valid=false
ec2_exists=false
ec2_running=false
port_3306_open=false
port_80_open=false
web_connected=false

[[ -n "$rds_id" && "$rds_id" != "None" ]] && rds_exists=true
[[ "$rds_engine" == "$db_engine" ]] && rds_engine_valid=true
[[ "$rds_version" == $db_engine_version_prefix* ]] && rds_version_valid=true
[[ "$rds_class" == "$db_instance_class" ]] && rds_class_valid=true
[[ "$rds_status" == "available" ]] && rds_status_valid=true
[[ "$rds_storage_type" == "$db_storage_type" ]] && rds_storage_valid=true
[[ -n "$ec2_id" && "$ec2_id" != "None" ]] && ec2_exists=true
[[ "$ec2_state" == "running" ]] && ec2_running=true
[[ -n "$port_3306_rule" && "$port_3306_rule" != "None" ]] && port_3306_open=true
[[ -n "$port_80_rule" && "$port_80_rule" != "None" ]] && port_80_open=true
[[ "$web_response" == *"Connected successfully"* ]] && web_connected=true

if [[ "$rds_exists" == true ]] && [[ "$rds_engine_valid" == true ]] && [[ "$rds_version_valid" == true ]] && [[ "$rds_class_valid" == true ]] && [[ "$rds_status_valid" == true ]] && [[ "$rds_storage_valid" == true ]] && [[ "$ec2_exists" == true ]] && [[ "$ec2_running" == true ]] && [[ "$port_3306_open" == true ]] && [[ "$port_80_open" == true ]] && [[ "$web_connected" == true ]]; then
  echo "✓ Success"
  echo "  RDS Instance: $rds_id"
  echo "  RDS Engine: $rds_engine $rds_version"
  echo "  RDS Class: $rds_class"
  echo "  RDS Status: $rds_status"
  echo "  RDS Endpoint: $rds_endpoint"
  echo "  EC2 Instance: $ec2_id"
  echo "  EC2 Public IP: $ec2_public_ip"
  echo "  Port 3306: Open"
  echo "  Port 80: Open"
  echo "  Web connection: Success"
else
  echo "✗ Fail"
  
  if [[ "$rds_exists" == false ]]; then
    echo "  ✗ RDS instance '$db_instance_identifier' not found"
  else
    echo "  ✓ RDS instance exists"
  fi
  
  if [[ "$rds_engine_valid" == false ]]; then
    echo "  ✗ RDS engine validation failed"
    echo "    Expected: $db_engine"
    echo "    Got: $rds_engine"
  else
    echo "  ✓ RDS engine is MySQL"
  fi
  
  if [[ "$rds_version_valid" == false ]]; then
    echo "  ✗ RDS version validation failed"
    echo "    Expected: $db_engine_version_prefix.x"
    echo "    Got: $rds_version"
  else
    echo "  ✓ RDS version is correct"
  fi
  
  if [[ "$rds_class_valid" == false ]]; then
    echo "  ✗ RDS instance class validation failed"
    echo "    Expected: $db_instance_class"
    echo "    Got: $rds_class"
  else
    echo "  ✓ RDS instance class is correct"
  fi
  
  if [[ "$rds_status_valid" == false ]]; then
    echo "  ✗ RDS status validation failed"
    echo "    Expected: available"
    echo "    Got: $rds_status"
  else
    echo "  ✓ RDS instance is available"
  fi
  
  if [[ "$rds_storage_valid" == false ]]; then
    echo "  ✗ RDS storage type validation failed"
    echo "    Expected: $db_storage_type"
    echo "    Got: $rds_storage_type"
  else
    echo "  ✓ RDS storage type is correct"
  fi
  
  if [[ "$ec2_exists" == false ]]; then
    echo "  ✗ EC2 instance '$ec2_instance_name' not found"
  else
    echo "  ✓ EC2 instance exists"
  fi
  
  if [[ "$ec2_running" == false ]]; then
    echo "  ✗ EC2 instance not running"
    echo "    Got: $ec2_state"
  else
    echo "  ✓ EC2 instance is running"
  fi
  
  if [[ "$port_3306_open" == false ]]; then
    echo "  ✗ Port 3306 not open in security group"
  else
    echo "  ✓ Port 3306 is open"
  fi
  
  if [[ "$port_80_open" == false ]]; then
    echo "  ✗ Port 80 not open in security group"
  else
    echo "  ✓ Port 80 is open"
  fi
  
  if [[ "$web_connected" == false ]]; then
    echo "  ✗ Web connection test failed"
    echo "    Expected: 'Connected successfully' in response"
    echo "    Got: $web_response"
  else
    echo "  ✓ Web connection successful"
  fi
fi
```

</details>
