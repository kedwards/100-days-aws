# Day 04 - Enabling version for S3 Bucket

## Task

Data protection and recovery are fundamental aspects of data management. It's essential to have systems in place to ensure that data can be recovered in case of accidental deletion or corruption. The DevOps team has received a requirement for implementing such measures for one of the S3 buckets they are managing.

The s3 bucket name is xfusion-s3-31064, enable versioning for this bucket.

## Help

```bash
aws s3api list-buckets help
aws s3api put-bucket versioning help
aws s3api get-bucket versioning help
```

## Solution

```bash
bucket_name=xfusion-s3-31064

aws s3api put-bucket-versioning --bucket $bucket_name --versioning-configuration Status=Enabled
```

## Validate

```bash
aws s3api get-bucket-versioning --bucket $bucket_name \
  --query "Status"
```

```bash
read -r status < <(aws s3api get-bucket-versioning --bucket $bucket_name --query Status --output text)

versioning_valid=false
[[ "$status" == "Enabled" ]] && versioning_valid=true

if [[ "$versioning_valid" == true ]]; then
  echo "✓ Success"
  echo "  Bucket: $bucket_name"
  echo "  Versioning status: $status"
else
  echo "✗ Fail"
  echo "  ✗ Versioning validation failed"
  echo "    Expected: Enabled"
  echo "    Got: $status"
fi
```
