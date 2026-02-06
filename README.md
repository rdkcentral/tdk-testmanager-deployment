# TDK Test Manager Deployment

Contains TDK test manager tool deployment files

## Table of Contents

- [Overview](#overview)
- [Docker Setup](#docker-setup)
- [Quick Start](#quick-start)
- [Miscellaneous](#miscellaneous)


## Overview

This project uses Docker Compose to orchestrate multiple services including the backend application, frontend, and database for tdk-testmanager. It also contains the data dump and other release migration related configurations


## Docker Setup

This project uses Docker Compose to orchestrate multiple services including the backend application, frontend, and database.

### Prerequisites

Before running the application, ensure you have:

#### Environment

- **Ubuntu**: Version 24.04 is recommended

#### Softwares

Recommended and Verified versions are given below. Higher versions may work but are not verified
- **Docker Engine**: Version 28.1 is recommended 
- **Docker Compose**: Version 2.40.0 is recommended


#### Installing Docker and Docker compose on Ubuntu

Please follow these steps to install docker, this will install the docker version - 28.1 and docker compose version
- 2.40.0:

##### 1. Clone this Repository and Install Docker

```bash
git clone https://github.com/rdkcentral/tdk-testmanager-deployment.git
cd tdk-testmanager-deployment
```


##### 2.  Install Docker and Docker Compose

```bash
cd docker
sudo ./install-docker.sh

```

#### 3. Check docker and docker compose version

```bash
docker --version        # Should show: Docker version 28.1.0
docker compose version  # Should show: Docker Compose version v2.40.0
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


### 5. Accesing containers after deployment

#### View docker containers


```Bash
docker ps -a
```


#### How to enter tdk-frontend container

Enter front-end docker container with the below command

```Bash
docker exec -it tdk-frontend bash
```

#### How to enter mysql-db container

Enter mysql-db docker container with the below command

```Bash
docker exec -it mysql-db bash
```


#### How to enter tdk-backend container

Enter front end docker container with the below command

```Bash
docker exec -it mysql-db bash
```





## Miscellaneous

#### Stop all containers

If some thing went wrong during the initial setup and we want to build docker compose again, use the below and then run the build command.The command docker compose down stops and removes the containers, networks, and, by default, the volumes defined by your docker-compose.yml file.This flag tells Docker Compose to also remove all named volumes. Use this only during intial setup when you dont have any data in the volume

```Bash
cd tdk-testmanager-deployment/docker
docker compose down -v
```

#### Start and stop tomcat in backend container

##### Start and stop tomcat from docker container

```Bash
supervisorctl stop tomcat
supervisorctl start tomcat
```

##### Restart tomcat

```Bash
supervisorctl restart tomcat
```

##### Start and stop nginx in frontend container

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
## Volumes Usage

We use Docker volumes in the `docker-compose.yml` file to persist data and files across container restarts and rebuilds.

```yaml
volumes:
  mysql-data:
  backend-webapps:
  frontend-html:
```

### Purpose

* **`mysql-data`** → Stores MySQL database data so it remains intact even after container rebuilds.
* **`backend-webapps`** → Keeps backend build artifacts, logs, and configuration files persistent.
* **`frontend-html`** → Stores built frontend files (HTML, CSS, JS) used by Nginx.

### Behavior

* During the **initial setup**, these volumes are automatically created when running:

  ```bash
  docker compose up -d
  ```
* Once created, Docker automatically reuses the existing volume data during future builds or image recreations.
* This ensures that any database data or generated files remain available even after rebuilding containers.

### Benefits

* Data persists across rebuilds and restarts.
* Faster development setup — no need to reimport or rebuild.
* Safe updates without losing existing files or configurations.
* Makes containers behave more like long-lived environments.

### To Reset Volumes

If you need to start fresh and remove stored data:

```bash
docker compose down -v
```







 


