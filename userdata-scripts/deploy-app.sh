#!/bin/bash
# Deployment script with explicit language selection
# Usage: ./deploy-app.sh <language> [web_server]
#   language: python, golang, node, php
#   web_server: nginx or httpd (only for PHP, default: nginx)

set -e

LANGUAGE="$1"
WEB_SERVER="${2:-nginx}"

if [ -z "$LANGUAGE" ]; then
    echo "Error: Language must be specified!"
    echo ""
    echo "Usage: $0 <language> [web_server]"
    echo ""
    echo "Available languages:"
    echo "  python  - Flask application with Gunicorn"
    echo "  golang  - Native Go HTTP server"
    echo "  node    - Express.js application"
    echo "  php     - PHP with nginx or Apache"
    echo ""
    echo "For PHP, optionally specify web server:"
    echo "  $0 php nginx   (default)"
    echo "  $0 php httpd"
    echo ""
    exit 1
fi

# Validate language
case "$LANGUAGE" in
    python|golang|node|php)
        ;;
    *)
        echo "Error: Invalid language '$LANGUAGE'"
        echo "Valid options: python, golang, node, php"
        exit 1
        ;;
esac

# Set userdata script path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USERDATA_SCRIPT="$SCRIPT_DIR/userdata-$LANGUAGE.sh"

if [ ! -f "$USERDATA_SCRIPT" ]; then
    echo "Error: Userdata script not found: $USERDATA_SCRIPT"
    exit 1
fi

echo "Selected language: $LANGUAGE"
if [ "$LANGUAGE" = "php" ]; then
    echo "Selected web server: $WEB_SERVER"
fi

# Common AWS variables
prefix="app-$LANGUAGE"
region=us-east-1
instance_type=t2.micro
security_group_name="$prefix-sg"
instance_name="$prefix-ec2"

echo "Getting VPC..."
vpc_id=$(aws ec2 describe-vpcs \
  --query "Vpcs[0].VpcId" \
  --output text) && echo "VPC: $vpc_id"

echo "Creating security group..."
ec2_security_group_id=$(aws ec2 create-security-group \
  --group-name "$security_group_name" \
  --description "Security group for $prefix" \
  --vpc-id "$vpc_id" \
  --query "GroupId" \
  --output text 2>/dev/null) || {
    # Security group might already exist
    ec2_security_group_id=$(aws ec2 describe-security-groups \
      --filters "Name=group-name,Values=$security_group_name" \
      --query "SecurityGroups[0].GroupId" \
      --output text)
}
echo "Security Group: $ec2_security_group_id"

echo "Authorizing port 80..."
aws ec2 authorize-security-group-ingress \
  --group-id "$ec2_security_group_id" \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0 2>/dev/null || echo "Port 80 already authorized"

# Ubuntu AMI
ubuntu_image=resolve:ssm:/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id

# Read userdata script
if [ "$LANGUAGE" = "php" ]; then
    # For PHP, inject WEB_SERVER variable
    userdata_script="#!/bin/bash
export WEB_SERVER=$WEB_SERVER
$(tail -n +2 "$USERDATA_SCRIPT")"
else
    userdata_script=$(cat "$USERDATA_SCRIPT")
fi

echo "Creating EC2 instance with $LANGUAGE application..."
instance_id=$(aws ec2 run-instances \
  --image-id $ubuntu_image \
  --instance-type "$instance_type" \
  --region "$region" \
  --security-group-ids "$ec2_security_group_id" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance_name},{Key=Language,Value=$LANGUAGE}]" \
  --user-data "$userdata_script" \
  --query "Instances[0].InstanceId" \
  --output text) && echo "Instance ID: $instance_id"

echo "Waiting for instance to start..."
aws ec2 wait instance-running --instance-ids "$instance_id"

public_ip=$(aws ec2 describe-instances \
  --instance-ids "$instance_id" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

echo ""
echo "=================================================================="
echo "✓ Deployment successful!"
echo "=================================================================="
echo "Language:     $LANGUAGE"
if [ "$LANGUAGE" = "php" ]; then
    echo "Web Server:   $WEB_SERVER"
fi
echo "Instance ID:  $instance_id"
echo "Public IP:    $public_ip"
echo ""
echo "Application:  http://$public_ip"
echo "Health Check: http://$public_ip/health"
if [ "$LANGUAGE" = "php" ]; then
    echo "Health Check: http://$public_ip/health.php"
fi
echo ""
echo "Note: Wait 2-3 minutes for userdata script to complete setup"
echo "=================================================================="
