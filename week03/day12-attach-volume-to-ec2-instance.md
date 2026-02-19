# Day 12 - Attach Volume

## Task

An instance named xfusion-ec2 and a volume named xfusion-volume already exists in us-east-1 region. Attach the xfusion-volume volume to the xfusion-ec2 instance, make sure to set the device name to /dev/sdb while attaching the volume.

## Help

```bash
aws ec2 describe-volumes help
aws ec2 describe-instances help
aws ec2 attach-volume help
```

<details>
<summary><h2>Solution</h2></summary>


```bash
instance_name=xfusion-ec2
volume_name=xfusion-volume
device_name=/dev/sdb

read -r instance_id az <<< "$(aws ec2 describe-instances \
  --filter "Name=tag:Name,Values=$instance_name" \
  --query "Reservations[].Instances[].[InstanceId,Placement.AvailabilityZone]" \
  --output text)" && echo "Instance ID: $instance_id, AZ: $az"

volume_id=$(aws ec2 describe-volumes \
  --filters "Name=tag:Name,Values=$volume_name" "Name=availability-zone,Values=$az" \
  --query "Volumes[].VolumeId" \
  --output text) && echo "Volume ID: $volume_id"

aws ec2 attach-volume \
  --volume-id "$volume_id" \
  --instance-id "$instance_id" \
  --device "$device_name"
```

</details>

<details>
<summary><h2>Validate</h2></summary>


```bash
aws ec2 describe-volumes --filters "Name=tag:Name,Values=$volume_name" \
  --query "Volumes[].{VolumeId:VolumeId,InstanceId:Attachments[0].InstanceId,Device:Attachments[0].Device,State:Attachments[0].State}" \
  --output table
```

```bash
read -r volume_id attached_instance device state <<< "$(aws ec2 describe-volumes \
  --filters "Name=tag:Name,Values=$volume_name" \
  --query "Volumes[0].[VolumeId,Attachments[0].InstanceId,Attachments[0].Device,Attachments[0].State]" \
  --output text)" && echo "Volume ID: $volume_id, Instance: $attached_instance, Device: $device, State: $state"

volume_exists=false
attachment_valid=false
state_valid=false

[[ -n "$volume_id" && "$volume_id" != "None" ]] && volume_exists=true
[[ "$attached_instance" == "$instance_id" ]] && attachment_valid=true
[[ "$state" == "attached" ]] && state_valid=true

if [[ "$volume_exists" == true ]] && [[ "$attachment_valid" == true ]] && [[ "$state_valid" == true ]]; then
  echo "✓ Success"
  echo "  Volume ID: $volume_id"
  echo "  Instance ID: $attached_instance"
  echo "  Device: $device"
  echo "  State: $state"
else
  echo "✗ Fail"
  
  if [[ "$volume_exists" == false ]]; then
    echo "  ✗ Volume not found"
  else
    echo "  ✓ Volume exists"
  fi
  
  if [[ "$attachment_valid" == false ]]; then
    echo "  ✗ Volume attachment validation failed"
    echo "    Expected instance: $instance_id"
    echo "    Attached to: $attached_instance"
  else
    echo "  ✓ Volume attached to correct instance"
  fi
  
  if [[ "$state_valid" == false ]]; then
    echo "  ✗ Attachment state validation failed"
    echo "    Expected: attached"
    echo "    Got: $state"
  else
    echo "  ✓ Attachment state validation passed"
  fi
fi
```

</details>
