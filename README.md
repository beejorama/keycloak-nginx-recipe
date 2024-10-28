# keycloak-nginx-recipe
Instructions on how to manually install and configure Keycloak, nginx and certbot on Rocky Linux 9.

These instructions are based on using a 1 CPU, 1GB memory VM running on Digital Ocean.

**To do:**
- Run Keycloak as a service
- Add steps to create permanent admin user and delete temporary user
- Update nginx config to only expose admin endpoints to a limited source IP
- Investigate certificate permission requirements

## Set up initial server config
https://www.digitalocean.com/community/tutorials/initial-server-setup-with-rocky-linux-9

## Set up enhanced metrics
https://docs.digitalocean.com/products/monitoring/how-to/install-agent/

## Install nginx
https://www.digitalocean.com/community/tutorials/how-to-install-nginx-on-rocky-linux-9

Note - this includes installing and configuring firewalld. Add http and https to permanent list.

## Configure nginx
Create the following file: `etc/nginx/conf.d/{your domain}.conf`, replacing `{your domain}` with your actual domain (e.g. example.com).

Paste the following into it, again, replacing the `{your domain}` placeholder.

```
server {
    listen          443 ssl;
    server_name     {your domain};

	# sets the SSL certs to use
    ssl_certificate         /etc/letsencrypt/live/{your domain}/fullchain.pem;
    ssl_certificate_key     /etc/letsencrypt/live/{your domain}/privkey.pem;

    location / {
        # sets the headers which are needed for keycloak to construct the correct redirect URLs
        proxy_set_header        X-Forwarded-For $remote_addr;
        proxy_set_header        Host $http_host;
        proxy_pass              https://0.0.0.0:8443;
    }
}
```

## Install certbot
Note - when I used certbot I used the `--standalone` argument, however I believe using the `--nginx` argument would be better in conjunction with `certonly`, as we don't want certbot to alter our nginx configuration.

https://www.digitalocean.com/community/tutorials/how-to-secure-nginx-with-let-s-encrypt-on-rocky-linux-9

## Install openjdk
This is required for the Keycloak bare-metal installation.

```
sudo dnf install java-21-openjdk.x86_64
```

## Download keycloak, copy and unzip to /opt
```
cd /opt
curl https://github.com/keycloak/keycloak/releases/download/26.0.2/keycloak-26.0.2.zip -O -J -L
sudo dnf install unzip
unzip keycloak-26.0.2.zip
```

## Update permissions on LetsEncrypt certificate folders (need to confirm if this is needed)
Various threads asking for help have answers where they suggest using 744 permissions on the certificates. I still need to confirm whether this is necessary.

In my first installation I ended up using 744 on archive (recursively) and live/{your domain}

## Update /opt/keycloak-26.0.2/conf/keycloak.conf
```
# Adapted the sample production config file.

# Database
# Use dev-file for small, single node instance.
db=dev-file

# Observability
# If the server should expose healthcheck and metric endpoints.
#health-enabled=true
#metrics-enabled=true

# HTTP
# The file path to a server certificate or certificate chain in PEM format.
https-certificate-file=/etc/letsencrypt/live/{your domain}/fullchain.pem

# The file path to a private key in PEM format.
https-certificate-key-file=/etc/letsencrypt/live/{your domain}/privkey.pem

# Proxy settings
proxy-headers=xforwarded

# Hostname for the Keycloak server.
hostname={your domain}
```

## Add environment variables for temp admin user
When you first start Keycloak it creates a temporary admin user in order to set up fully. This is only intended to be a temporary admin user, and should be removed as soon as the user has created a more permanent admin user.

Keycloak documentation suggests various ways of declaring the credentials, however it's easy enough to add them as environment variables.

Replace `{username}` and `{password}` in the following snippet with the credentials you want to use.

```
sudo export KC_BOOTSTRAP_ADMIN_USERNAME={username}
sudo export KC_BOOTSTRAP_ADMIN_PASSWORD={password}
```

## Build and run Keycloak
We have got our required configuration in the `/opt/keycloak-26.0.2/conf/keycloak.conf` and our temporary admin credentials in the environment variables. We are ready to run Keycloak.

I have opted to build Keycloak before running it, which is supposed to reduce the startup time. This doesn't matter too much given this is a single node instance and it's only being used for a small user base.

```
# Build then run
sudo /opt/keycloak-26.0.2/bin/kc.sh build
sudo /opt/keycloak-26.0.2/bin/kc.sh start --optimized

# Alternatively build every time we run
sudo /opt/keycloak-26.0.2/bin/kc.sh start
```