# Day 43: Scaling and Managing Kubernetes Clusters with Amazon EKS

## Task

The Nautilus DevOps team has been tasked with preparing the infrastructure for a new Kubernetes-based application that will be deployed using Amazon EKS. The team is in the process of setting up an EKS cluster that meets their internal security and scalability standards. They require that the cluster be provisioned using the latest stable Kubernetes version to take advantage of new features and security improvements.

To minimize external exposure, the EKS cluster endpoint must be kept private. Additionally, the cluster needs to use the default VPC with availability zones a, b, and c to ensure high availability across different physical locations.

Your task is to create an EKS cluster named nautilus-eks, with Custom configuration, use IAM role for the cluster named eksClusterRole. Additionally, ensure that EKS Auto Mode is disabled and that the cluster endpoint access is set to private.

Finally, verify that the EKS cluster is successfully created with the correct configuration and is ready for workloads.

## Help

```bash
aws eks create-cluster help
aws eks describe-cluster help
aws iam create-role help
aws iam attach-role-policy help
```

<details>
<summary><h2>Solution</h2></summary>

```bash
prefix=nautilus
cluster_name="$prefix-eks"
role_name="eksClusterRole"

# ── Get VPC and subnets ──────────────────────────────────────
vpc_id=$(aws ec2 describe-vpcs \
  --filters "Name=isDefault,Values=true" \
  --query "Vpcs[0].VpcId" \
  --output text) && echo "Default VPC ID: $vpc_id"

subnet_ids=$(aws ec2 describe-subnets \
  --filters \
    "Name=vpc-id,Values=$vpc_id" \
    "Name=availability-zone,Values=us-east-1a,us-east-1b,us-east-1c" \
    "Name=default-for-az,Values=true" \
  --query "Subnets[].SubnetId" \
  --output text | tr '\t' ',') && echo "Subnet IDs: $subnet_ids"
# ── Create IAM role ──────────────────────────────────────────
cat <<EOF > eks-trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }
  ]
}
EOF

role_arn=$(aws iam create-role \
  --role-name "$role_name" \
  --assume-role-policy-document file://eks-trust-policy.json \
  --query "Role.Arn" \
  --output text) && echo "Created IAM role: $role_name - $role_arn"

aws iam attach-role-policy --role-name "$role_name" \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy

# ── Create EKS cluster ──────────────────────────────────────
aws eks create-cluster \
  --name "$cluster_name" \
  --role-arn "$role_arn" \
  --resources-vpc-config subnetIds="$subnet_ids",endpointPrivateAccess=true,endpointPublicAccess=false \
  && echo "Creating EKS cluster: $cluster_name"

aws eks wait cluster-active
```

</details>

<details>
<summary><h2>Validate</h2></summary>

```bash
aws eks describe-cluster --name "$cluster_name" \
  --query "cluster.{Name:name,Status:status,Endpoint:endpoint,PrivateAccess:resourcesVpcConfig.endpointPrivateAccess,PublicAccess:resourcesVpcConfig.endpointPublicAccess}" \
  --output table
```

```bash
cluster_name="nautilus-eks"
role_name="eksClusterRole"

read -r cluster_status private_access public_access cluster_role_arn <<< "$(aws eks describe-cluster \
  --name "$cluster_name" \
  --query "cluster.[status,resourcesVpcConfig.endpointPrivateAccess,resourcesVpcConfig.endpointPublicAccess,roleArn]" \
  --output text)" && echo "Cluster: $cluster_name, Status: $cluster_status"

status_valid=false
private_valid=false
public_valid=false
role_valid=false

[[ "$cluster_status" == "ACTIVE" ]] && status_valid=true
[[ "$private_access" == "True" ]] && private_valid=true
[[ "$public_access" == "False" ]] && public_valid=true
[[ "$cluster_role_arn" == *"$role_name"* ]] && role_valid=true

if [[ "$status_valid" == true ]] && [[ "$private_valid" == true ]] && [[ "$public_valid" == true ]] && [[ "$role_valid" == true ]]; then
  echo "✓ Success"
  echo "  Cluster Name: $cluster_name"
  echo "  Status: $cluster_status"
  echo "  Private Endpoint: $private_access"
  echo "  Public Endpoint: $public_access"
  echo "  Role ARN: $cluster_role_arn"
else
  echo "✗ Fail"

  if [[ "$status_valid" == false ]]; then
    echo "  ✗ Cluster status validation failed"
    echo "    Expected: ACTIVE"
    echo "    Got: $cluster_status"
  else
    echo "  ✓ Cluster status is ACTIVE"
  fi

  if [[ "$private_valid" == false ]]; then
    echo "  ✗ Private endpoint access validation failed"
    echo "    Expected: True"
    echo "    Got: $private_access"
  else
    echo "  ✓ Private endpoint access enabled"
  fi

  if [[ "$public_valid" == false ]]; then
    echo "  ✗ Public endpoint access validation failed"
    echo "    Expected: False"
    echo "    Got: $public_access"
  else
    echo "  ✓ Public endpoint access disabled"
  fi

  if [[ "$role_valid" == false ]]; then
    echo "  ✗ IAM role validation failed"
    echo "    Expected role containing: $role_name"
    echo "    Got: $cluster_role_arn"
  else
    echo "  ✓ IAM role is correct"
  fi
fi
```

</details>
