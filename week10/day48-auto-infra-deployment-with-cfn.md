# Day 48: Automating Infrastructure Deployment with AWS CloudFormation

## Task

The Nautilus DevOps team needs to implement a Lambda function using a CloudFormation stack. Create a CloudFormation template named /root/devops-lambda.yml on the AWS client host and configure it to create the following components. The stack name must be devops-lambda-app.

    Create a Lambda function named devops-lambda.
    Use the Runtime Python.
    The function should print the body Welcome to KKE AWS Labs!.
    Ensure the status code is 200.
    Create and use the IAM role named lambda_execution_role.

## Help

```bash
aws cloudformation create-stack help
aws cloudformation describe-stacks help
aws cloudformation wait help
aws lambda get-function help
aws lambda invoke help
aws iam get-role help
```

<details>
<summary><h2>Solution</h2></summary>

```bash
prefix="devops"
stack_name="$prefix-lambda-app"
lambda_function_name="$prefix-lambda"
lambda_role_name="lambda_execution_role"

# Create the CloudFormation template
cat <<'CFEOF' > /root/devops-lambda.yml
AWSTemplateFormatVersion: '2010-09-09'
Description: Deploy a Lambda function that returns Welcome to KKE AWS Labs!

Resources:
  LambdaExecutionRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: lambda_execution_role
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: lambda.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

  DevOpsLambdaFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: devops-lambda
      Runtime: python3.11
      Handler: index.lambda_handler
      Role: !GetAtt LambdaExecutionRole.Arn
      Timeout: 30
      Code:
        ZipFile: |
          import json

          def lambda_handler(event, context):
              return {
                  'statusCode': 200,
                  'body': 'Welcome to KKE AWS Labs!'
              }

Outputs:
  LambdaFunctionArn:
    Value: !GetAtt DevOpsLambdaFunction.Arn
  LambdaRoleArn:
    Value: !GetAtt LambdaExecutionRole.Arn
CFEOF

# Deploy the CloudFormation stack
aws cloudformation create-stack \
  --stack-name "$stack_name" \
  --template-body file:///root/devops-lambda.yml \
  --capabilities CAPABILITY_NAMED_IAM && echo "Creating stack: $stack_name"

# Wait for stack to complete
echo "Waiting for stack creation to complete..."
aws cloudformation wait stack-create-complete \
  --stack-name "$stack_name" && echo "Stack created successfully"

# Invoke the Lambda function to verify
aws lambda invoke \
  --function-name "$lambda_function_name" \
  --log-type Tail \
  --query "StatusCode" \
  /tmp/lambda-output.json && echo "Lambda invoked successfully"

# Show Lambda output
cat /tmp/lambda-output.json | python3 -m json.tool
```

</details>

<details>
<summary><h2>Validate</h2></summary>

```bash
aws cloudformation describe-stacks --stack-name devops-lambda-app --output table
aws lambda get-function --function-name devops-lambda --output table
aws iam get-role --role-name lambda_execution_role --output table
```

```bash
prefix="devops"
stack_name="$prefix-lambda-app"
lambda_function_name="$prefix-lambda"
lambda_role_name="lambda_execution_role"

# Check CloudFormation stack status
stack_status=$(aws cloudformation describe-stacks \
  --stack-name "$stack_name" \
  --query "Stacks[0].StackStatus" \
  --output text 2>/dev/null) && echo "Stack Status: $stack_status"

# Check Lambda function exists, is active, and has correct runtime
read -r lambda_state lambda_runtime <<< "$(aws lambda get-function \
  --function-name "$lambda_function_name" \
  --query "Configuration.[State,Runtime]" \
  --output text 2>/dev/null)" && echo "Lambda: $lambda_state, Runtime: $lambda_runtime"

# Check IAM role exists
role_arn=$(aws iam get-role \
  --role-name "$lambda_role_name" \
  --query "Role.Arn" \
  --output text 2>/dev/null) && echo "Role ARN: $role_arn"

# Check Lambda has correct role
lambda_role=$(aws lambda get-function \
  --function-name "$lambda_function_name" \
  --query "Configuration.Role" \
  --output text 2>/dev/null) && echo "Lambda Role: $lambda_role"

# Invoke Lambda and check response body and status code
aws lambda invoke \
  --function-name "$lambda_function_name" \
  /tmp/lambda-validate.json > /tmp/lambda-invoke-result.json 2>/dev/null

invoke_status=$(python3 -c "import json; print(json.load(open('/tmp/lambda-invoke-result.json'))['StatusCode'])" 2>/dev/null) && echo "Invoke StatusCode: $invoke_status"
response_body=$(python3 -c "import json; r=json.load(open('/tmp/lambda-validate.json')); print(r.get('body',''))" 2>/dev/null) && echo "Response Body: $response_body"
response_code=$(python3 -c "import json; r=json.load(open('/tmp/lambda-validate.json')); print(r.get('statusCode',''))" 2>/dev/null) && echo "Response statusCode: $response_code"

# Validation checks
stack_valid=false
lambda_valid=false
runtime_valid=false
role_valid=false
role_attached_valid=false
body_valid=false
status_code_valid=false

[[ "$stack_status" == "CREATE_COMPLETE" ]] && stack_valid=true
[[ "$lambda_state" == "Active" ]] && lambda_valid=true
[[ "$lambda_runtime" == python* ]] && runtime_valid=true
[[ -n "$role_arn" && "$role_arn" != "None" ]] && role_valid=true
[[ "$lambda_role" == *"$lambda_role_name"* ]] && role_attached_valid=true
[[ "$response_body" == "Welcome to KKE AWS Labs!" ]] && body_valid=true
[[ "$response_code" == "200" ]] && status_code_valid=true

if [[ "$stack_valid" == true ]] && [[ "$lambda_valid" == true ]] && [[ "$runtime_valid" == true ]] && [[ "$role_valid" == true ]] && [[ "$role_attached_valid" == true ]] && [[ "$body_valid" == true ]] && [[ "$status_code_valid" == true ]]; then
  echo "✓ Success"
  echo "  Stack: $stack_name ($stack_status)"
  echo "  Lambda Function: $lambda_function_name ($lambda_state)"
  echo "  Runtime: $lambda_runtime"
  echo "  IAM Role: $lambda_role_name"
  echo "  Response Body: $response_body"
  echo "  Status Code: $response_code"
else
  echo "✗ Fail"

  if [[ "$stack_valid" == false ]]; then
    echo "  ✗ CloudFormation stack not complete"
    echo "    Expected: CREATE_COMPLETE"
    echo "    Got: $stack_status"
  else
    echo "  ✓ CloudFormation stack is complete"
  fi

  if [[ "$lambda_valid" == false ]]; then
    echo "  ✗ Lambda function not found or not active"
    echo "    Expected: $lambda_function_name"
    echo "    State: $lambda_state"
  else
    echo "  ✓ Lambda function is active"
  fi

  if [[ "$runtime_valid" == false ]]; then
    echo "  ✗ Lambda runtime is not Python"
    echo "    Expected: python*"
    echo "    Got: $lambda_runtime"
  else
    echo "  ✓ Lambda runtime is Python ($lambda_runtime)"
  fi

  if [[ "$role_valid" == false ]]; then
    echo "  ✗ IAM role not found"
    echo "    Expected: $lambda_role_name"
  else
    echo "  ✓ IAM role exists"
  fi

  if [[ "$role_attached_valid" == false ]]; then
    echo "  ✗ Lambda function not using correct role"
    echo "    Expected role: $lambda_role_name"
    echo "    Got: $lambda_role"
  else
    echo "  ✓ Lambda function using correct role"
  fi

  if [[ "$body_valid" == false ]]; then
    echo "  ✗ Response body mismatch"
    echo "    Expected: Welcome to KKE AWS Labs!"
    echo "    Got: $response_body"
  else
    echo "  ✓ Response body is correct"
  fi

  if [[ "$status_code_valid" == false ]]; then
    echo "  ✗ Status code mismatch"
    echo "    Expected: 200"
    echo "    Got: $response_code"
  else
    echo "  ✓ Status code is 200"
  fi
fi
```

</details>
