# Day 6: Launch EC2 Instance

## Task

For this task, create an EC2 instance with following requirements:

 - The name of the instance must be nautilus-ec2.
 - You can use the Amazon Linux AMI to launch this instance.
 - The Instance type must be t2.micro.
 - Create a new RSA key pair named nautilus-kp.
 - Attach the default (available by default) security group.

## Help

```bash
aws ec2 describe-images help
aws ec2 describe-security-groups help
aws ec2 create-key-pair help
aws ec2 run-instances help
aws ec2 describe-instances help
```

<details>
<summary><h2>Solution</h2></summary>


```bash
key_name=nautilus-kp
key_type=rsa
instance_name=nautilus-ec2
instance_type=t2.micro
region=us-east-1

aws ec2 create-key-pair --key-name "$key_name" \
  --key-type "$key_type" \
  --tag-specifications "ResourceType=key-pair,Tags=[{Key=Name,Value=$key_name}]"

image_id=$(aws ec2 describe-images \
  --region "$region" \
  --owners amazon \
  --filters 'Name=name,Values=al2023-ami-2023.*-x86_64' \
  --query 'reverse(sort_by(Images, &CreationDate))[:1] | [0].ImageId' \
  --output text) && echo "Image ID: $image_id"

default_sg=$(aws ec2 describe-security-groups \
  --query "SecurityGroups[?GroupName=='default'].GroupId" \
  --output text) && echo "Default security group: $default_sg"

aws ec2 run-instances \
  --image-id "$image_id" \
  --instance-type "$instance_type" \
  --region "$region" \
  --security-group-ids "$default_sg" \
  --key-name "$key_name" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance_name}]"
```

</details>

<details>
<summary><h2>Validate</h2></summary>


```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$instance_name" \
  --query "Reservations[].Instances[].{ID:InstanceId,State:State.Name,Type:InstanceType,AZ:Placement.AvailabilityZone}" \
  --output table
```

```bash
read -r id type instance_key image_id az sg_ids <<< "$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$instance_name" \
  --query "Reservations[0].Instances[0].[InstanceId,InstanceType,KeyName,ImageId,Placement.AvailabilityZone,SecurityGroups[*].GroupId|join(',', @)]" \
  --output text)" && echo "Instance ID: $id, Type: $type, Key: $instance_key, Image: $image_id, AZ: $az, SG: $sg_ids"

instance_region="${az%?}"

ami_name=$(aws ec2 describe-images \
  --image-ids "$image_id" \
  --query "Images[0].Name" \
  --output text) && echo "AMI name: $ami_name"

default_sg=$(aws ec2 describe-security-groups \
  --query "SecurityGroups[?GroupName=='default'].GroupId" \
  --output text) && echo "Default security group: $default_sg"

instance_exists=false
type_valid=false
key_valid=false
region_valid=false
ami_valid=false
sg_valid=false

[[ -n "$id" && "$id" != "None" ]] && instance_exists=true
[[ "$type" == "$instance_type" ]] && type_valid=true
[[ "$instance_key" == "$key_name" ]] && key_valid=true
[[ "$instance_region" == "$region" ]] && region_valid=true
[[ "$ami_name" =~ al2023 ]] && ami_valid=true
[[ "$sg_ids" =~ $default_sg ]] && sg_valid=true

if [[ "$instance_exists" == true ]] && [[ "$type_valid" == true ]] && [[ "$key_valid" == true ]] && \
   [[ "$region_valid" == true ]] && [[ "$ami_valid" == true ]] && [[ "$sg_valid" == true ]]; then
  echo "✓ Success"
  echo "  Instance ID: $id"
  echo "  Type: $type"
  echo "  Key Name: $instance_key"
  echo "  Region: $instance_region"
  echo "  AMI: $ami_name"
  echo "  Security Groups: $sg_ids"
else
  echo "✗ Fail"
  
  if [[ "$instance_exists" == false ]]; then
    echo "  ✗ Instance not found with name: $instance_name"
  else
    echo "  ✓ Instance exists"
  fi
  
  if [[ "$type_valid" == false ]]; then
    echo "  ✗ Instance type validation failed"
    echo "    Expected: $instance_type"
    echo "    Got: $type"
  else
    echo "  ✓ Instance type validation passed"
  fi
  
  if [[ "$key_valid" == false ]]; then
    echo "  ✗ Key pair validation failed"
    echo "    Expected: $key_name"
    echo "    Got: $instance_key"
  else
    echo "  ✓ Key pair validation passed"
  fi
  
  if [[ "$region_valid" == false ]]; then
    echo "  ✗ Region validation failed"
    echo "    Expected: $region"
    echo "    Got: $instance_region"
  else
    echo "  ✓ Region validation passed"
  fi
  
  if [[ "$ami_valid" == false ]]; then
    echo "  ✗ AMI validation failed (not Amazon Linux)"
    echo "    Got: $ami_name"
  else
    echo "  ✓ AMI validation passed (Amazon Linux)"
  fi
  
  if [[ "$sg_valid" == false ]]; then
    echo "  ✗ Security group validation failed (default SG not attached)"
    echo "    Expected: $default_sg"
    echo "    Got: $sg_ids"
  else
    echo "  ✓ Security group validation passed"
  fi
fi
```

</details>
