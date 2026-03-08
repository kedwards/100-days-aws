# EC2 Userdata Scripts

Standalone userdata scripts for deploying web applications in different languages on EC2 instances.

## Available Scripts

- `userdata-python.sh` - Python Flask application with Gunicorn
- `userdata-golang.sh` - Golang HTTP server
- `userdata-node.sh` - Node.js Express application
- `userdata-php.sh` - PHP with nginx or Apache (configurable)

All scripts include:
- OS detection (Ubuntu/Debian vs Amazon Linux/RHEL)
- Nginx reverse proxy configuration (or Apache for PHP)
- Systemd service setup
- Health check endpoint at `/health` (PHP also has `/health.php`)
- Auto-start on boot

## Quick Start (Recommended)

Use the `deploy-app.sh` script for easy deployment with explicit language selection:

```bash
# Deploy Python app
./userdata-scripts/deploy-app.sh python

# Deploy Golang app
./userdata-scripts/deploy-app.sh golang

# Deploy Node.js app
./userdata-scripts/deploy-app.sh node

# Deploy PHP with nginx (default)
./userdata-scripts/deploy-app.sh php

# Deploy PHP with Apache
./userdata-scripts/deploy-app.sh php httpd
```

No defaults - you **must** specify which language to deploy!

## Manual Usage with AWS CLI

### Direct file reference:
```bash
aws ec2 run-instances \
  --image-id ami-xxxxx \
  --instance-type t2.micro \
  --user-data file://userdata-scripts/userdata-python.sh \
  ...
```

### Using in bash scripts:
```bash
# Read script into variable
userdata_script=$(cat userdata-scripts/userdata-node.sh)

# Use in EC2 creation
instance_id=$(aws ec2 run-instances \
  --image-id $ubuntu_image \
  --instance-type t2.micro \
  --user-data "$userdata_script" \
  --query "Instances[0].InstanceId" \
  --output text)
```

### Echo into another file:
```bash
# Python
cat userdata-scripts/userdata-python.sh > my-deployment.sh

# Golang
cat userdata-scripts/userdata-golang.sh >> my-deployment.sh

# Node.js
cat userdata-scripts/userdata-node.sh >> my-deployment.sh
```

## Application Endpoints

Once deployed, each application serves:
- `/` - Main page with system info
- `/health` - Health check endpoint (JSON)

All applications listen on port 8000 internally and are proxied through nginx on port 80.

## Testing Locally

You can test these scripts locally (requires root/sudo):
```bash
sudo bash userdata-scripts/userdata-python.sh
curl http://localhost
curl http://localhost/health
```

## OS Compatibility

✓ Ubuntu 20.04/22.04/24.04
✓ Debian 11/12
✓ Amazon Linux 2023
✓ Amazon Linux 2
✓ RHEL 8/9

## Ports

- **80** - Nginx (external)
- **8000** - Application (internal, proxied by nginx)

## Service Management

```bash
# Check application status
systemctl status flask-app    # Python
systemctl status go-app       # Golang
systemctl status node-app     # Node.js

# Check nginx status
systemctl status nginx

# View logs
journalctl -u flask-app -f
journalctl -u go-app -f
journalctl -u node-app -f
```
