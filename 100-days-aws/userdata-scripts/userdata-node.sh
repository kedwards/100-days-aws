#!/bin/bash
set -e

# Node.js Express application with nginx reverse proxy

NODE_VERSION="20"
WEB_ROOT="/var/www"

# Detect OS and install packages
if [ -f /etc/debian_version ]; then
    # Ubuntu/Debian
    apt-get update
    apt-get install -y nginx curl
    # Install Node.js from NodeSource
    curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION}.x" | bash -
    apt-get install -y nodejs
elif [ -f /etc/redhat-release ]; then
    # Amazon Linux/RHEL
    yum install -y nginx curl
    # Install Node.js from NodeSource
    curl -fsSL "https://rpm.nodesource.com/setup_${NODE_VERSION}.x" | bash -
    yum install -y nodejs
fi

# Create application directory
mkdir -p $WEB_ROOT/app
cd $WEB_ROOT/app

# Initialize npm project and install Express
npm init -y
npm install express

# Create Express application
cat <<'EOF' > app.js
const express = require('express');
const os = require('os');

const app = express();
const PORT = 8000;

app.get('/', (req, res) => {
    const html = `
    <html>
    <head><title>Node.js Express App</title></head>
    <body>
        <h1>Node.js Express Application</h1>
        <p><strong>Hostname:</strong> ${os.hostname()}</p>
        <p><strong>Node Version:</strong> ${process.version}</p>
        <p><strong>Platform:</strong> ${process.platform}</p>
        <p><strong>Architecture:</strong> ${process.arch}</p>
    </body>
    </html>
    `;
    res.send(html);
});

app.get('/health', (req, res) => {
    res.json({ status: 'healthy' });
});

app.listen(PORT, () => {
    console.log(\`Server running on port \${PORT}\`);
});
EOF

# Create systemd service
cat <<EOF > /etc/systemd/system/node-app.service
[Unit]
Description=Node.js Express Application
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$WEB_ROOT/app
ExecStart=/usr/bin/node app.js
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Configure nginx as reverse proxy
cat <<'EOF' > /etc/nginx/conf.d/node-app.conf
server {
    listen 80 default_server;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_cache_bypass $http_upgrade;
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
systemctl enable node-app nginx
systemctl start node-app nginx
