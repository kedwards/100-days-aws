# Day 23 - Sync S3 Buckets

## Task

Create a new S3 bucket and sync content from an existing S3 bucket to the new bucket.

## Help

```bash
aws s3api create-bucket help
aws s3 sync help
aws s3 ls help
```

<details>
<summary><h2>Solution</h2></summary>


```bash
source_bucket=datacenter-s3-source
destination_bucket=datacenter-sync-bucket
region=us-east-1

# Create destination bucket
aws s3api create-bucket \
  --bucket "$destination_bucket" \
  --region "$region"

# Sync buckets
aws s3 sync s3://"$source_bucket"/ s3://"$destination_bucket"/
```

</details>
<details>
<summary><h2>Validate</h2></summary>


```bash
echo "Source bucket contents:"
aws s3 ls s3://"$source_bucket"/ --recursive

echo "Destination bucket contents:"
aws s3 ls s3://"$destination_bucket"/ --recursive
```

```bash
# Count objects in both buckets
source_count=$(aws s3 ls s3://"$source_bucket"/ --recursive | wc -l)
dest_count=$(aws s3 ls s3://"$destination_bucket"/ --recursive | wc -l)

# Check if destination bucket exists
bucket_exists=$(aws s3api head-bucket --bucket "$destination_bucket" 2>&1)

# Check validation
bucket_valid=false
sync_valid=false

[[ -z "$bucket_exists" ]] && bucket_valid=true
[[ "$source_count" -eq "$dest_count" && "$dest_count" -gt 0 ]] && sync_valid=true

if [[ "$bucket_valid" == true ]] && [[ "$sync_valid" == true ]]; then
  echo "✓ Success"
  echo "  Source bucket: $source_bucket"
  echo "  Destination bucket: $destination_bucket"
  echo "  Objects in source: $source_count"
  echo "  Objects in destination: $dest_count"
  echo "  Sync status: Complete"
else
  echo "✗ Fail"
  
  if [[ "$bucket_valid" == false ]]; then
    echo "  ✗ Destination bucket not found or not accessible"
  else
    echo "  ✓ Destination bucket exists"
  fi
  
  if [[ "$sync_valid" == false ]]; then
    echo "  ✗ Bucket sync validation failed"
    echo "    Source objects: $source_count"
    echo "    Destination objects: $dest_count"
  else
    echo "  ✓ Bucket sync validation passed"
  fi
fi
```

</details>
