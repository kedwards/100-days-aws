# Day 33: Create a Lambda Function

## Task

The Nautilus DevOps team is embracing serverless architecture by integrating AWS Lambda into their operational tasks. They have decided to deploy a simple Lambda function that will return a custom greeting to demonstrate serverless capabilities effectively. This function is crucial for showcasing rapid deployment and easy scalability features of AWS Lambda to the team.

    Create Lambda Function: Create a Lambda function named nautilus-lambda.

    Runtime: Use the Runtime Python.

    Deploy: The function should print the body Welcome to KKE AWS Labs!.

    Status Code: Ensure the status code is 200.

    IAM Role: Create and use the IAM role named lambda_execution_role.

## Help

```bash
aws iam create-role help
aws iam get-role help
aws lambda create-function help
aws lambda get-function help
aws lambda invoke help
```

<details>
<summary><h2>Solution</h2></summary>

```bash
function_name=nautilus-lambda
function_runtime=python3.9
role_name=lambda_execution_role

# ── Create trust policy document ──────────────────────────────
cat <<EOF > trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      }
    }
  ]
}
EOF

# ── Create Lambda function code ───────────────────────────────
cat << EOF > lambda_function.py
import json

def lambda_handler(event, context):
    return {
        'statusCode': 200,
        'body': json.dumps('Welcome to KKE AWS Labs!')
    }
EOF

zip lambda-function.zip lambda_function.py

# ── Create IAM role ───────────────────────────────────────────
aws iam create-role \
  --role-name $role_name \
  --assume-role-policy-document file://trust-policy.json

lambda_role_arn=$(aws iam list-roles \
  --query "Roles[?RoleName=='lambda_execution_role'].Arn" \
  --output text) && echo "Lambda Arn: $lambda_role_arn"

# ── Create Lambda function ────────────────────────────────────
aws lambda create-function \
  --function-name $function_name \
  --runtime $function_runtime \
  --zip-file fileb://lambda-function.zip \
  --handler lambda_function.lambda_handler \
  --role $lambda_role_arn

aws lambda wait function-active --function-name $function_name

aws lambda get-function --function-name $function_name \
  --query "Configuration.{FunctionName:FunctionName,State:State,Runtime:Runtime}" \
  --output table
```

</details>

<details>
<summary><h2>Validate</h2></summary>

```bash
aws lambda get-function --function-name $function_name \
  --query "{FunctionName:Configuration.FunctionName,Runtime:Configuration.Runtime,Role:Configuration.Role,State:Configuration.State}" \
  --output table

aws lambda invoke --function-name $function_name /tmp/lambda-output.json && cat /tmp/lambda-output.json
```

```bash
prefix=nautilus
function_name=$prefix-lambda
role_name=lambda_execution_role
expected_body='Welcome to KKE AWS Labs!'

# Check Lambda function
read -r fn_name runtime role_arn state <<< "$(aws lambda get-function \
  --function-name $function_name \
  --query "Configuration.[FunctionName,Runtime,Role,State]" \
  --output text 2>/dev/null)"&& echo "Function: $fn_name, Runtime: $runtime, State: $state"

# Check IAM role exists
read -r iam_role_name iam_role_arn <<< "$(aws iam get-role \
  --role-name $role_name \
  --query "Role.[RoleName,Arn]" \
  --output text 2>/dev/null)"&& echo "IAM Role: $iam_role_name"

# Invoke Lambda function and check response
aws lambda invoke --function-name $function_name /tmp/lambda-output.json --output text 2>/dev/null
response=$(cat /tmp/lambda-output.json 2>/dev/null)
status_code=$(echo $response | jq -r '.statusCode' 2>/dev/null)
body=$(echo $response | jq -r '.body' 2>/dev/null | tr -d '"')
echo "Response - Status: $status_code, Body: $body"

# Validation checks
function_exists=false
runtime_valid=false
role_valid=false
state_valid=false
status_code_valid=false
body_valid=false

[[ -n "$fn_name" && "$fn_name" != "None" ]] && function_exists=true
[[ "$runtime" == python* ]] && runtime_valid=true
[[ "$role_arn" == *"$role_name"* ]] && role_valid=true
[[ "$state" == "Active" ]] && state_valid=true
[[ "$status_code" == "200" ]] && status_code_valid=true
[[ "$body" == "$expected_body" ]] && body_valid=true

if [[ "$function_exists" == true ]] && [[ "$runtime_valid" == true ]] && [[ "$role_valid" == true ]] && [[ "$state_valid" == true ]] && [[ "$status_code_valid" == true ]] && [[ "$body_valid" == true ]]; then
  echo "✓ Success"
  echo "  Function name: $fn_name"
  echo "  Runtime: $runtime"
  echo "  IAM Role: $role_name"
  echo "  State: $state"
  echo "  Status code: $status_code"
  echo "  Body: $body"
else
  echo "✗ Fail"
  
  if [[ "$function_exists" == false ]]; then
    echo "  ✗ Lambda function '$function_name' not found"
  else
    echo "  ✓ Lambda function exists"
  fi
  
  if [[ "$runtime_valid" == false ]]; then
    echo "  ✗ Runtime validation failed"
    echo "    Expected: Python runtime"
    echo "    Got: $runtime"
  else
    echo "  ✓ Runtime is Python"
  fi
  
  if [[ "$role_valid" == false ]]; then
    echo "  ✗ IAM role validation failed"
    echo "    Expected role: $role_name"
    echo "    Got: $role_arn"
  else
    echo "  ✓ IAM role is correct"
  fi
  
  if [[ "$state_valid" == false ]]; then
    echo "  ✗ Function state validation failed"
    echo "    Expected: Active"
    echo "    Got: $state"
  else
    echo "  ✓ Function state is Active"
  fi
  
  if [[ "$status_code_valid" == false ]]; then
    echo "  ✗ Status code validation failed"
    echo "    Expected: 200"
    echo "    Got: $status_code"
  else
    echo "  ✓ Status code is 200"
  fi
  
  if [[ "$body_valid" == false ]]; then
    echo "  ✗ Response body validation failed"
    echo "    Expected: $expected_body"
    echo "    Got: $body"
  else
    echo "  ✓ Response body is correct"
  fi
fi
```

</details>
