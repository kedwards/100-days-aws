# Day XX - Task title

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
aws command help
aws command2 help
```

<details>
<summary><h2>Solution</h2></summary>

```bash
vpc_name=xfusion-priv-vpc
instance_type=t2.micro
public_subnet_name=

read -r vpc_id < <(aws ec2 describe-vpcs \
  --filter "Name=tag:Name,Values=$vpc_name" \
  --query "Vpcs[0].VpcId" \
  --output text) && echo "VPC ID: $vpc_id"

read -r private_subnet_id cidr_block  < <(aws ec2 describe-subnets \
  --filter "Name=vpc-id,Values=$vpc_id" \
  --query "Subnets[?Tags[?Key=='Name' && Value==$private_subnet_name]].[SubnetId,CidrBlock]" \
  --output text) && echo "Private Subnet ID: $private_subnet_id, Cidr: $cidr_block" 

public_cidr=10.1.2.0/24

read -r public_subnet_id < <(aws ec2 create-subnet \
  --vpc-id $vpc_id \
  --cidr-block $public_cidr \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$public_subnet_name}]"
  --query "Subnet.SubnetId" \
  --output text) && echo "Public Subnet ID: $public_subnet_id"

read -r nat_sg_id < <(aws ec2 create-security-group \
  --vpc-id $vpc_id \
  --group-name nat-security-group \
  --description "My nat security group" \
  --query "GroupId" \
  --output text) && echo "NAT Security Group ID: $nat_sg_id"

if [[ ! -f ~/.ssh/id_rsa.pub ]]; then
  ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N ""
fi

PUBKEY="$(cat ~/.ssh/id_rsa.pub)"

cat > user-data.sh <<EOF
#!/bin/bash
set -eux

mkdir -p /root/.ssh
chmod 700 /root/.ssh

cat <<EOC > /root/.ssh/authorized_keys
$PUBKEY
EOC

chmod 600 /root/.ssh/authorized_keys

yum install iptables-services -y
systemctl enable iptables
systemctl start iptables

echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/custom-ip-forwarding.conf
sysctl -p /etc/sysctl.d/custom-ip-forwarding.conf

/sbin/iptables -t nat -A POSTROUTING -o <primary_interface> -j MASQUERADE
/sbin/iptables -F FORWARD
service iptables save
EOF

aws ec2 import-key-pair \
  --key-name "$key_name" \
  --public-key-material fileb://~/.ssh/id_rsa.pub 

aws ec2 run-instances \
  --image-id \
    resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
    --instance-type $instance_type \
    --subnet-id $public_subnet_id \
    --security-group-ids $nat_sg_id \
    --associate-public-ip-address \
    --key-name $key_name \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance_name}]" \
    --user-data file://user-data.sh



~ on ☁️  (us-east-1) ➜  aws ec2 run-instances   --image-id     resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64     --instance-type $instance_type     --subnet-id $pub_subnet_id     --security-group-ids $nat_sg_id     --associate-public-ip-address     --key-name $keypair     --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=xfusion-nat-instance}]"     --user-data file://user-data.sh
{

# Add SSH rule to default security group
aws ec2 authorize-security-group-ingress \
  --group-id "$nat_sg_id" \
  --protocol tcp \
  --port -1 \
  --source-security-group cidr 0.0.0.0/0

aws ec2 authorize-security-group-egress \
  --group-id "$nat_sg_id" \
  --protocol tcp \
  --port -1 \
  --cidr 0.0.0.0/0

aws ec2 modify-instance-attribute --instance-id 'i-07a5a7b2f01e01caa' --attribute 'sourceDestCheck' --value 'false'

aws ec2 create-internet-gateway --tag-specifications '{"ResourceType":"internet-gateway","Tags":[{"Key":"Name","Value":"test-ig"}]}'

attach gateway 

nat route to ig

private roye to nat

tag_value=value

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
