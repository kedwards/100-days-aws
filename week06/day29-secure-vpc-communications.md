# Day 29 - Establishing Secure Communication Between Public and Private VPCs via VPC Peering

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
aws command help
aws command2 help
```

<details>
<summary><h2>Solution</h2></summary>

```bash
public_ec2_name=datacenter-public-ec2
private_ec2_name=datacenter-private-ec2
peer_name=datacenter-vpc-peering
private_vpc_name=datacente-private-vpc


read -r default_vpc_id < <(aws ec2 describe-vpcs \
  --query "Vpcs[?IsDefault].VpcId" \
  --output text) && echo "Default VPC ID: $default_vpc_id"

read -r private_vpc_id < <(aws describe-vpcs \
  --filter "Name=tag:Name,Values=$private_vpc_name" \
  --query "Vpcs[0].VpcId" \
  --output text) && echo "Private VPC ID: $private_vpc_id"

read -r peering_conn_id < <(aws ec2 create-vpc-peering-connection \
  --vpc-id $default_vpc_id \
  --peer-vpc-id $private_vpc_id \
  --tag-specifications "ResourceType=vpc-peering-connection,Tags=[{Key=Name,Value=$peering_conn_name}]" \
  --query 'VpcPeeringConnection.VpcPeeringConnectionId' \
  --output text) && echo "Created VPC Peering Connection: $peering_conn_id"

aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id $peering_conn_id

read -r pub_route_table_id < <(aws ec2 describe-route-tables \
  --filters Name=vpc-id,Values=$default_vpc_id \
  --query RouteTables[].RouteTableId \
  --output text) && echo "Public rtb_id: $pub_route_table_id"

read -r priv_route_table_id < <(aws ec2 describe-route-tables \
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

aws ec2 describe-instances --filters Name=tag:Name,Values=devops-public-ec2 --query Reservations[0].Instances[0].[PublicIpAddress,SecurityGroups]

aws ec2 authorize-security-group-ingress \
  --group-id $public_security_group_id \
  --protocol ssh \
  --port 22 \
  --cidr 0.0.0.0/0

aws ec2 describe-instances --filters Name=tag:Name,Values=devops-private-ec2 --query Reservations[0].Instances[0].[PublicIpAddress,SecurityGroups]
sg-0836303e0410d7445

aws ec2 authorize-security-group-ingress \
  --group-id $private_security_group_id \
  --protocol icmp \
  --port -1 \
  --cidr 0.0.0.0/0

read -r aws_value < <(aws command describe-something \
  --filter "Name=tag:Name,Values=$tag_value" \
  --query "Returned[].AwsValue" \
  --output text) && echo "AWS Value: $aws_value"
```

</details>

<details>
<summary><h2>Validate</h2></summary>

```bash
aws ec2 describe-omething--filters "Name=tag:Name,Values=$tag_vale" \
  --query "Returned[?KeyName=='"$key_name"'].{Name:KeyName,Type:KeyType}" \
  --output table
```

```bash
key_name=keyName
tag_value=value

read -r aws_value < <(aws command describe-something \
  --filter "Name=tag:Name,Values=$tag_value" \
  --query "Returned[].AwsValue" \
  --output text) && echo "AWS Value: $aws_value"

name_valid=false

[[ "$aws_value" == "$key_name" ]] && name_valid=true

if [[ "$name_valid" == true ]]; then
  echo "✓ Success"
  echo "  Key name: $aws_value"
else
  echo "✗ Fail"
  
  if [[ "$name_valid" == false ]]; then
    echo "  ✗ Key name validation failed"
    echo "    Expected: $key_name"
    echo "    Got: $aws_value"
  else
    echo "  ✓ Key name validation passed"
  fi
fi
```

</details>
