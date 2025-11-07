# TDK Test Manager Deployment

Contains TDK test manager tool deployment files

## Table of Contents

- [Overview](#overview)
- [Docker Setup](#docker-setup)
- [Quick Start](#quick-start)
- [Miscellaneous](#miscellaneous)


## Overview

This project uses Docker Compose to orchestrate multiple services including the backend application, frontend, and database.
It also contains the data dump and other release migration related configurations


## Docker Setup

This project uses Docker Compose to orchestrate multiple services including the backend application, frontend, and database.

### Prerequisites

Before running the application, ensure you have:

#### Environment

- **Ubuntu**: Version 24.04 is recommended

#### Softwares


- **Docker Engine**: Version 28.1 is recommended
- **Docker Compose**: Version 2.40.0 is recommended


#### Installing Docker and Docker compose on Ubuntu

If you don't have Docker installed, follow these steps:

```bash
# Update package index
sudo apt-get update

# Install required packages
sudo apt-get install ca-certificates curl

# Create directory for apt keyrings
sudo install -m 0755 -d /etc/apt/keyrings

# Add Docker's official GPG key
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker repository to apt sources
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package index again
sudo apt-get update

# Install Docker Engine and Docker Compose plugin
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Verify installation
docker --version
docker compose version
```

If the docker compose version is less than the recommended one, Please follow the below steps to get the exact version

```bash

#Direct Download via Curl

#Remove old Compose and create plugins directory:
sudo apt remove docker-compose -y
sudo mkdir -p /usr/libexec/docker/cli-plugins

#Download and install:
sudo curl -L "https://github.com/docker/compose/releases/download/v2.40.0/docker-compose-linux-x86_64" -o /usr/libexec/docker/cli-plugins/docker-compose
sudo chmod +x /usr/libexec/docker/cli-plugins/docker-compose

#Verify: 
docker compose version

```


### Docker Architecture

The Docker setup consists of three main services/containers:

- **tdk-frontend**: Angular application served by Nginx 
- **tdk-backend**: Spring Boot application on Tomcat 11 
- **mysql-db**: MySQL 8.4 database 

All services run on a shared Docker network (`tdk-net`) for internal communication.

## Quick Start

### 1. Switch to sudo user

```bash
sudo su
```

### 2. Clone this Repository

```bash
git clone https://github.com/rdkcentral/tdk-testmanager-deployment.git
cd tdk-testmanager-deployment

```
If you want to deploy a particular release tag, then checkout that using the below step

```bash
git checkout <Release tag>

cd docker

```

### 3. Configure Environment Variables


```bash
vi .env
```

Edit the `.env` file in the docker directory:

1. **Get your IP address**: Refer to the section [How to get IP of your ubuntu machine](#how-to-get-ip-of-your-ubuntu-machine) under Miscellaneous to get your IP.

2. **Update the BACKEND_URL**: Change backend URL from `http://localhost:8443/tdkservice/` to `http://{Your-IP}:8443/tdkservice/`




### 4. Change the permission of dumpfile and folder

```env

# Fix directory permissions
chmod 755 database/
chmod 755 database/init/

# Fix file permissions
chmod 644 database/init/tdk-master-data-dump.sql

```

### 5. Build and Start Services

```bash
docker compose build --no-cache && docker compose up -d
```

This  command will:
- Build all Docker images defined in your docker-compose.yml file,  ensuring a fresh build by ignoring any cached layers (--no-cache).
- Start all services defined in your docker-compose.yml file, running them in the detached mode (in the background, -d).
- Create and start the complete application stack based on your configuration.

### 4. Verify Application Startup

- **Frontend**: Open http://{IP}:8443 in your browser, you will be able to see the login screen

- **Backend API**: The backend API is proxied behind nginx, So the app is available in 8443 port under path tdkservice.
  - http://{IP}:8443/tdkservice/actuator/health - Use this endpoint to check if the app is up


### 5. Setup after Deployment


#### View docker containers


```Bash
docker ps -a
```

#### How to enter front end container

Enter front end docker container with the below command

```Bash
docker exec -it tdk-frontend bash
```

#### How to enter mysql db container

Enter front end docker container with the below command

```Bash
docker exec -it mysql-db bash
```



#### Configure backend service URL in the backend config and copy the fileStore(Copying the fileStore is a temporary step, it will be automated by October 2025 after the scripts and core open sourcing )


1. Copy the fileStore.zip share by the TDK tools team to your ubuntu VM

2. Copy the fileStore.zip to the backend docker container

```Bash
docker cp {source} tdk-backend:/mnt

#eg : docker cp /home/ajayan524/fileStore.zip tdk-backend:/mnt
```

3. Enter backend end docker container with the below command

```Bash
docker exec -it tdk-backend bash
```

4. Delete the existing fileStore in the deployment and copy the new fileStore in the deployment

```Bash
cd /mnt
rm -r /opt/tomcat/webapps/tdkservice/fileStore
cp fileStore.zip /opt/tomcat/webapps/tdkservice
cd /opt/tomcat/webapps/tdkservice
unzip fileStore.zip
```


5. Edit the config file to point to the backend URL.


```Bash
vi /opt/tomcat/webapps/tdkservice/fileStore/tm.config
```

6. Replace the tm URL value with your app URL

```Bash
tmURL=http://{IP}:8443/tdkservice/
```

The app should be ready to use now

## Miscellaneous

#### Stop all containers

If some thing went wrong during the initial setup and we want to build docker compose again, use the below and then run the build command.The command docker compose down stops and removes the containers, networks, and, by default, the volumes defined by your docker-compose.yml file.This flag tells Docker Compose to also remove all named volumes 

```Bash
docker compose down -v
```

#### Start and stop tomcat in backend container

Start and stop tomcat from docker container

```Bash
supervisorctl stop tomcat
supervisorctl start tomcat
```

Restart tomcat

```Bash
supervisorctl restart tomcat
```

#### Start and stop nginx in frontend container

Restart nginx

````
nginx -s reload

````



#### How to get IP of your ubuntu machine

**For same network access:**
```bash
# If you are going to access the test manager from the same network,
# run the below command to get your local IP
ifconfig

# Take IP address assigned to your VM's eth0 network interface
# Example output:
# eth0      Link encap:Ethernet  HWaddr D4:CF:F9:49:E8:C9
#           inet addr:192.168.162.65  Bcast:192.168.162.255  Mask:255.255.255.0
```

**For external network access:**
```bash
# If you are going to access the test manager from another network, 
# get the public IP by running the below command
curl ifconfig.me
```








 


