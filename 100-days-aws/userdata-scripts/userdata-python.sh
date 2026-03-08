#!/bin/bash
set -e

# Python Flask application with nginx reverse proxy

# Detect OS and install packages
if [ -f /etc/debian_version ]; then
    # Ubuntu/Debian
    apt-get update
    apt-get install -y nginx python3 python3-pip python3-venv
    WEB_ROOT="/var/www"
elif [ -f /etc/redhat-release ]; then
    # Amazon Linux/RHEL
    yum install -y nginx python3 python3-pip
    WEB_ROOT="/var/www"
fi

# Create application directory
mkdir -p $WEB_ROOT/app
cd $WEB_ROOT/app

# Create virtual environment and install Flask
python3 -m venv venv
source venv/bin/activate
pip install flask gunicorn

# Create Flask application
cat <<'EOF' > app.py
from flask import Flask
import socket
import os

app = Flask(__name__)

@app.route('/')
def hello():
    hostname = socket.gethostname()
    return f'''
    <html>
    <head><title>Python Flask App</title></head>
    <body>
        <h1>Python Flask Application</h1>
        <p><strong>Hostname:</strong> {hostname}</p>
        <p><strong>Python Version:</strong> {os.sys.version}</p>
        <p><strong>Framework:</strong> Flask</p>
    </body>
    </html>
    '''

@app.route('/health')
def health():
    return {'status': 'healthy'}, 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000)
EOF

# Create systemd service for Gunicorn
cat <<EOF > /etc/systemd/system/flask-app.service
[Unit]
Description=Gunicorn instance to serve Flask app
After=network.target

[Service]
User=root
Group=root
WorkingDirectory=$WEB_ROOT/app
Environment="PATH=$WEB_ROOT/app/venv/bin"
ExecStart=$WEB_ROOT/app/venv/bin/gunicorn --workers 3 --bind 127.0.0.1:8000 app:app

[Install]
WantedBy=multi-user.target
EOF

# Configure nginx as reverse proxy
cat <<'EOF' > /etc/nginx/conf.d/flask-app.conf
server {
    listen 80 default_server;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /health {
        proxy_pass http://127.0.0.1:8000/health;
        access_log off;
    }
}
EOF

# Remove default nginx configurations
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/conf.d/default.conf

# Start services
systemctl daemon-reload
systemctl enable flask-app nginx
systemctl start flask-app nginx
