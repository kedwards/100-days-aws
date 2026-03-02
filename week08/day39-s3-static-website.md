# Day 39: Hosting a Static Website on AWS S3

## Task

The Nautilus DevOps team has been tasked with creating an internal information portal for public access. As part of this project, they need to host a static website on AWS using an S3 bucket. The S3 bucket must be configured for public access to allow external users to access the static website directly via the S3 website URL.

Task Requirements:

    Create an S3 bucket named devops-web-26069.
    Configure the S3 bucket for static website hosting with index.html as the index document.
    Allow public access to the bucket so that the website is publicly accessible.
    Upload the index.html file from the /root/ directory of the AWS client host to the S3 bucket.
    Verify that the website is accessible directly through the S3 website URL.

## Help

```bash
aws s3api create-bucket help
aws s3api put-public-access-block help
aws s3api put-bucket-policy help
aws s3api put-bucket-website help
aws s3api get-bucket-website help
aws s3api head-bucket help
aws s3 cp help
aws s3 ls help
```

<details>
<summary><h2>Solution</h2></summary>

```bash
prefix=devops
bucket_name=$prefix-web-26069
region=us-east-1
s3_url="http://$bucket_name.s3-website-$region.amazonaws.com"

aws s3api create-bucket \
  --bucket $bucket_name \
  --acl public-read \
  --region us-east-1

aws s3api put-public-access-block \
  --bucket "$bucket_name" \
  --public-access-block-configuration BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false

policy=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::$bucket_name/*"
    }
  ]
}
EOF
)

aws s3api put-bucket-policy \
  --bucket "$bucket_name" \
  --policy "$policy"


cat <<EOF > website.json
{
  "IndexDocument": {
    "Suffix": "index.html"
  }
}
EOF

aws s3api put-bucket-website \
  --bucket $bucket_name \
  --website-configuration file://website.json

# Upload index.html to the bucket
aws s3 cp /root/index.html s3://$bucket_name/index.html

# Test the website
echo "Website URL: $s3_url"
curl $s3_url

```

</details>

<details>
<summary><h2>Validate</h2></summary>

```bash
aws s3api head-bucket --bucket $bucket_name

aws s3api get-bucket-website --bucket $bucket_name

aws s3 ls s3://$bucket_name/

curl -I $s3_url
```

```bash
prefix=devops
bucket_name=$prefix-web-26069
region=us-east-1
s3_url="http://$bucket_name.s3-website-$region.amazonaws.com"

# Check if bucket exists
bucket_exists=false
aws s3api head-bucket --bucket $bucket_name 2>/dev/null && bucket_exists=true
echo "Bucket exists: $bucket_exists"

# Check website configuration
index_doc=$(aws s3api get-bucket-website \
  --bucket $bucket_name \
  --query "IndexDocument.Suffix" \
  --output text 2>/dev/null) && echo "Index document: $index_doc"

# Check if index.html exists in bucket
index_exists=false
aws s3 ls s3://$bucket_name/index.html 2>/dev/null && index_exists=true
echo "index.html exists: $index_exists"

# Check public access block settings
read -r block_public_acls block_public_policy <<< "$(aws s3api get-public-access-block \
  --bucket $bucket_name \
  --query "PublicAccessBlockConfiguration.[BlockPublicAcls,BlockPublicPolicy]" \
  --output text 2>/dev/null)"&& echo "Block Public ACLs: $block_public_acls, Block Public Policy: $block_public_policy"

# Test website accessibility
echo "Testing website URL: $s3_url"
http_status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "$s3_url" 2>/dev/null)
echo "HTTP Status: $http_status"

# Get response content (first 100 chars)
response_preview=$(curl -s --connect-timeout 10 "$s3_url" 2>/dev/null | head -c 100)
echo "Response preview: $response_preview"

# Validation checks
bucket_valid=false
website_config_valid=false
index_file_valid=false
public_access_valid=false
http_success=false

[[ "$bucket_exists" == true ]] && bucket_valid=true
[[ "$index_doc" == "index.html" ]] && website_config_valid=true
[[ "$index_exists" == true ]] && index_file_valid=true
[[ "$block_public_acls" == "False" || "$block_public_acls" == "false" ]] && public_access_valid=true
[[ "$http_status" == "200" ]] && http_success=true

if [[ "$bucket_valid" == true ]] && [[ "$website_config_valid" == true ]] && [[ "$index_file_valid" == true ]] && [[ "$public_access_valid" == true ]] && [[ "$http_success" == true ]]; then
  echo "✓ Success"
  echo "  Bucket: $bucket_name"
  echo "  Index Document: $index_doc"
  echo "  Public Access: Enabled"
  echo "  Website URL: $s3_url"
  echo "  HTTP Status: $http_status (OK)"
else
  echo "✗ Fail"
  
  if [[ "$bucket_valid" == false ]]; then
    echo "  ✗ Bucket '$bucket_name' not found"
  else
    echo "  ✓ Bucket exists"
  fi
  
  if [[ "$website_config_valid" == false ]]; then
    echo "  ✗ Website configuration not set correctly"
    echo "    Expected index document: index.html"
    echo "    Got: $index_doc"
  else
    echo "  ✓ Website configuration is correct"
  fi
  
  if [[ "$index_file_valid" == false ]]; then
    echo "  ✗ index.html not found in bucket"
  else
    echo "  ✓ index.html exists in bucket"
  fi
  
  if [[ "$public_access_valid" == false ]]; then
    echo "  ✗ Public access not enabled"
    echo "    BlockPublicAcls: $block_public_acls (should be False)"
  else
    echo "  ✓ Public access is enabled"
  fi
  
  if [[ "$http_success" == false ]]; then
    echo "  ✗ Website not accessible"
    echo "    URL: $s3_url"
    echo "    Expected: 200"
    echo "    Got: $http_status"
  else
    echo "  ✓ Website is accessible (HTTP 200)"
  fi
fi
```

</details>
