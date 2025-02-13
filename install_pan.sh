#!/bin/bash

## Stop script from running as root
if [ "$EUID" -eq 0 ]; then
  echo "This script must not be run as root or with sudo. Exiting."
  exit 1
fi

## Request sudo password
sudo -v
clear

## Welcome message
echo -e "\e[1;36m"

echo "  /#######   /######   /##   /##"
echo " | ##__  ## /##__  ## | ### | ##"
echo " | ##  \ ##| ##  \ ## | ####| ##"
echo " | #######/| ######## | ## ## ##"
echo " | ##____/ | ##__  ## | ##  ####"
echo " | ##      | ##  | ## | ##\  ###"
echo " | ##      | ##  | ## | ## \  ##"
echo " |__/      |__/  |__/ |__/  \__/"
echo ""

echo -e "\e[0m"

echo "Welcome to PAN - the Preconfigured Application Node!"
echo ""
echo "Think of it as a cybersecurity Swiss Army knife, but in Docker form."
echo "One container to rule them all, deploy them all, and defend them all."
echo ""
echo "Why PAN?"
echo "  • Because setting up security tools manually is too much hassle."
echo "  • Because you'd rather focus on security, not troubleshooting dependencies."
echo "  • Because Docker makes everything easier (most of the time)."
echo ""
echo "Start it up, dive in, and begin defending the important things!"
echo "If something breaks… well, let's just say it's a feature."
echo ""
read -p "Press Enter to begin the chaos..."
clear

## Display a prompt if the domain is not provided
prompt_for_domain() {
    if [ -z "$base_domain" ]; then
        read -p "Please enter the base domain (i.e. test.local): " base_domain
    fi
}

## Command line options for -d or --domain
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--domain)
            base_domain="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

## If no domain is provided via -d, prompt the user
prompt_for_domain

## Function to create randomly generated passwords
generate_password() {
    local password
    while true; do
        password=$(tr -dc 'A-Za-z0-9!@#$' < /dev/urandom | fold -w 20 | head -n 1)

        # Ensure password meets requirements: at least one uppercase, one digit, one symbol
        if [[ "$password" =~ [A-Z] && "$password" =~ [0-9] && "$password" =~ [!@#$] ]]; then
            echo "$password"
            return
        fi
    done
}

## Generate random password for Pi-hole
pihole_pw=$(generate_password)

## Generate PAN landing page password and hash it
pan_pw=$(generate_password)
pw_hash=$(echo -n "$pan_pw" | sha256sum | awk '{print $1}')

## Generate LDAP Passwords
ldap_password=$(generate_password)
ldap_ro_password=$(generate_password)

## Define Variables
ip_addr=$(hostname -I | awk '{print $1}')
services=("ssp" "ldap" "ldapadmin" "vaultwarden" "iris" "pihole" "mattermost" "pan" "cyberchef" "gostatic")
salt1=$(openssl rand -base64 64 | tr -d '\n')
salt2=$(openssl rand -base64 64 | tr -d '\n')
salt3=$(openssl rand -base64 64 | tr -d '\n')
ldap_base_dn=$(echo "$base_domain" | awk -F'.' '{for(i=1;i<=NF;i++) printf "dc=%s%s", $i, (i<NF ? "," : "")}')

## Define Colors
RED="\e[1;31m"
GREEN="\e[1;32m"
CYAN="\e[1;36m"
YELLOW="\e[1;33m"
NC="\e[0m" # No Color

## Installing Services
echo -n "Installing required services... "

# Run the installation command silently
echo -e "y\n" | sudo apt-get install -y docker.io docker-compose easy-rsa >/dev/null 2>&1

echo -e "${GREEN}Done${NC}"

## Moving ahd editing important files
echo -n "Rearranging the landscape... "

## Function to remove all .gitkeep files
remove_gitkeep() {
  find "$1" -type f -name ".gitkeep" -exec rm -f {} \; >/dev/null 2>&1
}

## Run all tasks in the background
remove_gitkeep .

sudo chown -R 2000:2000 ./volumes/app/mattermost >/dev/null 2>&1

sed -i "s/<BASE_DOMAIN>/$base_domain/g" ./data/pan/pan_config.yml
sed -i "s/<BASE_DOMAIN>/$base_domain/g" ./data/proxy/default.conf
sed -i "s/<BASE_DOMAIN>/$base_domain/g" ./data/env.tmp
sed -i "s/<BASE_DOMAIN>/$base_domain/g" ./scripts/issue_certificate.sh
sed -i "s/<PW_HASH>/$pw_hash/g" ./data/pan/pan_config.yml
sed -i "s|<LDAP_PW>|$(printf '%q' "$ldap_password")|g" ./data/env.tmp
sed -i "s|<LDAP_RO_PW>|$(printf '%q' "$ldap_ro_password")|g" ./data/env.tmp
sed -i "s|<LDAP_BASE_DN>|$(printf '%q' "$ldap_base_dn")|g" ./data/env.tmp
sed -i "s|<LDAP_PW>|$(printf '%q' "$ldap_password")|g" ./data/ssp/config.inc.php
sed -i "s|<LDAP_BASE_DN>|$(printf '%q' "$ldap_base_dn")|g" ./data/ssp/config.inc.php
sed -i "s|<SALT1>|$(printf '%q' "$salt1")|g" ./data/env.tmp
sed -i "s|<SALT2>|$(printf '%q' "$salt2")|g" ./data/env.tmp
sed -i "s|<SALT3>|$(printf '%q' "$salt3")|g" ./data/env.tmp

## Move file after all replacements are complete
wait
mv ./data/env.tmp ./.env >/dev/null 2>&1

## Wait for all background processes to finish
wait

echo -e "${GREEN}Done${NC}"

## Docker pull needs to occur before disabling resolved
echo "Pulling docker images"
echo -e "\n-------------------------------------\n"
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
echo -n "Generating SSL Certificates... "

for service in "${services[@]}"; do
    # Generate the certificate request for each service silently
    echo -e "\n" | ./easyrsa gen-req "$service.$base_domain" nopass >/dev/null 2>&1
    # Sign the certificate request with the CA silently
    echo -e "yes\n" | ./easyrsa sign-req server "$service.$base_domain" >/dev/null 2>&1
done

echo -e "${GREEN}Done${NC}"

## Copy Certificates to Proxy, GoStatic, and OpenLDAP
cp ./pki/issued/*.crt ../data/proxy/ssl
cp ./pki/private/*.key ../data/proxy/ssl
cp ../data/proxy/ssl/ca.key ./pki/private
cp ./pki/ca.crt ../data/gostatic
cp ./pki/ca.crt ../data/openldap/certs
cp ./pki/issued/ldap.* ../data/openldap/certs
cp ./pki/private/ldap.* ../data/openldap/certs
cd ..
sudo chmod -R 755 ./data/gostatic

## Run the docker compose file
sudo docker-compose up -d

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
echo "Please wait, configuring Iris..."
sudo docker exec -it iriswebapp_app bash -c "sed -i.bak 's|\.like|\.ilike|g' /iriswebapp/app/blueprints/search/search_routes.py"
sudo docker restart iriswebapp_app
echo "Done"
clear

## Change the PiHole web gui password
sudo docker exec -it pihole pihole -a -p "$pihole_pw"

## Echo default passwords to user
iris_password=$(docker-compose logs app | grep "Administrator password:" | sed -E 's/.*Administrator password: ([^ ]*).*/\1/')
clear
echo -e "${RED}Change these credentials IMMEDIATELY:${NC}\n"
echo -e "${CYAN}Iris Credentials${NC}"
echo -e "${YELLOW}Username:${NC} administrator"
echo -e "${YELLOW}Password:${NC} $iris_password"
echo -e "\n--------------------------------\n"

echo -e "${GREEN}Save these credentials. You will never see them again after this:${NC}\n"
echo -e "${CYAN}LDAP Admin Credentials${NC}"
echo -e "${YELLOW}Username:${NC} cn=admin,$ldap_base_dn"
echo -e "${YELLOW}Password:${NC} $ldap_password\n"

echo -e "${CYAN}LDAP Read Only Credentials${NC}"
echo -e "${YELLOW}Username:${NC} cn=readonly,$ldap_base_dn"
echo -e "${YELLOW}Password:${NC} $ldap_ro_password\n"

echo -e "${CYAN}PAN Landing Page Credentials${NC}"
echo -e "${YELLOW}Username:${NC} admin"
echo -e "${YELLOW}Password:${NC} $pan_pw\n"

echo -e "${CYAN}PiHole Credentials${NC}"
echo -e "${YELLOW}Password:${NC} $pihole_pw"
echo -e "\n--------------------------------\n"

## Erase passwords from .env file
sed -i 's/^LDAP_ADMIN_PASSWORD=.*/LDAP_ADMIN_PASSWORD=""/' ./.env
sed -i 's/^LDAP_READONLY_USER_PASSWORD=.*/LDAP_READONLY_USER_PASSWORD=""/' ./.env
