#!/bin/bash

## Variables
ip_addr=$(hostname -I | awk '{print $1}')
services=("iris" "pihole" "mattermost" "pan" "cyberchef" "gostatic" "mkdocs")
base_domain=""
username=""
password=""
salt1=$(openssl rand -base64 64)
salt2=$(openssl rand -base64 64)
salt3=$(openssl rand -base64 64)

## Stop script from running as root
if [ "$EUID" -eq 0 ]; then
  echo "This script must not be run as root or with sudo. Exiting."
  exit 1
fi

## Display a prompt if the domain is not provided
prompt_for_domain() {
    if [ -z "$base_domain" ]; then
        read -p "Please enter the base domain (i.e. test.local): " base_domain
    fi
}

## Display a prompt if the username is not provided
# prompt_for_username() {     # Commented out to disable username prompting
#     if [ -z "$username" ]; then
#         read -p "Please enter an admin username: " username
#     fi
# }

## Command line options for -d or --domain and -u or --username
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--domain)
            base_domain="$2"
            shift 2
            ;;
        # -u|--username)   # Commented out to disable username prompting
        #     username="$2"
        #     shift 2
        #     ;;
        *)
            shift
            ;;
    esac
done

## If no domain is provided via -d, prompt the user
prompt_for_domain

## If no username is provided via -u, prompt the user
# prompt_for_username   # Commented out to disable username prompting

## Prompt the user for a password
read_password() {
    read -sp "Enter an admin password: " password
    echo
}
read_password

# Ask the user to verify the password
read -sp "Verify admin password: " verify_password
echo

# Check if both passwords match
if [ "$password" != "$verify_password" ]; then
    echo "Passwords do not match. Please try again."
    read_password
fi
touch password.txt
echo "$password" >> password.txt
clear

## Preparations
echo -e "y\n" | sudo apt-get install docker.io docker-compose easy-rsa 2>/dev/null
sudo docker swarm init
clear

# Function to remove all .gitkeep files
remove_gitkeep() {
  # Search for .gitkeep files and remove them
  find "$1" -type f -name ".gitkeep" -exec rm -f {} \; -print
}
remove_gitkeep .

## Put the password into a docker secret
echo "$password" | docker secret create password -

## Change ownership for Mattermost files
sudo chown -R 2000:2000 ./volumes/app/mattermost

## Add variables to corresponding files
sed -i "s/<BASE_DOMAIN>/$base_domain/g" ./data/pan/pan_config.yml
sed -i "s/<BASE_DOMAIN>/$base_domain/g" ./data/proxy/default.conf
sed -i "s/<BASE_DOMAIN>/$base_domain/g" ./data/env.tmp
sed -i "s/<SALT1>/$salt1/g" ./data/env.tmp
sed -i "s/<SALT2>/$salt2/g" ./data/env.tmp
sed -i "s/<SALT3>/$salt3/g" ./data/env.tmp
mv ./data/env.tmp ./.env

## Docker pull needs to occur before disabling resolved
sudo docker-compose pull

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

## Move Certificates to Proxy
mv ./pki/issued/*.crt ../data/proxy/ssl
mv ./pki/private/*.key ../data/proxy/ssl
mv ../data/proxy/ssl/ca.key ./pki/private
mv ./pki/ca.crt ../data/gostatic
cd ..
sudo chmod -R 755 ./data/gostatic

## Run the docker compose file
sudo docker-compose up -d
rm -f password.txt

## Move custom PiHole block list and run pihole command
gunzip ./data/pihole/gravity.db.gz
mv ./data/pihole/gravity.db etc-pihole/
sudo docker exec pihole chown pihole:pihole /etc/pihole/gravity.db
sudo docker exec pihole chmod 644 /etc/pihole/gravity.db

## Create custom DNS resolution for pihole
sed -i "s/<IP_ADDR>/$ip_addr/g" ./data/pihole/custom.list
sed -i "s/<BASE_DOMAIN>/$base_domain/g" ./data/pihole/custom.list
sudo rm -f ./etc-pihole/custom.list
mv ./data/pihole/custom.list ./etc-pihole/
sudo docker exec pihole pihole -g
clear

## Modify Iris search functionality to be case insensitive
sudo docker exec -it iriswebapp_app bash -c "sed -i.bak 's|\.like|\.ilike|g' /iriswebapp/app/blueprints/search/search_routes.py"

## Output randomly generated Iris password
iris_password=$(docker-compose logs app | grep "WARNING :: post_init :: create_safe_admin" | sed -E 's/.*Administrator password: ([^ ]*).*/\1/')
echo "Iris Credentials (CHANGE THESE IMMEDIATELY)"
echo "Username: administrator"
echo "Password: $iris_password"
sudo docker restart iriswebapp_app
