#!/bin/bash

## Prompt User for FQDN
read -p "Enter FQDN of service (e.g pihole.example.com): " FQDN

## Run script to generate certificates
openssl genrsa -out $FQDN.key 4096 2>/dev/null
openssl req -new -key $FQDN.key -out $FQDN.csr -config server.cfg 2>/dev/null
openssl x509 -req -days 365 -in $FQDN.csr -signkey $FQDN.key -out $FQDN.crt 2>/dev/null