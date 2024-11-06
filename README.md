# keycloak-nginx-recipe

> ### Warning - script is functional but not polished
>
> 1. Does not use `firewalld` due to memory issues while testing on a different cloud provider, so firewall settings must be done in the cloud portal
> 1. A small amount of manual input is required, e.g. providing an email address to LetsEncrypt
> 1. No validation on the arguments
> 1. No error handling
> 1. Permissions may be too open on LetsEncrypt certificate folders

This script installs and configures Keycloak 26.0.5, with nginx acting as a reverse proxy and with certbot retrieving free SSL certificates from LetsEncrypt. The aim of the script was to make it easy to get an authentication server up and running in the cloud for personal projects with minimal cost.

The script has been run on an EC2 VM running Amazon Linux 2023 with 1 CPU and 1GB memory.

If you try to run this script with a different distro you may encounter issues, for example when trying to run it on Rocky 9 some of the packages needed `epel-release` installed in order to access them.

## Requirements
For the script to work the following must be met:
1. Port 80 is free and open to the internet (required by certbot to verify domain ownership)
1. Port 443 is free for nginx to use
1. You must be able to use `sudo`


## How to run

Copy the script into a file and run the following, replacing the parameters with your own.

```bash
sudo sh keycloak-setup.sh example.domain.com admin password
```

### Parameters
1. The (sub)domain
1. The bootstrapped admin user for Keycloak
1. The bootstrapped admin password for Keycloak