# Day 23: Data Migration Between S3 Buckets Using AWS CLI

## Task

As part of a data migration project, the team lead has tasked the team with migrating data from an existing S3 bucket to a new S3 bucket. The existing bucket contains a substantial amount of data that must be accurately transferred to the new bucket. The team is responsible for creating the new S3 bucket and ensuring that all data from the existing bucket is copied or synced to the new bucket completely and accurately. It is imperative to perform thorough verification steps to confirm that all data has been successfully transferred to the new bucket without any loss or corruption.

As a member of the Nautilus DevOps Team, your task is to perform the following:

Create a New Private S3 Bucket: Name the bucket nautilus-sync-27859.

Data Migration: Migrate the entire data from the existing nautilus-s3-6954 bucket to the new nautilus-sync-27859 bucket.

Ensure Data Consistency: Ensure that both buckets have the same data.

Use AWS CLI: Use the AWS CLI to perform the creation and data migration tasks.


## Help

```bash
aws s3api create-bucket help
aws s3api head-bucket help
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

# Verify bucket contents match
echo "Source:"
aws s3 ls s3://"$source_bucket"/ --recursive
echo "Destination:"
aws s3 ls s3://"$destination_bucket"/ --recursive
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
# Variables should match those defined in Solution section

# Count objects in both buckets
source_count=$(aws s3 ls s3://"$source_bucket"/ --recursive | wc -l) && echo "Source count: $source_count"
dest_count=$(aws s3 ls s3://"$destination_bucket"/ --recursive | wc -l) && echo "Destination count: $dest_count"

# Check if destination bucket exists
bucket_exists=$(aws s3api head-bucket --bucket "$destination_bucket" 2>&1) && bucket_valid=true && echo "Bucket exists check: $bucket_exists"

# Check validation
sync_valid=false

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
