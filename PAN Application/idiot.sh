#!/bin/bash

ip_addr=$(hostname -I | awk '{print $1}')

## Stop script from running as root
if [ "$EUID" -eq 0 ]; then
  echo "This script must not be run as root or with sudo. Exiting."
  exit 1
fi

## Change ownership for Mattermost files
sudo chown -R 2000:2000 ./volumes/app/mattermost

## Prompt user for a base domain
read -p "Enter your base domain (i.e. test.local): " base_domain

## Docker pull needs to occur before disabling resolved
docker-compose pull

## Change Iris Docker Permissions
#sudo chown -R 1000:1000 /var/lib/docker/volumes/pan_server_data/_data/custom_assets

## Disable systemd-resolved and rewrite resolv.conf
sudo systemctl disable systemd-resolved.service
sudo systemctl stop systemd-resolved.service
sudo unlink /etc/resolv.conf
touch ~/resolv.conf
echo "#nameserver 127.0.0.53" >> ~/resolv.conf
sudo cp ~/resolv.conf /etc
rm -f ~/resolv.conf

## Generate SSL Certificates for your services
mkdir ~/openssl
mv server.cfg ~/openssl
cd ~/openssl

## PiHole
openssl genrsa -out pihole.$base_domain.key 4096 2>/dev/null
openssl req -new -key pihole.$base_domain.key -out pihole.$base_domain.csr -config server.cfg 2>/dev/null
openssl x509 -req -days 365 -in pihole.$base_domain.csr -signkey pihole.$base_domain.key -out pihole.$base_domain.crt 2>/dev/null

## NPM
openssl genrsa -out npm.$base_domain.key 4096 2>/dev/null
openssl req -new -key npm.$base_domain.key -out npm.$base_domain.csr -config server.cfg 2>/dev/null
openssl x509 -req -days 365 -in npm.$base_domain.csr -signkey npm.$base_domain.key -out npm.$base_domain.crt 2>/dev/null

## Mattermost
openssl genrsa -out mm.$base_domain.key 4096 2>/dev/null
openssl req -new -key mm.$base_domain.key -out mm.$base_domain.csr -config server.cfg 2>/dev/null
openssl x509 -req -days 365 -in mm.$base_domain.csr -signkey mm.$base_domain.key -out mm.$base_domain.crt 2>/dev/null

## PAN Landing Page
openssl genrsa -out pan.$base_domain.key 4096 2>/dev/null
openssl req -new -key pan.$base_domain.key -out pan.$base_domain.csr -config server.cfg 2>/dev/null
openssl x509 -req -days 365 -in pan.$base_domain.csr -signkey pan.$base_domain.key -out pan.$base_domain.crt 2>/dev/null

## Run the docker compose file
cd ~/pan
docker-compose up -d 
docker-compose up -d


## Move custom PiHole block list and run pihole command
mv gravity.db etc-pihole/
docker exec pihole chown pihole:pihole /etc/pihole/gravity.db
docker exec pihole chmod 644 /etc/pihole/gravity.db
docker exec pihole pihole -g

## Create custom DNS resolution for pihole
touch custom.list
echo "$ip_addr pihole.$base_domain" >> custom.list
echo "$ip_addr npm.$base_domain" >> custom.list
echo "$ip_addr mattermost.$base_domain" >> custom.list
echo "$ip_addr iris.$base_domain" >> custom.list
echo "$ip_addr pan.$base_domain" >> custom.list
sudo rm -f etc-pihole/custom.list
mv custom.list etc-pihole/
