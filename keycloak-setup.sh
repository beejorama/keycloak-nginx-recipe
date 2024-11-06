#!/bin/bash

# install prereqs
echo 'Installing prereqs'
dnf install -yq nginx
dnf install -yq java-21-amazon-corretto
dnf install -yq certbot python3-certbot-nginx

# start and enable nginx
echo 'Starting nginx'
systemctl enable nginx
systemctl start nginx

# Create certbot cert
echo 'Creating LetsEncrypt certs with Certbot'
certbot certonly --nginx -d $1

# Create nginx configuration
echo """
server {
    listen          443 ssl;
    server_name     $1;

	# sets the SSL certs to use
    ssl_certificate         /etc/letsencrypt/live/$1/fullchain.pem;
    ssl_certificate_key     /etc/letsencrypt/live/$1/privkey.pem;

    location / {
        # sets the headers which are needed for keycloak to construct the correct redirect URLs
        proxy_set_header        X-Forwarded-For $remote_addr;
        proxy_set_header        Host $http_host;
        proxy_pass              https://0.0.0.0:8443;
    }
}
""" > /etc/nginx/conf.d/$1.conf

# Update certbot LetsEncrypt folder permissions to allow keycloak to work
echo 'Updating LetsEncrypt folder permissions'
chmod 755 /etc/letsencrypt

chmod 755 /etc/letsencrypt/archive
chmod 755 -R /etc/letsencrypt/archive/$1

chmod 755 /etc/letsencrypt/live
chmod 755 -R /etc/letsencrypt/live/$1

# Reload nginx
echo 'Reloading nginx'
systemctl reload nginx

# Downloading keycloak
curl https://github.com/keycloak/keycloak/releases/download/26.0.5/keycloak-26.0.5.zip -O -J -L --output-dir /opt
unzip /opt/keycloak-26.0.5.zip -d /opt

# Configure keycloak.conf
echo 'Configuring keycloak'
echo """
# /opt/keycloak-26.0.2/conf/keycloak.conf

# Database
# Use dev-file for small, single node instance
db=dev-file

# Cache
# Change cache from ispn (default in production mode) to local
cache=local

# HTTP
# The file path to a server certificate or certificate chain in PEM format
https-certificate-file=/etc/letsencrypt/live/$1/fullchain.pem

# The file path to a private key in PEM format
https-certificate-key-file=/etc/letsencrypt/live/$1/privkey.pem

# Proxy settings
proxy-headers=xforwarded

# Hostname for the Keycloak server
hostname=$1
""" > /opt/keycloak-26.0.5/conf/keycloak.conf

# Allow nginx to forward requests
echo 'Configuring httpd relay'
setsebool -P httpd_can_network_relay 1

# Build keycloak
echo 'Building keycloak'
/opt/keycloak-26.0.5/bin/kc.sh build

# Bootstrapping admin user
export KCBS_USER=$2
export KCBS_PASS=$3
/opt/keycloak-26.0.5/bin/kc.sh bootstrap-admin user --username:env KCBS_USER --password:env KCBS_PASS

# Set permissions on keycloak folder
adduser keycloak
chown keycloak: -R /opt/keycloak-26.0.5

# Create keycloak service
echo '''
[Unit]
Description=Keycloak
After=network.target

[Service]
User=keycloak
Group=keycloak
ExecStart=/opt/keycloak-26.0.5/bin/kc.sh start --optimized

[Install]
WantedBy=multi-user.target
''' > /etc/systemd/system/keycloak.service

# Enable and start keycloak service
systemctl enable keycloak
systemctl start keycloak