# Day 31: Provision Private RDS Instance for Application Development

## Task

The Nautilus Development Team is working on a new application feature that requires a reliable and scalable database solution. To facilitate development and testing, they need a new private RDS instance. This instance will be used to store critical application data and must be provisioned using the AWS free tier to minimize costs during the initial development phase. The team has chosen MySQL as the database engine due to its compatibility with their existing systems. The DevOps team has been tasked with setting up this RDS instance, ensuring that it is correctly configured and available for use by the development team.

As a member of the Nautilus DevOps Team, your task is to perform the following:

1. Provision a Private RDS Instance: Create a new private RDS instance named xfusion-rds using a sandbox template, further it must be a db.t3.micro type instance.
2. Engine Configuration: Use the MySQL engine with version 8.4.x.
3. Enable Storage Autoscaling: Enable storage autoscaling and set the threshold value to 50GB. Keep the rest of the configurations as default.
4. Instance Availability: Ensure the instance is in the available state before submitting this task.ask.

## Help

```bash
aws rds create-db-subnet-group help
aws rds create-db-instance help
aws rds describe-db-instances help
aws ec2 describe-subnets help
aws ec2 describe-security-groups help
```

<details>
<summary><h2>Solution</h2></summary>

```bash
db_name=xfusion-rds
db_engine=mysql
db_engine_version=8.4
db_instance_class=db.t3.micro
db_max_storage=50

aws rds create-db-instance \
  --engine $db_engine \
  --engine-version $db_engine_version \
  --db-instance-identifier $db_name \
  --db-instance-class $db_instance_class \
  --master-username admin \
  --master-user-password password \
  --allocated-storage 20 \
  --max-allocated-storage $db_max_storage


aws rds wait db-instance-available --db-instance-identifier $db_name

aws rds describe-db-instances --db-instance-identifier $db_name --query "DBInstances[].DBInstanceStatus"
```

</details>

<details>
<summary><h2>Validate</h2></summary>

```bash
aws rds describe-db-instances --db-instance-identifier $db_name \
  --query "DBInstances[].{DBInstanceIdentifier:DBInstanceIdentifier,Engine:Engine,EngineVersion:EngineVersion,DBInstanceClass:DBInstanceClass,DBInstanceStatus:DBInstanceStatus,MaxAllocatedStorage:MaxAllocatedStorage}" \
  --output table
```

```bash
db_name=xfusion-rds
db_engine=mysql
db_instance_class=db.t3.micro
db_max_storage=50

read -r instance_id engine engine_version instance_class status max_storage < <(aws rds describe-db-instances \
  --db-instance-identifier $db_name \
  --query "DBInstances[0].[DBInstanceIdentifier,Engine,EngineVersion,DBInstanceClass,DBInstanceStatus,MaxAllocatedStorage]" \
  --output text 2>/dev/null) && echo "Instance: $instance_id, Engine: $engine $engine_version, Class: $instance_class, Status: $status, Max Storage: $max_storage GB"

# Validation checks
instance_exists=false
engine_valid=false
class_valid=false
status_valid=false
autoscaling_valid=false

[[ -n "$instance_id" && "$instance_id" != "None" ]] && instance_exists=true
[[ "$engine" == "$db_engine" ]] && engine_valid=true
[[ "$instance_class" == "$db_instance_class" ]] && class_valid=true
[[ "$status" == "available" ]] && status_valid=true
[[ "$max_storage" == "$db_max_storage" ]] && autoscaling_valid=true

if [[ "$instance_exists" == true ]] && [[ "$engine_valid" == true ]] && [[ "$class_valid" == true ]] && [[ "$status_valid" == true ]] && [[ "$autoscaling_valid" == true ]]; then
  echo "✓ Success"
  echo "  DB Instance: $instance_id"
  echo "  Engine: $engine $engine_version"
  echo "  Instance class: $instance_class"
  echo "  Status: $status"
  echo "  Max storage (autoscaling threshold): $max_storage GB"
else
  echo "✗ Fail"
  
  if [[ "$instance_exists" == false ]]; then
    echo "  ✗ RDS instance '$db_name' not found"
  else
    echo "  ✓ RDS instance exists"
  fi
  
  if [[ "$engine_valid" == false ]]; then
    echo "  ✗ Engine validation failed"
    echo "    Expected: $db_engine"
    echo "    Got: $engine"
  else
    echo "  ✓ Engine validation passed"
  fi
  
  if [[ "$class_valid" == false ]]; then
    echo "  ✗ Instance class validation failed"
    echo "    Expected: $db_instance_class"
    echo "    Got: $instance_class"
  else
    echo "  ✓ Instance class validation passed"
  fi
  
  if [[ "$status_valid" == false ]]; then
    echo "  ✗ Instance status validation failed"
    echo "    Expected: available"
    echo "    Got: $status"
  else
    echo "  ✓ Instance status validation passed"
  fi
  
  if [[ "$autoscaling_valid" == false ]]; then
    echo "  ✗ Storage autoscaling threshold validation failed"
    echo "    Expected max storage: $db_max_storage GB"
    echo "    Got: $max_storage GB"
  else
    echo "  ✓ Storage autoscaling validation passed"
  fi
fi
```

</details>
