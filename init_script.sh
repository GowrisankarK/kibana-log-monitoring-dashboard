#!/bin/bash

# Check if required environment variables are set
if [ -z "$KIBANA_DOMAIN_NAME" ]; then
  echo "KIBANA_DOMAIN_NAME is not set. Exiting."
  exit 1
fi

if [ -z "$KIBANA_USERNAME" ]; then
  echo "KIBANA_USERNAME is not set. Exiting."
  exit 1
fi

if [ -z "$KIBANA_PASSWORD" ]; then
  echo "KIBANA_PASSWORD is not set. Exiting."
  exit 1
fi

if [ -z "$ELASTICSEARCH_INDEX" ]; then
  echo "ELASTICSEARCH_INDEX is not set. Exiting."
  exit 1
fi

# Log the environment variables to confirm they are set
echo "KIBANA_DOMAIN_NAME=${KIBANA_DOMAIN_NAME}"
echo "KIBANA_USERNAME=${KIBANA_USERNAME}"
echo "KIBANA_PASSWORD=${KIBANA_PASSWORD}"
echo "ELASTICSEARCH_INDEX=${ELASTICSEARCH_INDEX}"

# log file path
LOGFILE=/var/log/init_script.log

# Redirect stdout and stderr to the log file and console
exec > >(tee -a $LOGFILE) 2>&1

# Update and upgrade the system
sudo apt-get update
sudo apt-get upgrade -y

# Install necessary packages
sudo apt-get install -y apt-transport-https wget gnupg nginx certbot

# Add Elasticsearch GPG key and repository
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-7.x.list

# Verify installation of apache2-utils
if ! command -v htpasswd &> /dev/null; then
    echo "apache2-utils installation failed. Attempting reinstall..."
    sudo apt-get install -y apache2-utils
fi

# Update package list and install Elasticsearch and Kibana
sudo apt-get update
sudo apt-get install -y elasticsearch kibana

# Enable and start Elasticsearch and Kibana services
sudo systemctl enable elasticsearch
sudo systemctl start elasticsearch
sudo systemctl enable kibana
sudo systemctl start kibana

# Configure UFW to allow necessary ports
sudo ufw allow 22/tcp
sudo ufw allow 5601/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 9200/tcp
sudo ufw --force enable

# Create directories if they don't exist
sudo mkdir -p /etc/nginx/ssl/

echo certificate_creation

# Generate private key & certificate signing request (CSR)
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/kibana.key -out /etc/nginx/ssl/kibana.crt -subj "/CN=${KIBANA_DOMAIN_NAME}"

# Grant access
sudo chmod 600 /etc/nginx/ssl/kibana.key
sudo chmod 644 /etc/nginx/ssl/kibana.crt

# Configure Kibana to use SSL
sudo bash -c "cat << EOF > /etc/kibana/kibana.yml
server.host: '0.0.0.0'
server.port: 5601
server.basePath: '/kibana'
server.rewriteBasePath: true
EOF"

# Restart Kibana to apply configuration changes
sudo systemctl restart kibana

# Create directory for certificates
sudo mkdir -p /etc/nginx/sites-available

touch /etc/nginx/sites-available/${KIBANA_DOMAIN_NAME}

echo nginx_proxy_creation

export http_upgrade=$http_upgrade
export host=$host
export remote_addr=$remote_addr
export proxy_add_x_forwarded_for=$proxy_add_x_forwarded_for

# Create a configuration file with placeholders for environment variables
sudo -E bash -c 'cat << EOF > /etc/nginx/sites-available/${KIBANA_DOMAIN_NAME}
server {
    listen 80;
    server_name ${KIBANA_DOMAIN_NAME};

    # Redirect HTTP to HTTPS
    location / {
        return 301 https://\$host\$request_uri;
    }

    # HTTP support for Kibana
    location /kibana {
        auth_basic "Restricted Access";
        auth_basic_user_file /etc/nginx/.htpasswd;

        proxy_pass http://localhost:5601;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection upgrade;
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    # HTTP support for Elasticsearch
    location /elasticsearch/ {
        proxy_pass http://localhost:9200/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection upgrade;
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}

server {
    listen 443 ssl;
    server_name ${KIBANA_DOMAIN_NAME};

    ssl_certificate /etc/nginx/ssl/kibana.crt;
    ssl_certificate_key /etc/nginx/ssl/kibana.key;

    location /kibana {
        auth_basic "Restricted Access";
        auth_basic_user_file /etc/nginx/.htpasswd;

        proxy_pass http://localhost:5601;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection upgrade;
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Port 443;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location /elasticsearch/ {
        proxy_pass http://localhost:9200/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection upgrade;
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Port 443;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF'

echo password_creation

# Create a password file for basic authentication
sudo htpasswd -bc /etc/nginx/.htpasswd ${KIBANA_USERNAME} ${KIBANA_PASSWORD}

# Verify the contents of the password file
sudo cat /etc/nginx/.htpasswd

# Remove the existing symbolic link if exists
sudo rm -f /etc/nginx/sites-enabled/${KIBANA_DOMAIN_NAME}

# Create a new symbolic link
sudo ln -s /etc/nginx/sites-available/${KIBANA_DOMAIN_NAME} /etc/nginx/sites-enabled/

# Test Nginx configuration and restart Nginx
sudo nginx -t
sudo systemctl restart nginx

# Configure curl to ignore SSL verification
sudo bash -c 'echo "insecure" >> ~/.curlrc'

echo index_creation

# Elasticsearch index creation
curl --location --request PUT "http://${KIBANA_DOMAIN_NAME}/elasticsearch/${ELASTICSEARCH_INDEX}" \
--header 'Content-Type: application/json' \
--data '{
  "mappings": {
    "properties": {
      "timestamp": { "type": "date" },
      "message": { "type": "text" },
      "level": { "type": "keyword" }
    }
  }
}'

# Elasticsearch index view
curl --location "http://${KIBANA_DOMAIN_NAME}/elasticsearch/_cat/indices" | grep ${ELASTICSEARCH_INDEX}
