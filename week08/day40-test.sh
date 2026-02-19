#!/bin/bash
# Test script for Day 40 - Troubleshoot EC2 Application
# Validates VPC internet connectivity for an EC2 instance

set -o pipefail

prefix=xfusion
vpc_name=$prefix-vpc
instance_name=$prefix-ec2
sg_name=$prefix-sg

echo "=== Day 40 - Troubleshoot EC2 Application Test ==="
echo ""

# Track test results
tests_passed=0
tests_failed=0

pass() {
  echo "✓ $1"
  ((tests_passed++))
}

fail() {
  echo "✗ $1"
  echo "  $2"
  ((tests_failed++))
}

# Test 1: VPC exists
echo "Test 1: VPC exists"
vpc_id=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=$vpc_name" \
  --query "Vpcs[0].VpcId" \
  --output text 2>/dev/null)

if [[ -n "$vpc_id" && "$vpc_id" != "None" ]]; then
  pass "VPC '$vpc_name' exists ($vpc_id)"
else
  fail "VPC '$vpc_name' not found" "Create VPC with name tag '$vpc_name'"
fi

# Test 2: Internet Gateway attached to VPC
echo "Test 2: Internet Gateway attached to VPC"
read -r igw_id igw_state <<< "$(aws ec2 describe-internet-gateways \
  --filters "Name=attachment.vpc-id,Values=$vpc_id" \
  --query "InternetGateways[0].[InternetGatewayId,Attachments[0].State]" \
  --output text 2>/dev/null)"

if [[ -n "$igw_id" && "$igw_id" != "None" && "$igw_state" == "available" ]]; then
  pass "Internet Gateway attached ($igw_id)"
else
  fail "No Internet Gateway attached to VPC" "IGW ID: $igw_id, State: $igw_state"
fi

# Test 3: Route to Internet Gateway exists
echo "Test 3: Route to Internet Gateway (0.0.0.0/0)"
route_table_id=$(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$vpc_id" \
  --query "RouteTables[0].RouteTableId" \
  --output text 2>/dev/null)

igw_route=$(aws ec2 describe-route-tables \
  --route-table-ids "$route_table_id" \
  --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].GatewayId" \
  --output text 2>/dev/null)

if [[ -n "$igw_route" && "$igw_route" == igw-* ]]; then
  pass "Route to IGW exists (0.0.0.0/0 -> $igw_route)"
else
  fail "No route to Internet Gateway" "Route Table: $route_table_id, Route: $igw_route"
fi

# Test 4: EC2 instance exists and is running
echo "Test 4: EC2 instance exists and running"
read -r instance_id instance_state subnet_id sg_id <<< "$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$instance_name" \
  --query "Reservations[0].Instances[0].[InstanceId,State.Name,SubnetId,SecurityGroups[0].GroupId]" \
  --output text 2>/dev/null)"

if [[ -n "$instance_id" && "$instance_id" != "None" && "$instance_state" == "running" ]]; then
  pass "EC2 instance '$instance_name' is running ($instance_id)"
else
  fail "EC2 instance not found or not running" "Instance: $instance_id, State: $instance_state"
fi

# Test 5: EC2 instance has public IP
echo "Test 5: EC2 instance has public IP"
public_ip=$(aws ec2 describe-instances \
  --instance-ids "$instance_id" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text 2>/dev/null)

if [[ -n "$public_ip" && "$public_ip" != "None" ]]; then
  pass "EC2 instance has public IP ($public_ip)"
else
  fail "EC2 instance has no public IP" "Allocate and associate an Elastic IP"
fi

# Test 6: Security group allows inbound port 80
echo "Test 6: Security group allows port 80 inbound"
port_80_rule=$(aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=$sg_id" \
  --query "SecurityGroupRules[?IsEgress==\`false\` && IpProtocol==\`tcp\` && FromPort==\`80\` && ToPort==\`80\`].SecurityGroupRuleId" \
  --output text 2>/dev/null)

if [[ -n "$port_80_rule" && "$port_80_rule" != "None" ]]; then
  pass "Security group allows port 80 ($sg_id)"
else
  fail "Port 80 not open in security group" "Security Group: $sg_id"
fi

# Test 7: HTTP connectivity (port 80 responds)
echo "Test 7: HTTP connectivity test"
if [[ -n "$public_ip" && "$public_ip" != "None" ]]; then
  http_status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "http://$public_ip" 2>/dev/null)
  if [[ "$http_status" == "200" ]]; then
    pass "HTTP request successful (status: $http_status)"
  else
    fail "HTTP request failed" "URL: http://$public_ip, Status: $http_status"
  fi
else
  fail "Cannot test HTTP - no public IP" "Skipped due to missing public IP"
fi

# Summary
echo ""
echo "=== Test Summary ==="
echo "Passed: $tests_passed"
echo "Failed: $tests_failed"
echo ""

if [[ $tests_failed -eq 0 ]]; then
  echo "✓ All tests passed - EC2 application is accessible from the internet"
  exit 0
else
  echo "✗ Some tests failed - review the troubleshooting steps above"
  exit 1
fi
