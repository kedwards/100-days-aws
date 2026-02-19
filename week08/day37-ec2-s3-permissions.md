# Day 37: EC2 to S3 Access with IAM Role

## Task

The Nautilus DevOps team needs to set up an application on an EC2 instance to interact with an S3 bucket for storing and retrieving data. To achieve this, the team must create a private S3 bucket, set appropriate IAM policies and roles, and test the application functionality.
Task:

1) EC2 Instance Setup:

    An instance named datacenter-ec2 already exists.
    The instance requires access to an S3 bucket.

2) Setup SSH Keys:

    Create new SSH key pair (id_rsa and id_rsa.pub) on the aws-client host and add the public key to the root user's authorized keys on the EC2 instance.

3) Create a Private S3 Bucket:

    Name the bucket datacenter-s3-4980.
    Ensure the bucket is private.

4) Create an IAM Policy and Role:

    Create an IAM policy allowing s3:PutObject, s3:ListBucket and s3:GetObject access to datacenter-s3-4980.
    Create an IAM role named datacenter-role.
    Attach the policy to the IAM role.
    Attach this role to the datacenter-ec2 instance.

5) Test the Access:

    SSH into the EC2 instance and try to upload a file to datacenter-s3-4980 bucket using following command:

aws s3 cp <your-file> s3://datacenter-s3-4980/

    Now run following command to list the upload file:

aws s3 ls s3://datacenter-s3-4980/

## Help

```bash
aws s3api create-bucket help
aws s3api head-bucket help
aws s3 ls help
aws s3 cp help
aws iam create-role help
aws iam put-role-policy help
aws iam get-role help
aws iam create-instance-profile help
aws iam add-role-to-instance-profile help
aws ec2 describe-instances help
aws ec2 associate-iam-instance-profile help
aws ec2 describe-iam-instance-profile-associations help
```

<details>
<summary><h2>Solution</h2></summary>

```bash
prefix=datacenter
instance_name=$prefix-ec2
bucket_name=$prefix-s3-17577
role_name=$prefix-role

if [[ ! -f ~/.ssh/id_rsa ]]; then
  ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N ""
fi

cat ~/.ssh/id_rsa.pub

aws s3api create-bucket \
  --bucket $bucket_name \
  --acl private \
  --object-ownership BucketOwnerEnforced

role_arn=$(aws iam create-role \
  --role-name $role_name \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "ec2.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }' \
  --query 'Role.Arn' \
  --output text) && echo "Role ARN: $role_arn"

policy_arn=$(aws iam create-policy \
  --policy-name $role_name-s3-policy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:GetObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::'"$bucket_name"'",
        "arn:aws:s3:::'"$bucket_name"'/*"
      ]
    }]
  }' \
  --query 'Policy.Arn' \
  --output text) && echo "Policy ARN: $policy_arn"

aws iam attach-role-policy \
  --role-name $role_name \
  --policy-arn $policy_arn

instance_profile_arn=$(aws iam create-instance-profile \
  --instance-profile-name $role_name \
  --query 'InstanceProfile.Arn' \
  --output text) && echo "Instance Profile ARN: $instance_profile_arn"

aws iam add-role-to-instance-profile \
  --instance-profile-name $role_name \
  --role-name $role_name

read -r public_ip instance_id <<< "$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$instance_name" \
  --query "Reservations[].Instances[].[PublicIpAddress,InstanceId]" \
  --output text)" && echo "Instance ID: $instance_id, Public IP: $public_ip"

aws ec2 associate-iam-instance-profile \
  --instance-id $instance_id \
  --iam-instance-profile Name=$role_name

ssh -i ~/.ssh/id_rsa root@$public_ip
```

</details>

<details>
<summary><h2>Validate</h2></summary>

```bash
aws s3api head-bucket --bucket $bucket_name

aws s3 ls s3://$bucket_name/

aws iam get-role --role-name $role_name \
  --query "Role.{RoleName:RoleName,Arn:Arn}" \
  --output table

aws ec2 describe-iam-instance-profile-associations \
  --filters "Name=instance-id,Values=$instance_id" \
  --query "IamInstanceProfileAssociations[].{InstanceId:InstanceId,ProfileArn:IamInstanceProfile.Arn,State:State}" \
  --output table
```

```bash
prefix=datacenter
instance_name=$prefix-ec2
bucket_name=$prefix-s3-17577
role_name=$prefix-role

# Check EC2 instance
read -r instance_id instance_state public_ip <<< "$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$instance_name" \
  --query "Reservations[0].Instances[0].[InstanceId,State.Name,PublicIpAddress]" \
  --output text 2>/dev/null)"&& echo "EC2: $instance_id, State: $instance_state, Public IP: $public_ip"

# Check S3 bucket exists and is private
bucket_exists=false
aws s3api head-bucket --bucket $bucket_name 2>/dev/null && bucket_exists=true
echo "Bucket exists: $bucket_exists"

# Check bucket public access block
read -r block_public_acls block_public_policy <<< "$(aws s3api get-public-access-block \
  --bucket $bucket_name \
  --query "PublicAccessBlockConfiguration.[BlockPublicAcls,BlockPublicPolicy]" \
  --output text 2>/dev/null)"&& echo "Block Public ACLs: $block_public_acls, Block Public Policy: $block_public_policy"

# Check IAM role
read -r iam_role_name iam_role_arn <<< "$(aws iam get-role \
  --role-name $role_name \
  --query "Role.[RoleName,Arn]" \
  --output text 2>/dev/null)"&& echo "IAM Role: $iam_role_name"

# Check role policy has correct permissions
policy_doc=$(aws iam get-role-policy \
  --role-name $role_name \
  --policy-name $role_name-s3-policy \
  --query "PolicyDocument" \
  --output json 2>/dev/null)
echo "Policy document retrieved: $(echo $policy_doc | jq -r '.Statement[0].Action' 2>/dev/null)"

# Check IAM instance profile association
read -r profile_arn profile_state <<< "$(aws ec2 describe-iam-instance-profile-associations \
  --filters "Name=instance-id,Values=$instance_id" \
  --query "IamInstanceProfileAssociations[0].[IamInstanceProfile.Arn,State]" \
  --output text 2>/dev/null)"&& echo "Instance Profile: $profile_arn, State: $profile_state"

# Validation checks
ec2_exists=false
ec2_running=false
s3_bucket_exists=false
role_exists=false
policy_valid=false
profile_attached=false

[[ -n "$instance_id" && "$instance_id" != "None" ]] && ec2_exists=true
[[ "$instance_state" == "running" ]] && ec2_running=true
[[ "$bucket_exists" == true ]] && s3_bucket_exists=true
[[ -n "$iam_role_name" && "$iam_role_name" != "None" ]] && role_exists=true
[[ "$policy_doc" == *"s3:PutObject"* && "$policy_doc" == *"s3:GetObject"* && "$policy_doc" == *"s3:ListBucket"* ]] && policy_valid=true
[[ -n "$profile_arn" && "$profile_arn" != "None" && "$profile_state" == "associated" ]] && profile_attached=true

if [[ "$ec2_exists" == true ]] && [[ "$ec2_running" == true ]] && [[ "$s3_bucket_exists" == true ]] && [[ "$role_exists" == true ]] && [[ "$policy_valid" == true ]] && [[ "$profile_attached" == true ]]; then
  echo "✓ Success"
  echo "  EC2 Instance: $instance_id ($instance_state)"
  echo "  Public IP: $public_ip"
  echo "  S3 Bucket: $bucket_name"
  echo "  IAM Role: $iam_role_name"
  echo "  Policy: s3:PutObject, s3:GetObject, s3:ListBucket"
  echo "  Instance Profile: Attached ($profile_state)"
else
  echo "✗ Fail"
  
  if [[ "$ec2_exists" == false ]]; then
    echo "  ✗ EC2 instance '$instance_name' not found"
  else
    echo "  ✓ EC2 instance exists"
  fi
  
  if [[ "$ec2_running" == false ]]; then
    echo "  ✗ EC2 instance not running"
    echo "    Got: $instance_state"
  else
    echo "  ✓ EC2 instance is running"
  fi
  
  if [[ "$s3_bucket_exists" == false ]]; then
    echo "  ✗ S3 bucket '$bucket_name' not found"
  else
    echo "  ✓ S3 bucket exists"
  fi
  
  if [[ "$role_exists" == false ]]; then
    echo "  ✗ IAM role '$role_name' not found"
  else
    echo "  ✓ IAM role exists"
  fi
  
  if [[ "$policy_valid" == false ]]; then
    echo "  ✗ IAM policy validation failed"
    echo "    Expected: s3:PutObject, s3:GetObject, s3:ListBucket"
  else
    echo "  ✓ IAM policy has correct permissions"
  fi
  
  if [[ "$profile_attached" == false ]]; then
    echo "  ✗ Instance profile not attached to EC2"
    echo "    Profile ARN: $profile_arn"
    echo "    State: $profile_state"
  else
    echo "  ✓ Instance profile attached"
  fi
fi
```

</details>
