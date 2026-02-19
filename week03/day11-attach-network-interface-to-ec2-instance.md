# Day 11 - Attach Network Interface

## Task

Attach a network interface to an EC2 instance.

## Help

```bash
aws ec2 describe-instances help
aws ec2 describe-network-interfaces help
aws ec2 attach-network-interface help
```

<details>
<summary><h2>Solution</h2></summary>


```bash
instance_name=nautilus-ec2
eni_name=nautilus-eni

instance_id=$(aws ec2 describe-instances \
  --filter "Name=tag:Name,Values=$instance_name" \
  --query "Reservations[].Instances[].InstanceId" \
  --output text) && echo "Instance ID: $instance_id"

eni_id=$(aws ec2 describe-network-interfaces \
  --filters "Name=tag:Name,Values=$eni_name" \
  --query "NetworkInterfaces[].NetworkInterfaceId" \
  --output text) && echo "ENI ID: $eni_id"

aws ec2 attach-network-interface \
  --network-interface-id "$eni_id" \
  --instance-id "$instance_id" \
  --device-index 1
```

</details>

<details>
<summary><h2>Validate</h2></summary>


```bash
aws ec2 describe-network-interfaces \
  --filters "Name=attachment.instance-id,Values=$instance_id" \
  --query "NetworkInterfaces[].{ENI_ID:NetworkInterfaceId,AttachmentId:Attachment.AttachmentId,DeviceIndex:Attachment.DeviceIndex,Status:Attachment.Status}" \
  --output table
```

```bash
read -r attached_eni attachment_status <<< "$(aws ec2 describe-network-interfaces \
  --filters "Name=network-interface-id,Values=$eni_id" \
  --query "NetworkInterfaces[0].[Attachment.InstanceId,Attachment.Status]" \
  --output text)" && echo "Attached to instance: $attached_eni, Status: $attachment_status"

# Check validation
eni_attached=false
attachment_valid=false

[[ "$attached_eni" == "$instance_id" ]] && eni_attached=true
[[ "$attachment_status" == "attached" ]] && attachment_valid=true

if [[ "$eni_attached" == true ]] && [[ "$attachment_valid" == true ]]; then
  echo "✓ Success"
  echo "  ENI ID: $eni_id"
  echo "  Instance ID: $instance_id"
  echo "  Attachment status: $attachment_status"
else
  echo "✗ Fail"
  
  if [[ "$eni_attached" == false ]]; then
    echo "  ✗ ENI not attached to correct instance"
    echo "    Expected instance: $instance_id"
    echo "    Attached to: $attached_eni"
  else
    echo "  ✓ ENI attached to correct instance"
  fi
  
  if [[ "$attachment_valid" == false ]]; then
    echo "  ✗ Attachment status validation failed"
    echo "    Expected: attached"
    echo "    Got: $attachment_status"
  else
    echo "  ✓ Attachment status validation passed"
  fi
fi
```

</details>
