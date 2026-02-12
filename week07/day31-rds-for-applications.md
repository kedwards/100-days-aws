# Day XX - Task title

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
aws rds create-db-subnet-group --db-subnet-group-name 'default-vpc-07f9891b00f0ca2c0' --subnet-ids 'subnet-0b7bd3c25a6b45f12' 'subnet-068f65c836c137af8' 'subnet-0b9cad2436a27fffd' 'subnet-0081136f7e3741c55' 'subnet-0126648fd4f1865bb' 'subnet-09361e750f470a547' --db-subnet-group-description 'Created from the RDS Management Console' 
aws rds create-db-instance --engine 'mysql' --engine-version '8.4.7' --engine-lifecycle-support 'open-source-rds-extended-support-disabled' --db-instance-identifier 'xfusion-db' --master-username 'admin' --db-instance-class 'db.t3.micro' --db-subnet-group-name 'default-vpc-07f9891b00f0ca2c0' --db-name '' --character-set-name 'null' --nchar-character-set-name 'null' --vpc-security-group-ids 'sg-0560a2153f703983e' --db-security-groups 'null' --availability-zone 'null' --port '3306' --storage-type 'gp2' --allocated-storage '20' --iops 'null' --storage-throughput 'null' --kms-key-id 'null' --preferred-maintenance-window 'null' --preferred-backup-window 'null' --backup-retention-period '1' --domain 'null' --domain-iam-role-name 'null' --domain-fqdn 'null' --domain-ou 'null' --domain-auth-secret-arn 'null' --domain-dns-ips 'null' --db-parameter-group-name 'default.mysql8.4' --option-group-name 'default:mysql-8-4' --timezone 'null' --processor-features 'null' --max-allocated-storage '50' --network-type 'null' --backup-target 'null' --ca-certificate-identifier 'rds-ca-rsa2048-g1' --master-user-password 'password'


tag_value=value

read -r aws_value < <(aws command describe-something \
  --filter "Name=tag:Name,Values=$tag_value" \
  --query "Returned[].AwsValue" \
  --output text) && echo "AWS Value: $aws_value"
```

</details>

<details>
<summary><h2>Validate</h2></summary>

```bash
aws ec2 describe-omething--filters "Name=tag:Name,Values=$tag_vale" \
  --query "Returned[?KeyName=='"$key_name"'].{Name:KeyName,Type:KeyType}" \
  --output table
```

```bash
key_name=keyName
tag_value=value

read -r aws_value < <(aws command describe-something \
  --filter "Name=tag:Name,Values=$tag_value" \
  --query "Returned[].AwsValue" \
  --output text) && echo "AWS Value: $aws_value"

name_valid=false

[[ "$aws_value" == "$key_name" ]] && name_valid=true

if [[ "$name_valid" == true ]]; then
  echo "✓ Success"
  echo "  Key name: $aws_value"
else
  echo "✗ Fail"
  
  if [[ "$name_valid" == false ]]; then
    echo "  ✗ Key name validation failed"
    echo "    Expected: $key_name"
    echo "    Got: $aws_value"
  else
    echo "  ✓ Key name validation passed"
  fi
fi
```

</details>
