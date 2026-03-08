# Day 42: Building and Managing NoSQL Databases with AWS DynamoDB

## Task

The Nautilus DevOps team is developing a simple 'To-Do' application using DynamoDB to store and manage tasks efficiently. The team needs to create a DynamoDB table to hold tasks, each identified by a unique task ID. Each task will have a description and a status, which indicates the progress of the task (e.g., 'completed' or 'in-progress').

Your task is to:

    Create a DynamoDB table named devops-tasks with a primary key called taskId (string).
    Insert the following tasks into the table:
        Task 1: taskId: '1', description: 'Learn DynamoDB', status: 'completed'
        Task 2: taskId: '2', description: 'Build To-Do App', status: 'in-progress'
    Verify that Task 1 has a status of 'completed' and Task 2 has a status of 'in-progress'.

Ensure the DynamoDB table is created successfully and that both tasks are inserted correctly with the appropriate statuses.

## Help

```bash
aws dynamodb create-table help
aws dynamodb describe-table help
aws dynamodb put-item help
aws dynamodb get-item help
aws dynamodb scan help
aws dynamodb wait help
```

<details>
<summary><h2>Solution</h2></summary>

```bash
prefix=devops
table_name="$prefix-tasks"

# ── Create DynamoDB table ────────────────────────────────────
aws dynamodb create-table \
  --table-name "$table_name" \
  --attribute-definitions AttributeName=taskId,AttributeType=S \
  --key-schema AttributeName=taskId,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST && echo "Creating table: $table_name"

aws dynamodb wait table-exists

aws dynamodb describe-table --table-name "$table_name" \
  --query "Table.{TableName:TableName,Status:TableStatus,KeySchema:KeySchema[0].AttributeName}" \
  --output table

# ── Insert tasks ─────────────────────────────────────────────
aws dynamodb put-item \
  --table-name "$table_name" \
  --item '{
    "taskId": {"S": "1"},
    "description": {"S": "Learn DynamoDB"},
    "status": {"S": "completed"}
  }' && echo "Inserted Task 1"

aws dynamodb put-item \
  --table-name "$table_name" \
  --item '{
    "taskId": {"S": "2"},
    "description": {"S": "Build To-Do App"},
    "status": {"S": "in-progress"}
  }' && echo "Inserted Task 2"

# ── Verify tasks ─────────────────────────────────────────────
echo "Task 1:"
aws dynamodb get-item \
  --table-name "$table_name" \
  --key '{"taskId": {"S": "1"}}' \
  --query "Item.{taskId:taskId.S,description:description.S,status:status.S}" \
  --output table

echo "Task 2:"
aws dynamodb get-item \
  --table-name "$table_name" \
  --key '{"taskId": {"S": "2"}}' \
  --query "Item.{taskId:taskId.S,description:description.S,status:status.S}" \
  --output table
```

</details>

<details>
<summary><h2>Validate</h2></summary>

```bash
aws dynamodb describe-table --table-name devops-tasks --output table
aws dynamodb scan --table-name devops-tasks --output table
```

```bash
table_name=devops-tasks

# Check table exists and is active
read -r table_status key_schema <<< "$(aws dynamodb describe-table \
  --table-name "$table_name" \
  --query "Table.[TableStatus,KeySchema[0].AttributeName]" \
  --output text 2>/dev/null)"&& echo "Table: $table_name, Status: $table_status, Key: $key_schema"

# Get Task 1 status
task1_status=$(aws dynamodb get-item \
  --table-name "$table_name" \
  --key '{"taskId": {"S": "1"}}' \
  --query "Item.status.S" \
  --output text 2>/dev/null) && echo "Task 1 status: $task1_status"

# Get Task 2 status
task2_status=$(aws dynamodb get-item \
  --table-name "$table_name" \
  --key '{"taskId": {"S": "2"}}' \
  --query "Item.status.S" \
  --output text 2>/dev/null) && echo "Task 2 status: $task2_status"

# Validation checks
table_active=false
key_valid=false
task1_valid=false
task2_valid=false

[[ "$table_status" == "ACTIVE" ]] && table_active=true
[[ "$key_schema" == "taskId" ]] && key_valid=true
[[ "$task1_status" == "completed" ]] && task1_valid=true
[[ "$task2_status" == "in-progress" ]] && task2_valid=true

if [[ "$table_active" == true ]] && [[ "$key_valid" == true ]] && [[ "$task1_valid" == true ]] && [[ "$task2_valid" == true ]]; then
  echo "✓ Success"
  echo "  Table: $table_name (ACTIVE)"
  echo "  Primary Key: $key_schema (string)"
  echo "  Task 1 status: $task1_status"
  echo "  Task 2 status: $task2_status"
else
  echo "✗ Fail"
  
  if [[ "$table_active" == false ]]; then
    echo "  ✗ Table not found or not active"
    echo "    Expected: ACTIVE"
    echo "    Got: $table_status"
  else
    echo "  ✓ Table is active"
  fi
  
  if [[ "$key_valid" == false ]]; then
    echo "  ✗ Primary key incorrect"
    echo "    Expected: taskId"
    echo "    Got: $key_schema"
  else
    echo "  ✓ Primary key is taskId"
  fi
  
  if [[ "$task1_valid" == false ]]; then
    echo "  ✗ Task 1 status incorrect"
    echo "    Expected: completed"
    echo "    Got: $task1_status"
  else
    echo "  ✓ Task 1 status is completed"
  fi
  
  if [[ "$task2_valid" == false ]]; then
    echo "  ✗ Task 2 status incorrect"
    echo "    Expected: in-progress"
    echo "    Got: $task2_status"
  else
    echo "  ✓ Task 2 status is in-progress"
  fi
fi
```

</details>
