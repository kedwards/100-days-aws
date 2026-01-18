# Day 05 - Create GP3 Volume

## Task

Create a volume with the following requirements:

- Name of the volume should be xfusion-volume.
- Volume type must be gp3.
- Volume size must be 2 GiB.

## Help

```bash
aws ec2 create-volume help
```

## Solution

```bash
volume_name=xfusion-volume
volume_size=2
volume_type=gp3

aws ec2 create-volume --volume-type "$volume_type" --availability-zone us-east-1a --size "$volume_size" --tag-specifications "ResourceType=volume,Tags=[{Key=Name,Value=$volume_name}]"

```

## Validate

```bash
aws ec2 describe-volumes --filters "Name=tag:Name,Values=$volume_name" \
  --query "Volumes[].{VolumeId:VolumeId,Name:Tags[?Key=='Name'].Value|[0],Size:Size,Type:VolumeType,State:State}" \
  --output table
```

```bash
read -r id size type < <(aws ec2 describe-volumes --filters "Name=tag:Name,Values=$volume_name" --query "Volumes[0].[VolumeId,Size,VolumeType]" --output text)

volume_exists=false
size_valid=false
type_valid=false

[[ -n "$id" && "$id" != "None" ]] && volume_exists=true
[[ "$size" == "$volume_size" ]] && size_valid=true
[[ "$type" == "$volume_type" ]] && type_valid=true

if [[ "$volume_exists" == true ]] && [[ "$size_valid" == true ]] && [[ "$type_valid" == true ]]; then
  echo "✓ Success"
  echo "  Volume ID: $id"
  echo "  Volume size: $size GiB"
  echo "  Volume type: $type"
else
  echo "✗ Fail"
  
  if [[ "$volume_exists" == false ]]; then
    echo "  ✗ Volume not found with name: $volume_name"
  else
    echo "  ✓ Volume exists"
  fi
  
  if [[ "$size_valid" == false ]]; then
    echo "  ✗ Volume size validation failed"
    echo "    Expected: $volume_size GiB"
    echo "    Got: $size GiB"
  else
    echo "  ✓ Volume size validation passed"
  fi
  
  if [[ "$type_valid" == false ]]; then
    echo "  ✗ Volume type validation failed"
    echo "    Expected: $volume_type"
    echo "    Got: $type"
  else
    echo "  ✓ Volume type validation passed"
  fi
fi
```
