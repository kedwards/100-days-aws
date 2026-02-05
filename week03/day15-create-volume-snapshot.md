# Day 15 - Create Volume Snapshot

## Task

The Nautilus DevOps team has some volumes in different regions in their AWS account. They are going to setup some automated backups so that all important data can be backed up on regular basis. For now they shared some requirements to take a snapshot of one of the volumes they have.

Create a snapshot of an existing volume named xfusion-vol in us-east-1 region.

1) The name of the snapshot must be devops-vol-ss.
2) The description must be devops Snapshot.
3) Make sure the snapshot status is completed before submitting the task.

## Help

```bash
aws ec2 describe-volumes help
aws ec2 create-snapshot help
aws ec2 describe-snapshots help
```

<details>
<summary><h2>Solution</h2></summary>


```bash
volume_name=datacenter-vol
snapshot_name=datacenter-vol-ss
snapshot_description="datacenter Snapshot"

read -r volume_id < <(aws ec2 describe-volumes \
  --filters "Name=tag:Name,Values=$volume_name" \
  --query "Volumes[].VolumeId" \
  --output text) && echo "Volume ID: $volume_id"

aws ec2 create-snapshot \
  --volume-id "$volume_id" \
  --description "$snapshot_description" \
  --tag-specifications "ResourceType=snapshot,Tags=[{Key=Name,Value=$snapshot_name}]"

aws ec2 wait snapshot-completed \
  --filters "Name=tag:Name,Values=$snapshot_name"
```

</details>

<details>
<summary><h2>Validate</h2></summary>


```bash
aws ec2 describe-snapshots --owner-ids self \
  --filters "Name=tag:Name,Values=$snapshot_name" \
  --query "Snapshots[].{SnapshotId:SnapshotId,VolumeId:VolumeId,Description:Description,Name:Tags[?Key=='Name'].Value|[0]}" \
  --output table
```

```bash
read -r snapshot_id snap_volume_id snap_description state < <(aws ec2 describe-snapshots --owner-ids self \
  --filters "Name=tag:Name,Values=$snapshot_name" \
  --query "Snapshots[0].[SnapshotId,VolumeId,Description,State]" \
  --output text) && echo "Snapshot ID: $snapshot_id, Volume: $snap_volume_id, Description: $snap_description, State: $state"

snapshot_exists=false
description_valid=false
volume_valid=false
state_valid=false

[[ -n "$snapshot_id" && "$snapshot_id" != "None" ]] && snapshot_exists=true
[[ "$snap_description" == "$snapshot_description" ]] && description_valid=true
[[ -n "$snap_volume_id" && "$snap_volume_id" != "None" ]] && volume_valid=true
[[ "$state" == "completed" ]] && state_valid=true

if [[ "$snapshot_exists" == true ]] && [[ "$volume_valid" == true ]] && [[ "$state_valid" == true ]] && [[ "$description_valid" == true ]]; then
  echo "✓ Success"
  echo "  Snapshot ID: $snapshot_id"
  echo "  Description: $snap_description"
  echo "  Volume ID: $snap_volume_id"
  echo "  State: $state"
else
  echo "✗ Fail"
  
  if [[ "$snapshot_exists" == false ]]; then
    echo "  ✗ Snapshot not found"
  else
    echo "  ✓ Snapshot exists"
  fi

  if [[ "$description_valid" == false ]]; then
    echo "  ✗ Snapshot description validation failed"
    echo "    Expected: $snapshot_description"
    echo "    Got: $snap_description"
  else
    echo "  ✓ Snapshot description validation passed"
  fi
  
  if [[ "$volume_valid" == false ]]; then
    echo "  ✗ Snapshot volume validation failed"
    echo "    Expected: $volume_id"
    echo "    Got: $snap_volume_id"
  else
    echo "  ✓ Snapshot volume validation passed"
  fi
  
  if [[ "$state_valid" == false ]]; then
    echo "  ✗ Snapshot state validation failed"
    echo "    Expected: completed"
    echo "    Got: $state"
  else
    echo "  ✓ Snapshot state validation passed"
  fi
fi
```

</details>
