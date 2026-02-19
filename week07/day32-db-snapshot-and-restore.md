# Day 32: Snapshot and Restoration of an RDS Instance

## Task

The Nautilus Development Team is preparing for a major update to their database infrastructure. To ensure a smooth transition and to safeguard data, the team has requested the DevOps team to take a snapshot of the current RDS instance and restore it to a new instance. This process is crucial for testing and validation purposes before the update is rolled out to the production environment. The snapshot will serve as a backup, and the new instance will be used to verify that the backup process works correctly and that the application can function seamlessly with the restored data.

As a member of the Nautilus DevOps Team, your task is to perform the following:

    Take a Snapshot: Take a snapshot of the devops-rds RDS instance and name it devops-snapshot (please wait devops-rds instance to be in available state).

    Restore the Snapshot: Restore the snapshot to a new RDS instance named devops-snapshot-restore.

    Configure the New RDS Instance: Ensure that the new RDS instance has a class of db.t3.micro.

    Verify the New RDS Instance: The new RDS instance must be in the Available state upon completion of the restoration process.

## Help

```bash
aws rds describe-db-instances help
aws rds create-db-snapshot help
aws rds describe-db-snapshots help
aws rds restore-db-instance-from-db-snapshot help
```

<details>
<summary><h2>Solution</h2></summary>

```bash
db_instance_name=devops-rds
db_snapshot_identifier=devops-snapshot
db_instance_restore_name=devops-snapshot-restore
db_instance_size=db.t3.micro

aws rds create-db-snapshot \
  --db-instance-identifier $db_instance_name \
  --db-snapshot-identifier $db_snapshot_identifier

aws rds wait db-snapshot-available --db-snapshot-identifier $db_snapshot_identifier

aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier $db_instance_restore_name \
  --db-snapshot-identifier $db_snapshot_identifier \
  --db-instance-class $db_instance_size

aws rds wait db-instance-available --db-instance-identifier $db_instance_restore_name
```

</details>

<details>
<summary><h2>Validate</h2></summary>

```bash
aws rds describe-db-snapshots --db-snapshot-identifier $db_snapshot_identifier \
  --query "DBSnapshots[].{DBSnapshotIdentifier:DBSnapshotIdentifier,DBInstanceIdentifier:DBInstanceIdentifier,Status:Status}" \
  --output table

aws rds describe-db-instances --db-instance-identifier $db_instance_restore_name \
  --query "DBInstances[].{DBInstanceIdentifier:DBInstanceIdentifier,DBInstanceClass:DBInstanceClass,DBInstanceStatus:DBInstanceStatus}" \
  --output table
```

```bash
prefix=datacenter
db_instance_name=${prefix}-rds
db_snapshot_identifier=${prefix}-rds-pre-snapshot
db_instance_restore_name=${prefix}-snapshot-restore
db_instance_size=db.t3.micro

# Check snapshot
read -r snapshot_id snapshot_status source_instance <<< "$(aws rds describe-db-snapshots \
  --db-snapshot-identifier $db_snapshot_identifier \
  --query "DBSnapshots[0].[DBSnapshotIdentifier,Status,DBInstanceIdentifier]" \
  --output text 2>/dev/null)"&& echo "Snapshot: $snapshot_id, Status: $snapshot_status, Source: $source_instance"

# Check restored instance
read -r restored_id restored_class restored_status <<< "$(aws rds describe-db-instances \
  --db-instance-identifier $db_instance_restore_name \
  --query "DBInstances[0].[DBInstanceIdentifier,DBInstanceClass,DBInstanceStatus]" \
  --output text 2>/dev/null)"&& echo "Restored Instance: $restored_id, Class: $restored_class, Status: $restored_status"

# Validation checks
snapshot_exists=false
snapshot_available=false
snapshot_source_valid=false
restored_exists=false
restored_class_valid=false
restored_available=false

[[ -n "$snapshot_id" && "$snapshot_id" != "None" ]] && snapshot_exists=true
[[ "$snapshot_status" == "available" ]] && snapshot_available=true
[[ "$source_instance" == "$db_instance_name" ]] && snapshot_source_valid=true
[[ -n "$restored_id" && "$restored_id" != "None" ]] && restored_exists=true
[[ "$restored_class" == "$db_instance_size" ]] && restored_class_valid=true
[[ "$restored_status" == "available" ]] && restored_available=true

if [[ "$snapshot_exists" == true ]] && [[ "$snapshot_available" == true ]] && [[ "$snapshot_source_valid" == true ]] && [[ "$restored_exists" == true ]] && [[ "$restored_class_valid" == true ]] && [[ "$restored_available" == true ]]; then
  echo "✓ Success"
  echo "  Snapshot: $snapshot_id (from $source_instance)"
  echo "  Snapshot status: $snapshot_status"
  echo "  Restored instance: $restored_id"
  echo "  Restored instance class: $restored_class"
  echo "  Restored instance status: $restored_status"
else
  echo "✗ Fail"
  
  if [[ "$snapshot_exists" == false ]]; then
    echo "  ✗ Snapshot '$db_snapshot_identifier' not found"
  else
    echo "  ✓ Snapshot exists"
  fi
  
  if [[ "$snapshot_available" == false ]]; then
    echo "  ✗ Snapshot status validation failed"
    echo "    Expected: available"
    echo "    Got: $snapshot_status"
  else
    echo "  ✓ Snapshot is available"
  fi
  
  if [[ "$snapshot_source_valid" == false ]]; then
    echo "  ✗ Snapshot source validation failed"
    echo "    Expected source: $db_instance_name"
    echo "    Got: $source_instance"
  else
    echo "  ✓ Snapshot source is correct"
  fi
  
  if [[ "$restored_exists" == false ]]; then
    echo "  ✗ Restored instance '$db_instance_restore_name' not found"
  else
    echo "  ✓ Restored instance exists"
  fi
  
  if [[ "$restored_class_valid" == false ]]; then
    echo "  ✗ Restored instance class validation failed"
    echo "    Expected: $db_instance_size"
    echo "    Got: $restored_class"
  else
    echo "  ✓ Restored instance class is correct"
  fi
  
  if [[ "$restored_available" == false ]]; then
    echo "  ✗ Restored instance status validation failed"
    echo "    Expected: available"
    echo "    Got: $restored_status"
  else
    echo "  ✓ Restored instance is available"
  fi
fi
```

</details>
