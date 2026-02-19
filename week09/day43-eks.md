# Day XX - Task title

## Task

The Nautilus DevOps team has been tasked with preparing the infrastructure for a new Kubernetes-based application that will be deployed using Amazon EKS. The team is in the process of setting up an EKS cluster that meets their internal security and scalability standards. They require that the cluster be provisioned using the latest stable Kubernetes version to take advantage of new features and security improvements.

To minimize external exposure, the EKS cluster endpoint must be kept private. Additionally, the cluster needs to use the default VPC with availability zones a, b, and c to ensure high availability across different physical locations.

Your task is to create an EKS cluster named nautilus-eks, with Custom configuration, use IAM role for the cluster named eksClusterRole. Additionally, ensure that EKS Auto Mode is disabled and that the cluster endpoint access is set to private.

Finally, verify that the EKS cluster is successfully created with the correct configuration and is ready for workloads.

## Help

```bash
aws command help
aws command2 help
```

<details>
<summary><h2>Solution</h2></summary>

```bash
prefix=datacenter
cluster_name="$prefix-eks"

vpc_id=$(aws ec2 describe-vpcs \
  --filters "Name=isDefault,Values=true" \
  --query "Vpcs[].VpcId" \
  --output text) && echo "Default VPC ID: $vpc_id"

subnet_ids=$(aws ec2 describe-subnets \
  --filters \
    Name=vpc-id,Values="$vpc_id" \
    Name=availability-zone,Values=us-east-1a,us-east-1b,us-east-1c \
    Name=default-for-az,Values=true \
  --query "Subnets[].SubnetId" \
  --output text | tr '\t' ',') && echo "Subnet IDs: $subnet_ids"

aws eks create-cluster \
  --name "$cluster_name" \
  --version "1.27" \
  --role-arn "arn:aws:iam::123456789012:role/eksClusterRole" \
  --resources-vpc-config subnetIds=${subnet_ids},endpointPrivateAccess=true,endpointPublicAccess=false \
  && echo "Creating EKS cluster: $cluster_name"



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

aws_value=$(aws command describe-something \
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
