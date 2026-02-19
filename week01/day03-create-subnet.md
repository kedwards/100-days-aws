# Day 03: Create Subnet

## Task

For this task, create one subnet named devops-subnet under default VPC.

## Help

```bash
aws ec2 describe-vpcs help
aws ec2 describe-subnets help
aws ec2 create-subnet help
```

<details>
<summary><h2>Solution</h2></summary>


```bash
subnet_name=devops-subnet

read -r vpc_id cidr_block <<< "$(aws ec2 describe-vpcs \
    --query "Vpcs[?IsDefault].[VpcId,CidrBlock]" \
    --output text)" && echo "VPC ID: $vpc_id, CIDR Block: $cidr_block"

aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$vpc_id" \
  --query "Subnets[*].CidrBlock"

aws ec2 create-subnet \
  --vpc-id "$vpc_id" \
  --cidr-block 172.31.96.0/20 \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$subnet_name}]"
```

</details>

<details>
<summary><h2>Validate</h2></summary>


```bash
aws ec2 describe-subnets --filters "Name=tag:Name,Values=$subnet_name" \
  --query "Subnets[].{SubnetId:SubnetId,Name:Tags[?Key=='Name'].Value|[0],VpcId:VpcId,CidrBlock:CidrBlock}" \
  --output table
```

```bash
read -r subnet_id name vpc <<< "$(aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=$subnet_name" \
  --query "Subnets[0].[SubnetId,Tags[?Key=='Name'].Value|[0],VpcId]" \
  --output text)" && echo "Subnet ID: $subnet_id, Name: $name, VPC: $vpc"

subnet_exists=false
name_valid=false
vpc_valid=false

[[ -n "$subnet_id" && "$subnet_id" != "None" ]] && subnet_exists=true
[[ "$name" == "$subnet_name" ]] && name_valid=true
[[ "$vpc" == "$vpc_id" ]] && vpc_valid=true

if [[ "$subnet_exists" == true ]] && [[ "$name_valid" == true ]] && [[ "$vpc_valid" == true ]]; then
  echo "✓ Success"
  echo "  Subnet ID: $subnet_id"
  echo "  Subnet name: $name"
  echo "  VPC ID: $vpc"
else
  echo "✗ Fail"
  
  if [[ "$subnet_exists" == false ]]; then
    echo "  ✗ Subnet not found"
  else
    echo "  ✓ Subnet exists"
  fi
  
  if [[ "$name_valid" == false ]]; then
    echo "  ✗ Subnet name validation failed"
    echo "    Expected: $subnet_name"
    echo "    Got: $name"
  else
    echo "  ✓ Subnet name validation passed"
  fi
  
  if [[ "$vpc_valid" == false ]]; then
    echo "  ✗ VPC validation failed (not in default VPC)"
    echo "    Expected: $vpc_id"
    echo "    Got: $vpc"
  else
    echo "  ✓ VPC validation passed"
  fi
fi
```

</details>
