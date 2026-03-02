# Day 50: Expanding EC2 Instance Storage for Development Needs

## Task

The Nautilus DevOps Team has recently been informed by the Development Team that their EC2 instance is running out of storage space. This instance, crucial for development activities, is named nautilus-ec2 and currently has an attached volume of 8 GiB. To accommodate the increasing data requirements, the storage needs to be expanded to 12 GiB. This change should ensure that the expanded space is immediately available for use within the instance without disrupting ongoing activities.

    Identify Volume: Find the volume attached to the nautilus-ec2 instance.

    Expand Volume: Increase the volume size from 8 GiB to 12 GiB.

    Reflect Changes: Ensure the root (/) partition within the instance reflects the expanded size from 8 GiB to 12 GiB.

    SSH Access: Use the key pair located at /root/nautilus-keypair.pem on the aws-client host to SSH into the EC2 instance.

## Help

```bash
aws ec2 describe-instances help
aws ec2 modify-volume help
aws ec2 describe-volumes help
aws ec2 describe-volumes-modifications help
```

<details>
<summary><h2>Solution</h2></summary>

```bash
prefix="nautilus"
ec2_instance_name="${prefix}-ec2"
expanded_volume_size=12
key_pair_path="/root/${prefix}-keypair.pem"

# Get the volume ID attached to the instance
volume_id=$(aws ec2 describe-instances \
  --filter Name=tag:Name,Values="$ec2_instance_name" \
  --query 'Reservations[0].Instances[0].BlockDeviceMappings[0].Ebs.VolumeId' \
  --output text) && echo "Volume ID: $volume_id"

# Get the public IP for SSH access
public_ip=$(aws ec2 describe-instances \
  --filter Name=tag:Name,Values="$ec2_instance_name" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text) && echo "Public IP: $public_ip"

# Expand the volume from 8 GiB to 12 GiB
aws ec2 modify-volume \
  --volume-id "$volume_id" \
  --size $expanded_volume_size && echo "Volume modification initiated"

# Wait for the volume modification to complete
while true; do
  state=$(aws ec2 describe-volumes-modifications \
    --volume-ids "$volume_id" \
    --query 'VolumesModifications[0].ModificationState' \
    --output text)
  echo "Modification state: $state"
  [[ "$state" == "completed" || "$state" == "optimizing" ]] && break
  sleep 5
done

# SSH into the instance and grow the partition and filesystem
ssh -o StrictHostKeyChecking=no -i "$key_pair_path" ec2-user@"$public_ip" << 'EOF'
  # Grow the partition to use all available space
  sudo growpart /dev/xvda 1

  # Expand the filesystem to fill the partition
  sudo xfs_growfs /

  # Verify the new size
  df -h /
EOF
```

</details>

<details>
<summary><h2>Validate</h2></summary>

```bash
aws ec2 describe-volumes --volume-ids vol-XXXX --output table
aws ec2 describe-instances --filter Name=tag:Name,Values=nautilus-ec2 \
  --query 'Reservations[0].Instances[0].{InstanceId:InstanceId,State:State.Name}' --output table
```

```bash
prefix="nautilus"
ec2_instance_name="${prefix}-ec2"
expanded_volume_size=12
key_pair_path="/root/${prefix}-keypair.pem"

# Get the volume ID
volume_id=$(aws ec2 describe-instances \
  --filter Name=tag:Name,Values="$ec2_instance_name" \
  --query 'Reservations[0].Instances[0].BlockDeviceMappings[0].Ebs.VolumeId' \
  --output text) && echo "Volume ID: $volume_id"

# Check the EBS volume size
volume_size=$(aws ec2 describe-volumes \
  --volume-ids "$volume_id" \
  --query 'Volumes[0].Size' \
  --output text) && echo "Volume Size: $volume_size GiB"

# Get the public IP for SSH
public_ip=$(aws ec2 describe-instances \
  --filter Name=tag:Name,Values="$ec2_instance_name" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text) && echo "Public IP: $public_ip"

# Check the filesystem size inside the instance
fs_size=$(ssh -o StrictHostKeyChecking=no -i "$key_pair_path" ec2-user@"$public_ip" \
  "df -BG / | tail -1 | awk '{print \$2}'" 2>/dev/null) && echo "Filesystem Size: $fs_size"

# Strip the 'G' suffix for comparison
fs_size_num=${fs_size%%G}

# Validation checks
volume_valid=false
fs_valid=false

[[ "$volume_size" == "$expanded_volume_size" ]] && volume_valid=true
[[ "$fs_size_num" -ge "$expanded_volume_size" ]] 2>/dev/null && fs_valid=true

if [[ "$volume_valid" == true ]] && [[ "$fs_valid" == true ]]; then
  echo "✓ Success"
  echo "  Volume: $volume_id ($volume_size GiB)"
  echo "  Filesystem: $fs_size (root partition reflects expanded size)"
else
  echo "✗ Fail"

  if [[ "$volume_valid" == false ]]; then
    echo "  ✗ EBS volume size mismatch"
    echo "    Expected: $expanded_volume_size GiB"
    echo "    Got: $volume_size GiB"
  else
    echo "  ✓ EBS volume size is correct"
  fi

  if [[ "$fs_valid" == false ]]; then
    echo "  ✗ Filesystem does not reflect expanded size"
    echo "    Expected: >= ${expanded_volume_size}G"
    echo "    Got: $fs_size"
  else
    echo "  ✓ Filesystem reflects expanded size"
  fi
fi
```

</details>
