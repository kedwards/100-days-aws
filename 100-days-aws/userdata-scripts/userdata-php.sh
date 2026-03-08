#!/bin/bash
set -e

# PHP application with nginx or Apache
# Set WEB_SERVER environment variable before running: WEB_SERVER=nginx or WEB_SERVER=httpd

WEB_SERVER="${WEB_SERVER:-nginx}"  # Default to nginx if not set

# Detect OS and install packages
if [ -f /etc/debian_version ]; then
    # Ubuntu/Debian
    apt-get update
    if [ "$WEB_SERVER" = "nginx" ]; then
        apt-get install -y nginx php-fpm php-cli
        WEB_ROOT="/var/www/html"
        PHP_SOCK="/run/php/php-fpm.sock"
    else
        apt-get install -y apache2 libapache2-mod-php php-cli
        a2enmod php8.*
        WEB_ROOT="/var/www/html"
    fi
elif [ -f /etc/redhat-release ]; then
    # Amazon Linux/RHEL
    if [ "$WEB_SERVER" = "nginx" ]; then
        yum install -y nginx php-fpm php-cli
        WEB_ROOT="/usr/share/nginx/html"
        PHP_SOCK="/run/php-fpm/www.sock"
    else
        yum install -y httpd php php-cli
        WEB_ROOT="/var/www/html"
    fi
fi

# Create PHP application
cat <<'EOF' > $WEB_ROOT/index.php
<?php
$hostname = gethostname();
$php_version = phpversion();
$server_software = $_SERVER['SERVER_SOFTWARE'] ?? 'Unknown';
?>
<!DOCTYPE html>
<html>
<head>
    <title>PHP Application</title>
</head>
<body>
    <h1>PHP Application</h1>
    <p><strong>Hostname:</strong> <?php echo htmlspecialchars($hostname); ?></p>
    <p><strong>PHP Version:</strong> <?php echo htmlspecialchars($php_version); ?></p>
    <p><strong>Web Server:</strong> <?php echo htmlspecialchars($server_software); ?></p>
    <p><strong>Script:</strong> <?php echo htmlspecialchars($_SERVER['SCRIPT_NAME']); ?></p>
</body>
</html>
EOF

# Create health check endpoint
cat <<'EOF' > $WEB_ROOT/health.php
<?php
header('Content-Type: application/json');
echo json_encode(['status' => 'healthy']);
?>
EOF

# Configure nginx if selected
if [ "$WEB_SERVER" = "nginx" ]; then
    cat <<EOF > /etc/nginx/conf.d/php-app.conf
server {
    listen 80 default_server;
    root $WEB_ROOT;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php\$ {
        fastcgi_pass unix:$PHP_SOCK;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
    # Remove default server block that conflicts
    rm -f /etc/nginx/sites-enabled/default
    rm -f /etc/nginx/conf.d/default.conf
    
    # Start services
    systemctl enable php-fpm nginx
    systemctl start php-fpm nginx
else
    # Apache configuration
    cat <<EOF > /etc/apache2/sites-available/000-default.conf 2>/dev/null || cat <<EOF > /etc/httpd/conf.d/php-app.conf
<VirtualHost *:80>
    DocumentRoot $WEB_ROOT
    
    <Directory $WEB_ROOT>
        AllowOverride All
        Require all granted
    </Directory>
    
    <FilesMatch \.php$>
        SetHandler application/x-httpd-php
    </FilesMatch>
    
    DirectoryIndex index.php index.html
</VirtualHost>
EOF
    
    # Start Apache
    systemctl enable httpd 2>/dev/null || systemctl enable apache2
    systemctl start httpd 2>/dev/null || systemctl start apache2
fi
