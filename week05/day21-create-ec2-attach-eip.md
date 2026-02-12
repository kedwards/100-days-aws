# Day 21 - Create EC2 Instance and Attach EIP

## Task

The Nautilus DevOps Team has received a new request from the Development Team to set up a new EC2 instance. This instance will be used to host a new application that requires a stable IP address. To ensure that the instance has a consistent public IP, an Elastic IP address needs to be associated with it. The instance will be named nautilus-ec2, and the Elastic IP will be named nautilus-eip. This setup will help the Development Team to have a reliable and consistent access point for their application.

Create an EC2 instance named nautilus-ec2 using any linux AMI like ubuntu, the Instance type must be t2.micro and associate an Elastic IP address with this instance, name it as nautilus-eip.

Use below given AWS Credentials: (You can run the showcreds command on aws-client host to retrieve these credentials)

## Help

```bash
aws ec2 describe-images help
aws ec2 run-instances help
aws ec2 allocate-address help
aws ec2 associate-address help
aws ec2 describe-addresses help
aws ec2 describe-instances help
```

<details>
<summary><h2>Solution</h2></summary>


```bash
instance_name=datacenter-ec2
eip_name=datacenter-eip
instance_type=t2.micro
region=us-east-1

# Get latest Amazon Linux 2023 AMI
read -r image_id < <(aws ec2 describe-images \
  --region "$region" \
  --owners amazon \
  --filters 'Name=name,Values=al2023-ami-2023.*-x86_64' \
  --query 'reverse(sort_by(Images, &CreationDate))[:1] | [0].ImageId' \
  --output text) && echo "Image ID: $image_id"

instance_name=xfusion-ec2
eip_name=xfusion-eip
instance_type=t2.micro
region=us-east-1

# Create EC2 instance
read -r instance_id < <(aws ec2 run-instances \
  --image-id "$image_id" \
  --instance-type "$instance_type" \
  --region "$region" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance_name}]" \
  --query "Instances[0].InstanceId" \
  --output text) && echo "Instance ID: $instance_id"

# Allocate Elastic IP
read -r allocation_id < <(aws ec2 allocate-address \
  --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=$eip_name}]" \
  --query "AllocationId" \
  --output text) && echo "Allocation ID: $allocation_id"

# Wait for instance to be running
aws ec2 wait instance-running --instance-ids "$instance_id"

# Associate EIP with instance
aws ec2 associate-address \
  --allocation-id "$allocation_id" \
  --instance-id "$instance_id"
```

</details>

<details>
<summary><h2>Validate</h2></summary>


```bash
aws ec2 describe-addresses --filters "Name=tag:Name,Values=$eip_name" \
  --query "Addresses[].{AllocationId:AllocationId,InstanceId:InstanceId,PublicIp:PublicIp}" \
  --output table

aws ec2 describe-instances --instance-ids "$instance_id" \
  --query "Reservations[].Instances[].{InstanceId:InstanceId,State:State.Name,PublicIp:PublicIpAddress}" \
  --output table
```

```bash
instance_name=nautilus-eip
eip_name=nautilus-eip
instance_type=t2.micro
region=eu-west-1

read -r allocation_id associated_instance public_ip < <(aws ec2 describe-addresses \
  --filters "Name=tag:Name,Values=$eip_name" \
  --query "Addresses[0].[AllocationId,InstanceId,PublicIp]" \
  --output text) && echo "Allocation ID: $allocation_id, Instance: $associated_instance, Public IP: $public_ip"

read -r instance_state instance_public_ip < <(aws ec2 describe-instances \
  --instance-ids "$instance_id" \
  --query "Reservations[0].Instances[0].[State.Name,PublicIpAddress]" \
  --output text) && echo "Instance state: $instance_state, Public IP: $instance_public_ip"

# Check validation
instance_exists=false
eip_attached=false
state_valid=false
ip_match=false

[[ -n "$instance_id" && "$instance_id" != "None" ]] && instance_exists=true
[[ "$associated_instance" == "$instance_id" ]] && eip_attached=true
[[ "$instance_state" == "running" ]] && state_valid=true
[[ "$public_ip" == "$instance_public_ip" ]] && ip_match=true

if [[ "$instance_exists" == true ]] && [[ "$eip_attached" == true ]] && [[ "$state_valid" == true ]] && [[ "$ip_match" == true ]]; then
  echo "✓ Success"
  echo "  Instance ID: $instance_id"
  echo "  Instance state: $instance_state"
  echo "  Public IP: $public_ip"
  echo "  EIP attached: Yes"
else
  echo "✗ Fail"
  
  if [[ "$instance_exists" == false ]]; then
    echo "  ✗ Instance not found"
  else
    echo "  ✓ Instance exists"
  fi
  
  if [[ "$state_valid" == false ]]; then
    echo "  ✗ Instance state validation failed"
    echo "    Expected: running"
    echo "    Got: $instance_state"
  else
    echo "  ✓ Instance state validation passed"
  fi
  
  if [[ "$eip_attached" == false ]]; then
    echo "  ✗ EIP not attached to instance"
    echo "    Expected instance: $instance_id"
    echo "    Associated to: $associated_instance"
  else
    echo "  ✓ EIP attached to instance"
  fi
  
  if [[ "$ip_match" == false ]]; then
    echo "  ✗ Public IP mismatch"
    echo "    Expected: $public_ip"
    echo "    Got: $instance_public_ip"
  else
    echo "  ✓ Public IP matches"
  fi
fi
```

</details>
