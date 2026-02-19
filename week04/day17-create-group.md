# Day 17 - Create IAM Group

## Task

The Nautilus DevOps team has been creating a couple of services on AWS cloud. They have been breaking down the migration into smaller tasks, allowing for better control, risk mitigation, and optimization of resources throughout the migration process. Recently they came up with requirements mentioned below.

Create an IAM group named iamgroup_siva.

## Help

```bash
aws iam create-group help
aws iam list-groups help
aws iam get-group help
```

<details>
<summary><h2>Solution</h2></summary>


```bash
group_name=iamgroup_siva

aws iam create-group --group-name "$group_name"
```

</details>

<details>
<summary><h2>Validate</h2></summary>


```bash
aws iam get-group --group-name "$group_name" \
  --query "Group.{GroupName:GroupName,GroupId:GroupId,CreateDate:CreateDate}" \
  --output table
```

```bash
read -r retrieved_groupname group_id <<< "$(aws iam get-group --group-name "$group_name" \
  --query "Group.[GroupName,GroupId]" \
  --output text)" && echo "Group name: $retrieved_groupname, Group ID: $group_id"

# Check validation
group_exists=false
name_valid=false

[[ -n "$group_id" && "$group_id" != "None" ]] && group_exists=true
[[ "$retrieved_groupname" == "$group_name" ]] && name_valid=true

if [[ "$group_exists" == true ]] && [[ "$name_valid" == true ]]; then
  echo "✓ Success"
  echo "  Group name: $retrieved_groupname"
  echo "  Group ID: $group_id"
else
  echo "✗ Fail"
  
  if [[ "$group_exists" == false ]]; then
    echo "  ✗ IAM group not found"
  else
    echo "  ✓ IAM group exists"
  fi
  
  if [[ "$name_valid" == false ]]; then
    echo "  ✗ Group name validation failed"
    echo "    Expected: $group_name"
    echo "    Got: $retrieved_groupname"
  else
    echo "  ✓ Group name validation passed"
  fi
fi
```

</details>
