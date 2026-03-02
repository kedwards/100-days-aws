# Day 47: Integrating AWS SQS and SNS for Reliable Messaging

## Task

The Nautilus DevOps team needs to implement priority queuing using Amazon SQS and SNS. The goal is to create a system where messages with different priorities are handled accordingly. You are required to use AWS CloudFormation to deploy the necessary resources in your AWS account. The CloudFormation template should be created on the AWS client host at /root/nautilus-priority-stack.yml, the stack name must be nautilus-priority-stack and it should create the following resources:

    Two SQS queues named nautilus-High-Priority-Queue and nautilus-Low-Priority-Queue.
    An SNS topic named nautilus-Priority-Queues-Topic.
    A Lambda function named nautilus-priorities-queue-function that will consume messages from the SQS queues. The Lambda function code is provided in /root/index.py on the AWS client host.
    An IAM role named lambda_execution_role that provides the necessary permissions for the Lambda function to interact with SQS and SNS.

Once the stack is deployed, to test the same you can publish messages to the SNS topic, invoke the Lambda function and observe the order in which they are processed by the Lambda function. The high-priority message must be processed first.

## Help

```bash
aws cloudformation create-stack help
aws cloudformation describe-stacks help
aws cloudformation wait help
aws sqs list-queues help
aws sqs get-queue-url help
aws sqs get-queue-attributes help
aws sns list-topics help
aws sns list-subscriptions-by-topic help
aws sns publish help
aws lambda get-function help
aws lambda invoke help
aws iam get-role help
```

<details>
<summary><h2>Solution</h2></summary>

```bash
prefix=nautilus
stack_name="$prefix-priority-stack"
high_priority_queue="$prefix-High-Priority-Queue"
low_priority_queue="$prefix-Low-Priority-Queue"
sns_topic_name="$prefix-Priority-Queues-Topic"
lambda_function_name="$prefix-priorities-queue-function"
lambda_role_name="lambda_execution_role"

# Create the Lambda function code at /root/index.py
cat <<'PYEOF' > /root/index.py
import boto3
import os

sqs = boto3.client('sqs')

def delete_message(queue_url, receipt_handle, message):
    sqs.delete_message(QueueUrl=queue_url, ReceiptHandle=receipt_handle)
    return "Message '" + message + "' deleted"

def poll_messages(queue_url):
    response = sqs.receive_message(
        QueueUrl=queue_url,
        AttributeNames=[],
        MaxNumberOfMessages=1,
        MessageAttributeNames=['All'],
        WaitTimeSeconds=3
    )
    if "Messages" in response:
        receipt_handle = response['Messages'][0]['ReceiptHandle']
        message = response['Messages'][0]['Body']
        return delete_message(queue_url, receipt_handle, message)
    else:
        return "No more messages to poll"

def lambda_handler(event, context):
    response = poll_messages(os.environ['high_priority_queue'])
    if response == "No more messages to poll":
        response = poll_messages(os.environ['low_priority_queue'])
    return response
PYEOF

# Create the CloudFormation template
cat <<'CFEOF' > /root/nautilus-priority-stack.yml
AWSTemplateFormatVersion: '2010-09-09'
Description: Priority Queuing with SQS, SNS, and Lambda

Resources:
  HighPriorityQueue:
    Type: AWS::SQS::Queue
    Properties:
      QueueName: nautilus-High-Priority-Queue

  LowPriorityQueue:
    Type: AWS::SQS::Queue
    Properties:
      QueueName: nautilus-Low-Priority-Queue

  PriorityQueuesTopic:
    Type: AWS::SNS::Topic
    Properties:
      TopicName: nautilus-Priority-Queues-Topic

  HighPriorityQueuePolicy:
    Type: AWS::SQS::QueuePolicy
    Properties:
      Queues:
        - !Ref HighPriorityQueue
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: sns.amazonaws.com
            Action: sqs:SendMessage
            Resource: !GetAtt HighPriorityQueue.Arn
            Condition:
              ArnEquals:
                aws:SourceArn: !Ref PriorityQueuesTopic

  LowPriorityQueuePolicy:
    Type: AWS::SQS::QueuePolicy
    Properties:
      Queues:
        - !Ref LowPriorityQueue
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: sns.amazonaws.com
            Action: sqs:SendMessage
            Resource: !GetAtt LowPriorityQueue.Arn
            Condition:
              ArnEquals:
                aws:SourceArn: !Ref PriorityQueuesTopic

  HighPrioritySubscription:
    Type: AWS::SNS::Subscription
    Properties:
      TopicArn: !Ref PriorityQueuesTopic
      Protocol: sqs
      Endpoint: !GetAtt HighPriorityQueue.Arn
      FilterPolicy:
        priority:
          - high
      RawMessageDelivery: true

  LowPrioritySubscription:
    Type: AWS::SNS::Subscription
    Properties:
      TopicArn: !Ref PriorityQueuesTopic
      Protocol: sqs
      Endpoint: !GetAtt LowPriorityQueue.Arn
      FilterPolicy:
        priority:
          - low
      RawMessageDelivery: true

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
        - arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole

  PrioritiesQueueFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: nautilus-priorities-queue-function
      Runtime: python3.11
      Handler: index.lambda_handler
      Role: !GetAtt LambdaExecutionRole.Arn
      Timeout: 30
      Environment:
        Variables:
          high_priority_queue: !Ref HighPriorityQueue
          low_priority_queue: !Ref LowPriorityQueue
      Code:
        ZipFile: |
          import boto3
          import os

          sqs = boto3.client('sqs')

          def delete_message(queue_url, receipt_handle, message):
              sqs.delete_message(QueueUrl=queue_url, ReceiptHandle=receipt_handle)
              return "Message '" + message + "' deleted"

          def poll_messages(queue_url):
              response = sqs.receive_message(
                  QueueUrl=queue_url,
                  AttributeNames=[],
                  MaxNumberOfMessages=1,
                  MessageAttributeNames=['All'],
                  WaitTimeSeconds=3
              )
              if "Messages" in response:
                  receipt_handle = response['Messages'][0]['ReceiptHandle']
                  message = response['Messages'][0]['Body']
                  return delete_message(queue_url, receipt_handle, message)
              else:
                  return "No more messages to poll"

          def lambda_handler(event, context):
              response = poll_messages(os.environ['high_priority_queue'])
              if response == "No more messages to poll":
                  response = poll_messages(os.environ['low_priority_queue'])
              return response

Outputs:
  HighPriorityQueueUrl:
    Value: !Ref HighPriorityQueue
  LowPriorityQueueUrl:
    Value: !Ref LowPriorityQueue
  SNSTopicArn:
    Value: !Ref PriorityQueuesTopic
  LambdaFunctionArn:
    Value: !GetAtt PrioritiesQueueFunction.Arn
CFEOF

# Deploy the CloudFormation stack
aws cloudformation create-stack \
  --stack-name "$stack_name" \
  --template-body file:///root/nautilus-priority-stack.yml \
  --capabilities CAPABILITY_NAMED_IAM && echo "Creating stack: $stack_name"

# Wait for stack to complete
echo "Waiting for stack creation to complete..."
aws cloudformation wait stack-create-complete \
  --stack-name "$stack_name" && echo "Stack created successfully"

# Get the SNS topic ARN from stack outputs
sns_topic_arn=$(aws cloudformation describe-stacks \
  --stack-name "$stack_name" \
  --query "Stacks[0].Outputs[?OutputKey=='SNSTopicArn'].OutputValue" \
  --output text) && echo "SNS Topic ARN: $sns_topic_arn"

# Test: Publish 2 high-priority messages
aws sns publish \
  --topic-arn "$sns_topic_arn" \
  --message "High priority task 1: Deploy critical update" \
  --message-attributes '{"priority": {"DataType": "String", "StringValue": "high"}}' && echo "Published high-priority message 1"

aws sns publish \
  --topic-arn "$sns_topic_arn" \
  --message "High priority task 2: Fix production bug" \
  --message-attributes '{"priority": {"DataType": "String", "StringValue": "high"}}' && echo "Published high-priority message 2"

# Publish 2 low-priority messages
aws sns publish \
  --topic-arn "$sns_topic_arn" \
  --message "Low priority task 1: Update documentation" \
  --message-attributes '{"priority": {"DataType": "String", "StringValue": "low"}}' && echo "Published low-priority message 1"

aws sns publish \
  --topic-arn "$sns_topic_arn" \
  --message "Low priority task 2: Clean up old logs" \
  --message-attributes '{"priority": {"DataType": "String", "StringValue": "low"}}' && echo "Published low-priority message 2"

# Wait for messages to propagate to SQS
sleep 5

# Invoke Lambda function to process messages (high-priority first)
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
aws cloudformation describe-stacks --stack-name nautilus-priority-stack --output table
aws sqs list-queues --queue-name-prefix nautilus --output table
aws sns list-topics --output table
aws lambda get-function --function-name nautilus-priorities-queue-function --output table
aws iam get-role --role-name lambda_execution_role --output table
```

```bash
prefix=nautilus
stack_name="$prefix-priority-stack"
high_priority_queue="$prefix-High-Priority-Queue"
low_priority_queue="$prefix-Low-Priority-Queue"
sns_topic_name="$prefix-Priority-Queues-Topic"
lambda_function_name="$prefix-priorities-queue-function"
lambda_role_name="lambda_execution_role"

# Check CloudFormation stack status
stack_status=$(aws cloudformation describe-stacks \
  --stack-name "$stack_name" \
  --query "Stacks[0].StackStatus" \
  --output text 2>/dev/null) && echo "Stack Status: $stack_status"

# Check high-priority queue exists
high_queue_url=$(aws sqs get-queue-url \
  --queue-name "$high_priority_queue" \
  --query "QueueUrl" \
  --output text 2>/dev/null) && echo "High Priority Queue URL: $high_queue_url"

# Check low-priority queue exists
low_queue_url=$(aws sqs get-queue-url \
  --queue-name "$low_priority_queue" \
  --query "QueueUrl" \
  --output text 2>/dev/null) && echo "Low Priority Queue URL: $low_queue_url"

# Check SNS topic exists
sns_topic_arn=$(aws sns list-topics \
  --query "Topics[?contains(TopicArn, '$sns_topic_name')].TopicArn" \
  --output text 2>/dev/null) && echo "SNS Topic ARN: $sns_topic_arn"

# Check SNS subscriptions exist with filter policies
sub_count=$(aws sns list-subscriptions-by-topic \
  --topic-arn "$sns_topic_arn" \
  --query "length(Subscriptions)" \
  --output text 2>/dev/null) && echo "SNS Subscriptions: $sub_count"

# Check Lambda function exists and is active
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

# Validation checks
stack_valid=false
high_queue_valid=false
low_queue_valid=false
sns_topic_valid=false
sns_subs_valid=false
lambda_valid=false
role_valid=false
role_attached_valid=false

[[ "$stack_status" == "CREATE_COMPLETE" ]] && stack_valid=true
[[ -n "$high_queue_url" && "$high_queue_url" != "None" ]] && high_queue_valid=true
[[ -n "$low_queue_url" && "$low_queue_url" != "None" ]] && low_queue_valid=true
[[ -n "$sns_topic_arn" && "$sns_topic_arn" != "None" ]] && sns_topic_valid=true
[[ "$sub_count" -ge 2 ]] && sns_subs_valid=true
[[ "$lambda_state" == "Active" ]] && lambda_valid=true
[[ -n "$role_arn" && "$role_arn" != "None" ]] && role_valid=true
[[ "$lambda_role" == *"$lambda_role_name"* ]] && role_attached_valid=true

if [[ "$stack_valid" == true ]] && [[ "$high_queue_valid" == true ]] && [[ "$low_queue_valid" == true ]] && [[ "$sns_topic_valid" == true ]] && [[ "$sns_subs_valid" == true ]] && [[ "$lambda_valid" == true ]] && [[ "$role_valid" == true ]] && [[ "$role_attached_valid" == true ]]; then
  echo "✓ Success"
  echo "  Stack: $stack_name ($stack_status)"
  echo "  High Priority Queue: $high_priority_queue"
  echo "  Low Priority Queue: $low_priority_queue"
  echo "  SNS Topic: $sns_topic_name"
  echo "  SNS Subscriptions: $sub_count"
  echo "  Lambda Function: $lambda_function_name ($lambda_state)"
  echo "  IAM Role: $lambda_role_name"
else
  echo "✗ Fail"

  if [[ "$stack_valid" == false ]]; then
    echo "  ✗ CloudFormation stack not complete"
    echo "    Expected: CREATE_COMPLETE"
    echo "    Got: $stack_status"
  else
    echo "  ✓ CloudFormation stack is complete"
  fi

  if [[ "$high_queue_valid" == false ]]; then
    echo "  ✗ High priority queue not found"
    echo "    Expected: $high_priority_queue"
  else
    echo "  ✓ High priority queue exists"
  fi

  if [[ "$low_queue_valid" == false ]]; then
    echo "  ✗ Low priority queue not found"
    echo "    Expected: $low_priority_queue"
  else
    echo "  ✓ Low priority queue exists"
  fi

  if [[ "$sns_topic_valid" == false ]]; then
    echo "  ✗ SNS topic not found"
    echo "    Expected: $sns_topic_name"
  else
    echo "  ✓ SNS topic exists"
  fi

  if [[ "$sns_subs_valid" == false ]]; then
    echo "  ✗ SNS subscriptions missing"
    echo "    Expected: 2 subscriptions"
    echo "    Got: $sub_count"
  else
    echo "  ✓ SNS subscriptions configured ($sub_count)"
  fi

  if [[ "$lambda_valid" == false ]]; then
    echo "  ✗ Lambda function not found or not active"
    echo "    Expected: $lambda_function_name"
    echo "    State: $lambda_state"
  else
    echo "  ✓ Lambda function is active"
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
fi
```

</details>
