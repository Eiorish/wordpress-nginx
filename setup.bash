#!/bin/bash

# WordPress Docker Setup Script
# This script automates the complete setup of WordPress with Nginx and MySQL

set -e  # Exit on any error

echo "========================================"
echo "WordPress Docker Setup Script"
echo "========================================"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "Error: Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Create project directory
PROJECT_DIR="wordpress-docker"
echo "Creating project directory: $PROJECT_DIR"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Generate random passwords
DB_ROOT_PASSWORD=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 24)
DB_PASSWORD=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 24)

echo "Generated secure passwords for database"

# Create docker-compose.yml
echo "Creating docker-compose.yml..."
cat > docker-compose.yml <<'EOF'
version: '3.8'

services:
  db:
    image: mysql:8.0
    container_name: wordpress_db
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${DB_ROOT_PASSWORD}
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wordpress
      MYSQL_PASSWORD: ${DB_PASSWORD}
    volumes:
      - db_data:/var/lib/mysql
    networks:
      - wordpress_network
    command: '--default-authentication-plugin=mysql_native_password'
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5

  wordpress:
    image: wordpress:fpm-alpine
    container_name: wordpress_php
    restart: unless-stopped
    user: "82:82"
    environment:
      WORDPRESS_DB_HOST: db:3306
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: ${DB_PASSWORD}
      WORDPRESS_DB_NAME: wordpress
      WORDPRESS_CONFIG_EXTRA: |
        define('FS_METHOD', 'direct');
    volumes:
      - wordpress_data:/var/www/html
      - ./php.ini:/usr/local/etc/php/conf.d/custom.ini:ro
    networks:
      - wordpress_network
    depends_on:
      db:
        condition: service_healthy

  nginx:
    image: nginx:alpine
    container_name: wordpress_nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - wordpress_data:/var/www/html:ro
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
    networks:
      - wordpress_network
    depends_on:
      - wordpress

volumes:
  db_data:
    driver: local
  wordpress_data:
    driver: local

networks:
  wordpress_network:
    driver: bridge
EOF

# Create .env file
echo "Creating .env file with credentials..."
cat > .env <<EOF
DB_ROOT_PASSWORD=$DB_ROOT_PASSWORD
DB_PASSWORD=$DB_PASSWORD
EOF

# Create nginx.conf
echo "Creating Nginx configuration..."
cat > nginx.conf <<'EOF'
server {
    listen 80;
    server_name localhost;
    
    root /var/www/html;
    index index.php index.html index.htm;
    
    client_max_body_size 100M;
    
    location / {
        try_files $uri $uri/ /index.php?$args;
    }
    
    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass wordpress:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
        fastcgi_buffering off;
        fastcgi_read_timeout 300;
    }
    
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires max;
        log_not_found off;
        access_log off;
    }
    
    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }
    
    location = /robots.txt {
        log_not_found off;
        access_log off;
        allow all;
    }
    
    location ~* \.(htaccess|htpasswd)$ {
        deny all;
    }
}
EOF

# Create php.ini
echo "Creating PHP configuration..."
cat > php.ini <<'EOF'
upload_max_filesize = 100M
post_max_size = 100M
max_execution_time = 300
max_input_time = 300
memory_limit = 256M
EOF

# Create .gitignore
echo "Creating .gitignore..."
cat > .gitignore <<'EOF'
.env
EOF

# Create README
echo "Creating README.md..."
cat > README.md <<'EOF'
# WordPress Docker Setup

## Description
This setup runs WordPress with:
- **Nginx** as the web server
- **PHP-FPM** for PHP processing
- **MySQL 8.0** as the database

## Security Features
- Both Nginx and PHP-FPM run as user 82:82 (www-data), eliminating permission issues
- Database credentials are randomly generated and stored in .env
- WordPress files are read-only for Nginx
- No 777 permissions needed

## Quick Start

1. Start the containers:
```bash
docker-compose up -d
```

2. Wait for containers to be ready (about 30 seconds)

3. Visit http://localhost and complete WordPress installation

## Management Commands

**View logs:**
```bash
docker-compose logs -f
```

**Stop containers:**
```bash
docker-compose down
```

**Stop and remove volumes (WARNING: deletes all data):**
```bash
docker-compose down -v
```

**Restart containers:**
```bash
docker-compose restart
```

**Access WordPress container:**
```bash
docker exec -it wordpress_php sh
```

**Access database:**
```bash
docker exec -it wordpress_db mysql -u wordpress -p
```

## File Structure
- `docker-compose.yml` - Container orchestration
- `nginx.conf` - Nginx configuration
- `php.ini` - PHP settings
- `.env` - Database credentials (keep secret!)

## Backup

**Backup WordPress files:**
```bash
docker run --rm -v wordpress-docker_wordpress_data:/data -v $(pwd):/backup alpine tar czf /backup/wordpress-backup.tar.gz -C /data .
```

**Backup database:**
```bash
docker exec wordpress_db mysqladmin -u root -p${DB_ROOT_PASSWORD} ping
docker exec wordpress_db mysqldump -u wordpress -p${DB_PASSWORD} wordpress > wordpress-db-backup.sql
```

## Troubleshooting

**Check container status:**
```bash
docker-compose ps
```

**View specific container logs:**
```bash
docker-compose logs nginx
docker-compose logs wordpress
docker-compose logs db
```

**Restart a specific service:**
```bash
docker-compose restart wordpress
```
EOF

echo ""
echo "========================================"
echo "Setup Complete!"
echo "========================================"
echo ""
echo "Files created in: $(pwd)"
echo ""
echo "Database credentials (saved in .env):"
echo "  Root Password: $DB_ROOT_PASSWORD"
echo "  WordPress DB Password: $DB_PASSWORD"
echo ""
echo "Next steps:"
echo "  1. cd $PROJECT_DIR"
echo "  2. docker-compose up -d"
echo "  3. Wait 30 seconds for containers to initialize"
echo "  4. Visit http://localhost"
echo ""
echo "View logs: docker-compose logs -f"
echo "Stop: docker-compose down"
echo ""
echo "IMPORTANT: Keep the .env file secure and don't commit it to version control!"
echo ""
