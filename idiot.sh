#!/bin/bash

## Variables
ip_addr=$(hostname -I | awk '{print $1}')
services=("pihole" "mattermost" "pan" "cyberchef" "gostatic" "mkdocs")

## Stop script from running as root
if [ "$EUID" -eq 0 ]; then
  echo "This script must not be run as root or with sudo. Exiting."
  exit 1
fi

## Preparations
echo -e "y\n" | sudo apt-get install easy-rsa 2>/dev/null
mv ./data/env.tmp ./.env
clear

## Change ownership for Mattermost files
sudo chown -R 2000:2000 ./volumes/app/mattermost

## Prompt user for a base domain
read -p "Enter your base domain (i.e. test.local): " base_domain

## Modify dashy yaml file
sed -i "s/<BASE_DOMAIN>/$base_domain/g" ./data/pan/pan_config.yml

## Modify proxy config file
sed -i "s/<BASE_DOMAIN>/$base_domain/g" ./data/proxy/default.conf

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

## Create Certificate Authority
mkdir $base_domain-CA
cd $base_domain-CA
cp -r /usr/share/easy-rsa/* .
./easyrsa init-pki 2>/dev/null
echo -e "\n" | ./easyrsa build-ca nopass 2>/dev/null

## Generate SSL Certificates
for service in "${services[@]}"; do
    # Generate the certificate request for each service
    echo -e "\n" | ./easyrsa gen-req "$service.$base_domain" nopass 2>/dev/null
    # Sign the certificate request with the CA
    echo -e "yes\n" | ./easyrsa sign-req server "$service.$base_domain" 2>/dev/null
done
echo "Certificates have been generated and signed for: ${services[@]}"

## Move Certificates to Proxy
mv pki/issued/*.crt ~/pan/data/proxy/ssl
mv pki/private/*.key ~/pan/data/proxy/ssl
mv pki/ca.crt ~/pan/data/gostatic
sudo chmod -R 755 ~/pan/data/gostatic

## Generate SSL Certificates (OLD)
#cd ~/pan/data/proxy/ssl

# Loop through each service to generate certificates
#for service in "${services[@]}"; do
#    openssl genrsa -out "$service.$base_domain.key" 4096 2>/dev/null
#    openssl req -new -key "$service.$base_domain.key" -out "$service.$base_domain.csr" -config server.cfg 2>/dev/null
#    openssl x509 -req -days 365 -in "$service.$base_domain.csr" -signkey "$service.$base_domain.key" -out "$service.$base_domain.crt" 2>/dev/null
#    rm -f "$service.$base_domain.csr"
#done
#rm -f server.cfg
#echo "Certificates have been generated for: ${services[@]}"

## Run the docker compose file
cd ~/pan
docker-compose up -d 
docker-compose up -d


## Move custom PiHole block list and run pihole command
gunzip gravity.db.gz
mv gravity.db etc-pihole/
docker exec pihole chown pihole:pihole /etc/pihole/gravity.db
docker exec pihole chmod 644 /etc/pihole/gravity.db

## Create custom DNS resolution for pihole
sed -i "s/<IP_ADDR>/$ip_addr/g" ./custom.list
sed -i "s/<BASE_DOMAIN>/$base_domain/g" ./custom.list
sudo rm -f etc-pihole/custom.list
mv custom.list etc-pihole/
docker exec pihole pihole -g
