# Day 2: Create Security Group

## Task

For this task, create a security group under default VPC with the following requirements:

- Name of the security group is nautillus-sg.
- The description must be Security group for Nautilus App Servers
- Add the inbound rule of type HTTP, with port range of 80. Enter the source CIDR range of 0.0.0.0/0.
- Add another inbound rule of type SSH, with port range of 22. Enter the source CIDR range of 0.0.0.0/0.

## Help

```bash
aws ec2 describe-vpcs help
aws ec2 create-security-group help
aws ec2 describe-security-groups help
aws ec2 authorize-security-group-ingress help
aws ec2 describe-security-group-rules help
```

<details>
<summary><h2>Solution</h2></summary>


```bash
group_name="nautilus-sg"
description="Security group for Nautilus App Servers"

read -r vpc_id < <(aws ec2 describe-vpcs \
  --query "Vpcs[?IsDefault].VpcId" \
  --output text) && echo "Default VPC ID: $vpc_id"

read -r group_id < <(aws ec2 create-security-group \
  --description "$description" \
  --group-name "$group_name" \
  --vpc-id "$vpc_id" \
  --query GroupId \
  --output text) && echo "Created Security Group ID: $group_id"

aws ec2 authorize-security-group-ingress \
  --group-id "$group_id" \
  --ip-permissions 'IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges=[{CidrIp=0.0.0.0/0}]' 'IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=0.0.0.0/0}]'
```

</details>

<details>
<summary><h2>Validate</h2></summary>


```bash
aws ec2 describe-security-groups --group-names "$group_name" \
  --query "SecurityGroups[].{GroupName:GroupName,Description:Description,VpcId:VpcId}" \
  --output table

aws ec2 describe-security-group-rules --filters "Name=group-id,Values=$group_id" \
  --query "SecurityGroupRules[?IsEgress==\`false\`].{Protocol:IpProtocol,FromPort:FromPort,ToPort:ToPort,CIDR:CidrIpv4}" \
  --output table
```

```bash
read -r desc < <(aws ec2 describe-security-groups \
  --group-names "$group_name" \
  --query "SecurityGroups[?GroupName=='"$group_name"'].Description" \
  --output text) && echo "Security Group Description: $desc"

ssh_rule=$(aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=$group_id" \
  --query "SecurityGroupRules[?IsEgress==\`false\` && IpProtocol==\`tcp\` && FromPort==\`22\` && ToPort==\`22\` && CidrIpv4==\`*******/0\`]" \
  --output json)

http_rule=$(aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=$group_id" \
  --query "SecurityGroupRules[?IsEgress==\`false\` && IpProtocol==\`tcp\` && FromPort==\`80\` && ToPort==\`80\` && CidrIpv4==\`*******/0\`]" \
  --output json)

ssh_rule_count=$(echo $ssh_rule | jq 'length')
http_rule_count=$(echo $http_rule | jq 'length')

ssh_valid=false
http_valid=false
desc_valid=false

[[ $ssh_rule_count -gt 0 ]] && ssh_valid=true
[[ $http_rule_count -gt 0 ]] && http_valid=true
[[ "$desc" = "$description" ]] && desc_valid=true

if [[ "$ssh_valid" == true ]] && [[ "$http_valid" == true ]] && [[ "$desc_valid" == true ]]; then
  echo "✓ Success"
  echo "  Description: $desc"
  echo "  SSH rule (port 22): Found"
  echo "  HTTP rule (port 80): Found"
else
  echo "✗ Fail"
  
  if [[ "$desc_valid" == false ]]; then
    echo "  ✗ Description validation failed"
    echo "    Expected: $description"
    echo "    Got: $desc"
  else
    echo "  ✓ Description validation passed"
  fi
  
  if [[ "$ssh_valid" == false ]]; then
    echo "  ✗ SSH rule validation failed (port 22 not found or misconfigured)"
    echo "    Rule details: $ssh_rule"
  else
    echo "  ✓ SSH rule validation passed"
  fi
  
  if [[ "$http_valid" == false ]]; then
    echo "  ✗ HTTP rule validation failed (port 80 not found or misconfigured)"
    echo "    Rule details: $http_rule"
  else
    echo "  ✓ HTTP rule validation passed"
  fi
fi
```

</details>
