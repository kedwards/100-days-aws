# Day 38: Deploying Containerized Applications with Amazon ECS

## Task

The Nautilus DevOps team is tasked with deploying a containerized application using Amazon's container services. They need to create a private Amazon Elastic Container Registry (ECR) to store their Docker images and use Amazon Elastic Container Service (ECS) to deploy the application. The process involves building a Docker image from a given Dockerfile, pushing it to the ECR, and then setting up an ECS cluster to run the application.

    Create a Private ECR Repository:
        Create a private ECR repository named devops-ecr to store Docker images.

    Build and Push Docker Image:
        Use the Dockerfile located at /root/pyapp on the aws-client host.
        Build a Docker image using this Dockerfile.
        Tag the image with latest tag.
        Push the Docker image to the devops-ecr repository.

    Create and Configure ECS cluster:
        Create an ECS cluster named devops-cluster using the Fargate launch type.

    Create an ECS Task Definition:
        Define a task named devops-taskdefinition using the Docker image from the devops-ecr ECR repository.
        Specify necessary CPU and memory resources.

    Deploy the Application Using ECS Service:
        Create a service named devops-service on the devops-cluster to run the task.
        Ensure the service runs at least one task.

## Help

```bash
aws ecr create-repository help
aws ecr get-login-password help
aws ecr describe-repositories help
aws ecr describe-images help
aws ecs create-cluster help
aws ecs describe-clusters help
aws ecs register-task-definition help
aws ecs describe-task-definition help
aws ecs create-service help
aws ecs describe-services help
aws ecs list-tasks help
aws iam create-role help
aws iam attach-role-policy help
aws ec2 describe-security-groups help
aws ec2 describe-subnets help
```

<details>
<summary><h2>Solution</h2></summary>

```bash
prefix=devops
repository_name="$prefix-ecr"
cluster_name="$prefix-cluster"
json_file="taskdef.json"
service_name="$prefix-service"
execution_role_name="${prefix}-ecsTaskExecutionRole"

read -r repository_uri registry_id <<< "$(aws ecr create-repository \
  --repository-name "$repository_name" \
  --query "repository.[repositoryUri,registryId]" \
  --output text)" && echo "Repository URI: $repository_uri, Registry ID: $registry_id"

cd pyapp

docker build -t "$repository_uri:latest" .

aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $repository_uri

docker push "$repository_uri:latest"

cluster_arn=$(aws ecs create-cluster \
  --cluster-name "$cluster_name" \
  --query "cluster.clusterArn" \
  --output text) && echo "Cluster ARN: $cluster_arn"

# Create ECS Task Execution Role (required for Fargate)
execution_role_name="${prefix}-ecsTaskExecutionRole"

execution_role_arn=$(aws iam create-role \aws iam create-role \
  --role-name $execution_role_name \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "ecs-tasks.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }' \
  --query "Role.Arn" \
  --output text) && echo "Execution Role ARN: $execution_role_arn"


aws iam attach-role-policy \
  --role-name $execution_role_name \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

sleep 10

cat << EOF > $json_file
{
  "family": "${prefix}-taskdefinition",
  "networkMode": "awsvpc",
  "executionRoleArn": "${execution_role_arn}",
  "containerDefinitions": [
    {
      "name": "$repository_name",
      "image": "${repository_uri}:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 80,
          "protocol": "tcp"
        }
      ]
    }
  ],
  "requiresCompatibilities": [
    "FARGATE"
  ],
  "cpu": "256",
  "memory": "512"
}
EOF

task_definition_arn=$(aws ecs register-task-definition \
  --cli-input-json file://$json_file \
  --tags "key=Name,value=${prefix}-taskdefinition" \
  --query "taskDefinition.taskDefinitionArn" \
  --output text) && echo "Task Definition ARN: $task_definition_arn"

default_security_group_id=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=default" \
  --query "SecurityGroups[0].GroupId" \
  --output text) && echo "Default Security Group ID: $default_security_group_id"

aws ec2 authorize-security-group-ingress \
  --group-id $default_security_group_id \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

subnet_id=$(aws ec2 describe-subnets \
   --query Subnets[0].SubnetId \
  --output text) && echo "Subnet ID: $subnet_id"

aws ecs create-service \
  --cluster $cluster_name \
  --service-name $service_name \
  --task-definition $task_definition_arn \
  --desired-count 1 \
  --launch-type FARGATE \
  --platform-version LATEST \
  --network-configuration "awsvpcConfiguration={subnets=[$subnet_id],securityGroups=[$default_security_group_id],assignPublicIp=ENABLED}"

eni_id=$(aws ecs describe-tasks \
    --cluster $cluster_name \
    --tasks $task_definition_arn \
    --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value" \
    --output text) && echo "ENI ID: $eni_id"
  
public_ip=$(aws ec2 describe-network-interfaces \
  --network-interface-ids $eni_id \
  --query "NetworkInterfaces[0].Association.PublicIp" \
  --output text) && echo "Public IP: $public_ip"
  
curl http://$public_ip

curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "http://$public_ip"
```

</details>

<details>
<summary><h2>Validate</h2></summary>

```bash
aws ecr describe-repositories --repository-names $repository_name \
  --query "repositories[].{Name:repositoryName,URI:repositoryUri}" \
  --output table

aws ecs describe-clusters --clusters $cluster_name \
  --query "clusters[].{Name:clusterName,Status:status}" \
  --output table

aws ecs describe-services --cluster $cluster_name --services $service_name \
  --query "services[].{Name:serviceName,Status:status,RunningCount:runningCount,DesiredCount:desiredCount}" \
  --output table
```

```bash
prefix=devops
repository_name="$prefix-ecr"
cluster_name="$prefix-cluster"
service_name="$prefix-service"
task_definition_name="$prefix-taskdefinition"

read -r ecr_name ecr_uri <<< "$(aws ecr describe-repositories \
  --repository-names $repository_name \
  --query "repositories[0].[repositoryName,repositoryUri]" \
  --output text 2>/dev/null)"&& echo "ECR: $ecr_name, URI: $ecr_uri"

image_tag=$(aws ecr describe-images \
  --repository-name $repository_name \
  --query "imageDetails[0].imageTags[0]" \
  --output text 2>/dev/null) && echo "Image tag: $image_tag"

cluster_status=$(aws ecs describe-clusters \
  --clusters $cluster_name \
  --query "clusters[0].status" \
  --output text 2>/dev/null) && echo "Cluster status: $cluster_status"

read -r task_def_arn task_def_status <<< "$(aws ecs describe-task-definition \
  --task-definition $task_definition_name \
  --query "taskDefinition.[taskDefinitionArn,status]" \
  --output text 2>/dev/null)"&& echo "Task Definition: $task_def_arn, Status: $task_def_status"

read -r svc_name svc_status running_count desired_count <<< "$(aws ecs describe-services \
  --cluster $cluster_name \
  --services $service_name \
  --query "services[0].[serviceName,status,runningCount,desiredCount]" \
  --output text 2>/dev/null)"&& echo "Service: $svc_name, Status: $svc_status, Running: $running_count/$desired_count"

task_arn=$(aws ecs list-tasks \
  --cluster $cluster_name \
  --service-name $service_name \
  --query "taskArns[0]" \
  --output text 2>/dev/null) && echo "Task ARN: $task_arn"

task_count=0
public_ip=""
http_status=""

if [[ -n "$task_arn" && "$task_arn" != "None" ]]; then
  task_count=1
  
  # Get the ENI ID from the task
  eni_id=$(aws ecs describe-tasks \
    --cluster $cluster_name \
    --tasks $task_arn \
    --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value" \
    --output text 2>/dev/null) && echo "ENI ID: $eni_id"
  
  # Get public IP from the ENI
  if [[ -n "$eni_id" && "$eni_id" != "None" ]]; then
    public_ip=$(aws ec2 describe-network-interfaces \
      --network-interface-ids $eni_id \
      --query "NetworkInterfaces[0].Association.PublicIp" \
      --output text 2>/dev/null) && echo "Public IP: $public_ip"
  fi
  
  # Test HTTP response
  if [[ -n "$public_ip" && "$public_ip" != "None" ]]; then
    echo "Testing HTTP endpoint: http://$public_ip"
    http_status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "http://$public_ip" 2>/dev/null)
    echo "HTTP Status: $http_status"
  fi
fi

# Validation checks
ecr_exists=false
image_exists=false
cluster_active=false
task_def_exists=false
service_active=false
tasks_running=false
http_success=false

[[ -n "$ecr_name" && "$ecr_name" != "None" ]] && ecr_exists=true
[[ -n "$image_tag" && "$image_tag" != "None" ]] && image_exists=true
[[ "$cluster_status" == "ACTIVE" ]] && cluster_active=true
[[ -n "$task_def_arn" && "$task_def_arn" != "None" ]] && task_def_exists=true
[[ "$svc_status" == "ACTIVE" ]] && service_active=true
[[ "$task_count" -ge 1 ]] 2>/dev/null && tasks_running=true
[[ "$http_status" == "200" ]] && http_success=true

if [[ "$ecr_exists" == true ]] && [[ "$image_exists" == true ]] && [[ "$cluster_active" == true ]] && [[ "$task_def_exists" == true ]] && [[ "$service_active" == true ]] && [[ "$tasks_running" == true ]] && [[ "$http_success" == true ]]; then
  echo "✓ Success"
  echo "  ECR Repository: $ecr_name"
  echo "  Image Tag: $image_tag"
  echo "  Cluster: $cluster_name ($cluster_status)"
  echo "  Task Definition: $task_definition_name"
  echo "  Service: $svc_name ($svc_status)"
  echo "  Running Tasks: $running_count/$desired_count"
  echo "  Public IP: $public_ip"
  echo "  HTTP Status: $http_status (OK)"
else
  echo "✗ Fail"
  
  if [[ "$ecr_exists" == false ]]; then
    echo "  ✗ ECR repository '$repository_name' not found"
  else
    echo "  ✓ ECR repository exists"
  fi
  
  if [[ "$image_exists" == false ]]; then
    echo "  ✗ No image found in ECR repository"
  else
    echo "  ✓ Image exists in ECR (tag: $image_tag)"
  fi
  
  if [[ "$cluster_active" == false ]]; then
    echo "  ✗ ECS cluster not active"
    echo "    Got: $cluster_status"
  else
    echo "  ✓ ECS cluster is active"
  fi
  
  if [[ "$task_def_exists" == false ]]; then
    echo "  ✗ Task definition '$task_definition_name' not found"
  else
    echo "  ✓ Task definition exists"
  fi
  
  if [[ "$service_active" == false ]]; then
    echo "  ✗ ECS service not active"
    echo "    Got: $svc_status"
  else
    echo "  ✓ ECS service is active"
  fi
  
  if [[ "$tasks_running" == false ]]; then
    echo "  ✗ No tasks running"
    echo "    Running: $running_count, Desired: $desired_count"
  else
    echo "  ✓ Tasks are running ($running_count/$desired_count)"
  fi
  
  if [[ "$http_success" == false ]]; then
    echo "  ✗ HTTP request failed"
    echo "    Public IP: $public_ip"
    echo "    Expected: 200"
    echo "    Got: $http_status"
  else
    echo "  ✓ HTTP request successful (200)"
  fi
fi
```

</details>
