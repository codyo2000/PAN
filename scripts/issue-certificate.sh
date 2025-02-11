#!/bin/bash

# Prompt user for input
read -p "Enter service name: " service
read -p "Enter Base Domain: " base_domain
read -p "Enter IP address: " ip_addr
read -p "Enter port number: " port

# Define the file to modify
pan_config="../data/proxy/default.conf"
pihole_config="../etc-pihole/custom.list"

# Append new server block to the config file
echo "" >> "$pan_config"
echo "#$service" >> "$pan_config"
echo "server {" >> "$pan_config"
echo "    listen 443 ssl;" >> "$pan_config"
echo "    server_name $service.$base_domain;" >> "$pan_config"
echo "" >> "$pan_config"
echo "    ssl_certificate /etc/ssl/certs/nginx/$service.$base_domain.crt;" >> "$pan_config"
echo "    ssl_certificate_key /etc/ssl/certs/nginx/$service.$base_domain.key;" >> "$pan_config"
echo "" >> "$pan_config"
echo "    location / {" >> "$pan_config"
echo "        include /etc/nginx/includes/proxy.conf;" >> "$pan_config"
echo "        proxy_pass http://$ip_addr:$port/;" >> "$pan_config"
echo "        proxy_set_header Host \$host;" >> "$pan_config"
echo "        proxy_set_header X-Real-IP \$remote_addr;" >> "$pan_config"
echo "        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;" >> "$pan_config"
echo "        proxy_set_header X-Forwarded-Proto \$scheme;" >> "$pan_config"
echo "" >> "$pan_config"
echo "        # Disable SSL verification for the Iris backend" >> "$pan_config"
echo "        proxy_ssl_verify off;" >> "$pan_config"
echo "" >> "$pan_config"
echo "        # Enable WebSocket support" >> "$pan_config"
echo "        proxy_set_header Upgrade \$http_upgrade;" >> "$pan_config"
echo "        proxy_set_header Connection 'upgrade';" >> "$pan_config"
echo "    }" >> "$pan_config"
echo "}" >> "$pan_config"

# Change directory to CA directory and generate/sign certificates
cd ../$base_domain-CA
echo -e "\n" | ./easyrsa gen-req "$service.$base_domain" nopass >/dev/null 2>&1
echo -e "yes\n" | ./easyrsa sign-req server "$service.$base_domain" >/dev/null 2>&1

# Move the generated certificates to the proxy directory
cp ./pki/issued/$service.$base_domain.crt ../data/proxy/ssl
cp ./pki/private/$service.$base_domain.key ../data/proxy/ssl

## Modify the PiHole custom.list file
echo "$ip_addr $service.$base_domain" >> $pihole_config

## Restart docker containers
sudo docker restart proxy
sudo docker exec -it pihole pihole restartdns reload-lists