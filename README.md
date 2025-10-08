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

- **Ubuntu**: Version 24.X or higher is recommended

#### Softwares


- **Docker Engine**: Version 28.1.X or higher
- **Docker Compose**: Version 2.35.X or higher


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
git clone <repository-url>
cd tdk-testmanager-deployment/docker
```

### 3. Configure Environment Variables
```bash
vi .env
```

Edit`.env` file in the docker  directory:

Add values for MYSQL_ROOT_PASSWORD, MYSQL_PASSWORD and BACKEND_URL

(PS : Please add MYSQL_ROOT_PASSWORD and MYSQL_PASSWORD as 'root' for now, as the parametrization of these are in progress in the backend container )

Change backend URL from http://localhost:8080 to http://<IP>:8443/tdkservice/. 

```env
# Database Configuration
MYSQL_ROOT_PASSWORD=
MYSQL_DATABASE=tdktestmanagerproddb
MYSQL_USER=tdktestuser
MYSQL_PASSWORD=

# Backend URL for Frontend
BACKEND_URL=http://localhost:8080/
```

### 4. Change the permission of dumpfile

```env

chmod 655 database/init/tdk-master-data-dump.sql

```


### 5. Build and Start Services

```bash
docker compose build --no-cache && docker compose up -d
```

This single command will:
- Load environment variables from `.env` file
- Build all Docker images
- Start all services in detached mode
- Create the complete application stack

### 4. Verify Application Startup
- **Frontend**: Open http://localhost:8443 or  http://{IP}:8443 in your browser, you will be able to see the login screen
- **Backend API**: The backend API is proxied behind nginx, So the app is available in 8443 port under path tdkservice
  - http://localhost:8443/tdkservice - Main API endpoint
  - http://localhost:8443/tdkservice/actuator/health / http://{IP}:8443/tdkservice/actuator/health - Use this endpoint to check if the app is up



### 5. Setup after Deployment


#### View docker containers


```Bash
docker ps -a
```

#### Configure backend service URL in the front end service

1. Enter front end docker container with the below command

```Bash
docker exec -it tdk-frontend bash
```

2. Edit the config file to point to the backend URL. 


```Bash
vi /var/www/html/assets/config.json
```

3. Replace the URL with http://<IP of your ubuntu VM>:8443/tdkservice. 

```Bash
  {
    "apiUrl": "http://<IP>:8443/tdkservice/",
    "nodeApiUrl":""
  }

```

#### Configure backend service URL in the backend config and copy the fileStore(Copying the fileStore is a temporary step, it will be automated by Oct 25)


1. Copy the fileStore.zip share by the TDK tools team to your ubuntu VM

2. Copy the fileStore.zip to the backend docker container

```Bash
docker cp /home/ajayan524/fileStore.zip tdk-backend:/mnt
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
tmURL=http://<IP>:8443/tdkservice/
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

#### Start and stop tomcat in backend container

Restart nginx

````
nginx -s reload

````








 


