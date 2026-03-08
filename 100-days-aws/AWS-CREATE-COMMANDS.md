# AWS CLI Create Command Reference

Quick-reference catalog of all `aws ... create-*` commands used in this repository, organized by service. Each entry links to the day file and line number where the command is used.

---

## EC2

### `aws ec2 create-key-pair`
Creates an EC2 key pair for SSH access.
- [Day 1: Create Key Pair](week01/day01-create-keypair.md) — line 25
- [Day 6: Launch EC2 Instance](week02/day06-launch-ec2-instance.md) — line 34

### `aws ec2 create-security-group`
Creates a VPC security group.
- [Day 2: Create Security Group](week01/day02-create-security-group.md) — line 34
- [Day 24: Application Load Balancer for EC2](week05/day24-application-load-balancer-for-ec2.md) — line 58
- [Day 27: Public VPC with EC2 Internet Access](week06/day27-public-vpc-ec2-internet-access.md) — line 84
- [Day 30: Enable Internet via NAT Instance](week06/day30-enable-internet-via-nat.md) — line 136
- [Day 35: Deploying Applications on AWS](week07/day35-applications-on-aws.md) — line 93
- [Day 36: Load Balancing EC2](week08/day36-load-balancing-ec2.md) — line 75
- [Day 44: Auto Scaling for High Availability](week09/day44-high-availability.md) — line 83 (via launch template)
- [Day 49: Centralized Audit Logging with VPC Peering](week10/day49-centalize-audit-logging-with-vpc-peering.md) — line 134

### `aws ec2 create-subnet`
Creates a subnet in a VPC.
- [Day 3: Create Subnet](week01/day03-create-subnet.md) — line 30
- [Day 27: Public VPC with EC2 Internet Access](week06/day27-public-vpc-ec2-internet-access.md) — line 75
- [Day 30: Enable Internet via NAT Instance](week06/day30-enable-internet-via-nat.md) — line 89
- [Day 35: Deploying Applications on AWS](week07/day35-applications-on-aws.md) — line 68
- [Day 45: NAT Gateway in Private VPC](week09/day45-nat-gateway-in-private-vpc.md) — line 68
- [Day 49: Centralized Audit Logging with VPC Peering](week10/day49-centalize-audit-logging-with-vpc-peering.md) — line 96

### `aws ec2 create-volume`
Creates an EBS volume.
- [Day 5: Create GP3 Volume](week01/day05-create-gp3-volume.md) — line 27

### `aws ec2 create-image`
Creates an AMI from an EC2 instance.
- [Day 13: Create AMI from EC2 Instance](week03/day13-create-ami-from-ec2-instance.md) — line 32

### `aws ec2 create-snapshot`
Creates a snapshot of an EBS volume.
- [Day 15: Create Volume Snapshot](week03/day15-create-volume-snapshot.md) — line 35

### `aws ec2 create-vpc`
Creates a Virtual Private Cloud.
- [Day 27: Public VPC with EC2 Internet Access](week06/day27-public-vpc-ec2-internet-access.md) — line 50
- [Day 49: Centralized Audit Logging with VPC Peering](week10/day49-centalize-audit-logging-with-vpc-peering.md) — line 89

### `aws ec2 create-internet-gateway`
Creates an Internet Gateway for VPC internet access.
- [Day 27: Public VPC with EC2 Internet Access](week06/day27-public-vpc-ec2-internet-access.md) — line 56
- [Day 30: Enable Internet via NAT Instance](week06/day30-enable-internet-via-nat.md) — line 104
- [Day 40: Troubleshoot EC2 Application](week08/day40-troubleshoot-ec2-application.md) — line 60
- [Day 45: NAT Gateway in Private VPC](week09/day45-nat-gateway-in-private-vpc.md) — line 75
- [Day 49: Centralized Audit Logging with VPC Peering](week10/day49-centalize-audit-logging-with-vpc-peering.md) — line 119

### `aws ec2 create-route-table`
Creates a route table in a VPC.
- [Day 30: Enable Internet via NAT Instance](week06/day30-enable-internet-via-nat.md) — line 116
- [Day 35: Deploying Applications on AWS](week07/day35-applications-on-aws.md) — line 53
- [Day 45: NAT Gateway in Private VPC](week09/day45-nat-gateway-in-private-vpc.md) — line 84
- [Day 49: Centralized Audit Logging with VPC Peering](week10/day49-centalize-audit-logging-with-vpc-peering.md) — line 108

### `aws ec2 create-route`
Adds a route to a route table (e.g. to IGW, NAT, or peering connection).
- [Day 27: Public VPC with EC2 Internet Access](week06/day27-public-vpc-ec2-internet-access.md) — line 70
- [Day 29: Secure VPC Communications via Peering](week06/day29-secure-vpc-communications.md) — lines 94, 99
- [Day 30: Enable Internet via NAT Instance](week06/day30-enable-internet-via-nat.md) — lines 123, 216
- [Day 40: Troubleshoot EC2 Application](week08/day40-troubleshoot-ec2-application.md) — line 85
- [Day 45: NAT Gateway in Private VPC](week09/day45-nat-gateway-in-private-vpc.md) — lines 90, 126
- [Day 49: Centralized Audit Logging with VPC Peering](week10/day49-centalize-audit-logging-with-vpc-peering.md) — lines 128, 258, 263

### `aws ec2 create-vpc-peering-connection`
Creates a VPC peering connection between two VPCs.
- [Day 29: Secure VPC Communications via Peering](week06/day29-secure-vpc-communications.md) — line 71
- [Day 49: Centralized Audit Logging with VPC Peering](week10/day49-centalize-audit-logging-with-vpc-peering.md) — line 247

### `aws ec2 create-nat-gateway`
Creates a managed NAT Gateway for private subnet internet access.
- [Day 45: NAT Gateway in Private VPC](week09/day45-nat-gateway-in-private-vpc.md) — line 104

### `aws ec2 create-launch-template`
Creates a launch template for EC2 Auto Scaling.
- [Day 44: Auto Scaling for High Availability](week09/day44-high-availability.md) — line 83

---

## IAM

### `aws iam create-user`
Creates an IAM user.
- [Day 16: Create IAM User](week04/day16-create-user.md) — line 24

### `aws iam create-group`
Creates an IAM group.
- [Day 17: Create IAM Group](week04/day17-create-group.md) — line 24

### `aws iam create-policy`
Creates an IAM policy from a JSON document.
- [Day 18: Create Read-Only IAM Policy](week04/day18-create-policy.md) — line 42
- [Day 37: EC2 Access with S3 Permissions](week08/day37-ec2-s3-permissions.md) — line 89
- [Day 46: Event-Driven Processing with S3 and Lambda](week10/day46-event-processing-s3-and-lambda.md) — line 227
- [Day 49: Centralized Audit Logging with VPC Peering](week10/day49-centalize-audit-logging-with-vpc-peering.md) — line 178

### `aws iam create-role`
Creates an IAM role with a trust policy.
- [Day 20: IAM Role for EC2 with Policy](week04/day20-create-and-attach-policy.md) — line 55
- [Day 33: Create a Lambda Function](week07/day33-create-a-lambda-function.md) — line 62
- [Day 34: Create a Lambda Function Using CLI](week07/day34-create-a-lambda-function-cli.md) — line 60
- [Day 37: EC2 Access with S3 Permissions](week08/day37-ec2-s3-permissions.md) — line 76
- [Day 38: Deploying Containerized Apps with ECS](week08/day38-deploy-container-apps-with-ecs.md) — line 79
- [Day 43: Kubernetes Clusters with EKS](week09/day43-manageing-k8s-clusters-with-eks.md) — line 60
- [Day 46: Event-Driven Processing with S3 and Lambda](week10/day46-event-processing-s3-and-lambda.md) — line 178
- [Day 49: Centralized Audit Logging with VPC Peering](week10/day49-centalize-audit-logging-with-vpc-peering.md) — line 161

### `aws iam create-instance-profile`
Creates an instance profile to attach an IAM role to an EC2 instance.
- [Day 37: EC2 Access with S3 Permissions](week08/day37-ec2-s3-permissions.md) — line 146
- [Day 49: Centralized Audit Logging with VPC Peering](week10/day49-centalize-audit-logging-with-vpc-peering.md) — line 188

---

## S3

### `aws s3api create-bucket`
Creates an S3 bucket.
- [Day 23: Data Migration Between S3 Buckets](week05/day23-data-migration-between-s3-buckets.md) — line 37
- [Day 37: EC2 Access with S3 Permissions](week08/day37-ec2-s3-permissions.md) — line 71
- [Day 39: Hosting a Static Website on S3](week08/day39-s3-static-website.md) — line 37
- [Day 46: Event-Driven Processing with S3 and Lambda](week10/day46-event-processing-s3-and-lambda.md) — lines 49, 58
- [Day 49: Centralized Audit Logging with VPC Peering](week10/day49-centalize-audit-logging-with-vpc-peering.md) — line 242

---

## RDS

### `aws rds create-db-instance`
Creates an RDS database instance.
- [Day 31: Private RDS Instance](week07/day31-rds-for-applications.md) — line 34
- [Day 35: Deploying Applications on AWS](week07/day35-applications-on-aws.md) — line 126

### `aws rds create-db-snapshot`
Creates a manual snapshot of an RDS instance.
- [Day 32: Snapshot and Restoration of RDS](week07/day32-db-snapshot-and-restore.md) — line 35

### `aws rds create-db-subnet-group`
Creates a DB subnet group for RDS multi-AZ placement.
- [Day 35: Deploying Applications on AWS](week07/day35-applications-on-aws.md) — line 86

---

## Lambda

### `aws lambda create-function`
Creates a Lambda function from a deployment package.
- [Day 33: Create a Lambda Function](week07/day33-create-a-lambda-function.md) — line 70
- [Day 34: Create a Lambda Function Using CLI](week07/day34-create-a-lambda-function-cli.md) — line 68
- [Day 46: Event-Driven Processing with S3 and Lambda](week10/day46-event-processing-s3-and-lambda.md) — line 240

---

## ELB / ALB

### `aws elbv2 create-load-balancer`
Creates an Application Load Balancer.
- [Day 24: Application Load Balancer for EC2](week05/day24-application-load-balancer-for-ec2.md) — line 101
- [Day 36: Load Balancing EC2](week08/day36-load-balancing-ec2.md) — line 145
- [Day 44: Auto Scaling for High Availability](week09/day44-high-availability.md) — line 89

### `aws elbv2 create-target-group`
Creates a target group for load balancer routing.
- [Day 24: Application Load Balancer for EC2](week05/day24-application-load-balancer-for-ec2.md) — line 80
- [Day 36: Load Balancing EC2](week08/day36-load-balancing-ec2.md) — line 152
- [Day 44: Auto Scaling for High Availability](week09/day44-high-availability.md) — line 96

### `aws elbv2 create-listener`
Creates a listener on a load balancer.
- [Day 24: Application Load Balancer for EC2](week05/day24-application-load-balancer-for-ec2.md) — line 112
- [Day 36: Load Balancing EC2](week08/day36-load-balancing-ec2.md) — line 161
- [Day 44: Auto Scaling for High Availability](week09/day44-high-availability.md) — line 132

---

## ECR

### `aws ecr create-repository`
Creates a private ECR container image repository.
- [Day 28: Creating a Private ECR Repository](week06/day28-creating-private-ecr.md) — line 28
- [Day 38: Deploying Containerized Apps with ECS](week08/day38-deploy-container-apps-with-ecs.md) — line 58

---

## ECS

### `aws ecs create-cluster`
Creates an ECS cluster.
- [Day 38: Deploying Containerized Apps with ECS](week08/day38-deploy-container-apps-with-ecs.md) — line 71

### `aws ecs create-service`
Creates an ECS service to run and maintain tasks.
- [Day 38: Deploying Containerized Apps with ECS](week08/day38-deploy-container-apps-with-ecs.md) — line 146

---

## EKS

### `aws eks create-cluster`
Creates an Amazon EKS Kubernetes cluster.
- [Day 43: Kubernetes Clusters with EKS](week09/day43-manageing-k8s-clusters-with-eks.md) — line 69

---

## Auto Scaling

### `aws autoscaling create-auto-scaling-group`
Creates an Auto Scaling group from a launch template.
- [Day 44: Auto Scaling for High Availability](week09/day44-high-availability.md) — line 105

---

## DynamoDB

### `aws dynamodb create-table`
Creates a DynamoDB table.
- [Day 42: NoSQL Databases with DynamoDB](week09/day42-building-and-maintaining-nosql.md) — line 36
- [Day 46: Event-Driven Processing with S3 and Lambda](week10/day46-event-processing-s3-and-lambda.md) — line 167

---

## KMS

### `aws kms create-key`
Creates a KMS customer-managed encryption key.
- [Day 41: Securing Data with KMS](week09/day41-securing-data-with-kms.md) — line 36

### `aws kms create-alias`
Creates an alias for a KMS key.
- [Day 41: Securing Data with KMS](week09/day41-securing-data-with-kms.md) — line 42

---

## SNS

### `aws sns create-topic`
Creates an SNS topic for notifications.
- [Day 25: EC2 Instance with CloudWatch Alarm](week05/day25-ec2-instance-with-cloudwatch-alarm.md) — line 40

---

## CloudFormation

### `aws cloudformation create-stack`
Creates a CloudFormation stack from a template.
- [Day 47: Integrating SQS and SNS for Messaging](week10/day47-integrating-sqs-and-sns-for-messaging.md) — line 223
- [Day 48: Automating Infrastructure with CloudFormation](week10/day48-auto-infra-deployment-with-cfn.md) — line 79
