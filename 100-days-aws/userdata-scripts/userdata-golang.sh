#!/bin/bash
set -e

# Golang HTTP server with nginx reverse proxy

GO_VERSION="1.21.6"
WEB_ROOT="/var/www"

# Detect OS and install packages
if [ -f /etc/debian_version ]; then
    # Ubuntu/Debian
    apt-get update
    apt-get install -y nginx wget
elif [ -f /etc/redhat-release ]; then
    # Amazon Linux/RHEL
    yum install -y nginx wget
fi

# Install Go
cd /tmp
wget -q "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"
rm -rf /usr/local/go
tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz"
export PATH=$PATH:/usr/local/go/bin

# Create application directory
mkdir -p $WEB_ROOT/app
cd $WEB_ROOT/app

# Create Go application
cat <<'EOF' > main.go
package main

import (
    "encoding/json"
    "fmt"
    "log"
    "net/http"
    "os"
    "runtime"
)

type HealthResponse struct {
    Status string `json:"status"`
}

func mainHandler(w http.ResponseWriter, r *http.Request) {
    hostname, _ := os.Hostname()
    html := fmt.Sprintf(`
    <html>
    <head><title>Go HTTP Server</title></head>
    <body>
        <h1>Golang HTTP Server</h1>
        <p><strong>Hostname:</strong> %s</p>
        <p><strong>Go Version:</strong> %s</p>
        <p><strong>Architecture:</strong> %s/%s</p>
    </body>
    </html>
    `, hostname, runtime.Version(), runtime.GOOS, runtime.GOARCH)
    
    w.Header().Set("Content-Type", "text/html")
    fmt.Fprint(w, html)
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(HealthResponse{Status: "healthy"})
}

func main() {
    http.HandleFunc("/", mainHandler)
    http.HandleFunc("/health", healthHandler)
    
    log.Println("Server starting on :8000")
    if err := http.ListenAndServe(":8000", nil); err != nil {
        log.Fatal(err)
    }
}
EOF

# Initialize Go module and build
go mod init goapp
go build -o goapp main.go

# Create systemd service
cat <<EOF > /etc/systemd/system/go-app.service
[Unit]
Description=Go HTTP Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$WEB_ROOT/app
ExecStart=$WEB_ROOT/app/goapp
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Configure nginx as reverse proxy
cat <<'EOF' > /etc/nginx/conf.d/go-app.conf
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
systemctl enable go-app nginx
systemctl start go-app nginx
