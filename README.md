# TDK Test Manager Deployment

This repository contains deployment configurations for the TDK Test Manager application.


### Table of Contents

- [Overview](#overview)
- [Application setup](#Application-setup)
- [Miscellaneous](#Miscellaneous)


## Overview

This project uses Docker Compose to orchestrate multiple services including the backend application, frontend, and database for tdk-testmanager. It also contains the data dump and other release migration related configurations


## Application-Setup

This project uses Docker Compose to orchestrate multiple services including the backend application, frontend, and database.

### Environment

Before proceeding, ensure you have:

 **Ubuntu**: Version 24.04 is recommended and verfied


### Docker installation and app startup

Please follow these steps to install docker, this will install the docker version - 28.1 and docker compose version 2.40.0:


#### 1. Switch to sudo user

```bash
sudo su
```

#### 2. Clone this Repository and checkout the release tag

Clone the repository

```bash
git clone https://github.com/rdkcentral/tdk-testmanager-deployment.git
cd tdk-testmanager-deployment

```

Checkout the release tag

```bash
git checkout <Release tag>
cd docker
```

#### 3. Configure the env file with the app url

```bash
vi .env
```

Edit the `.env` file in the docker directory:

1. *Get your IP address* : Refer to the section [How to get IP of your ubuntu machine](#how-to-get-ip-of-your-ubuntu-machine) under Miscellaneous to get your IP.

2. *Update the BACKEND_URL* : Change backend URL from `http://localhost:8443/tdkservice/` to `http://{Your-IP}:8443/tdkservice/`

Example : If your IP is 192.168.162.65, backend url should be changed like this

```bash
BACKEND_URL=http://192.168.162.65:8443/tdkservice/

```


#### 4.  Install/Reinstall Docker , Docker Compose and Launch application

Run the script *install_docker_and_launch.sh*. This will install the required version of docker and bring up the application

```bash
sudo ./install_docker_and_launch.sh 2>&1 | tee app-launch.log

```

##### What to expect :

- The script checks if Docker 28.1.X and Docker Compose 2.40.X are installed on your system
- If versions are correct:
  - A confirmation message is displayed
  - Application launch begins automatically
- If versions are incorrect or missing:
  - Current and recommended versions are displayed
  - You will be prompted: Do you want to (re)install the recommended Docker versions? (Y/N)
  - Enter Y to remove existing Docker and install recommended versions
  - Enter N to skip installation and continue with current versions (warning will be shown)
- Application containers will be built and started (first run may take several minutes)
- A success message confirms the application is running
- All output is saved to app-launch.log for troubleshooting

#### 5 . Verify Application Startup

- **Frontend**: Open *http://{IP}:8443* in your browser, you will be able to see the login screen

*Example : http://192.168.162.65:8443*

- **Backend API**: The backend API is proxied behind nginx, So the app is available in 8443 port under path tdkservice.
  - http://{IP}:8443/tdkservice/actuator/health - Use this endpoint to check if the app is up
  - The restapi will return the app health status like given below:
  ```bash
    {"status":"UP"}
     ```


*Example : http://192.168.162.65:8443/tdkservice/actuator/health*



## Miscellaneous


### Docker Architecture

The Docker setup consists of three main services/containers:

- **tdk-frontend**: Angular application served by Nginx 
- **tdk-backend**: Spring Boot application on Tomcat 11 
- **mysql-db**: MySQL 8.4 database 

All services run on a shared Docker network (`tdk-net`) for internal communication.



### Accessing containers after deployment

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


### Stop all containers

If some thing went wrong during the initial setup and we want to build docker compose again, use the below and then run the build command.The command docker compose down stops and removes the containers, networks, and, by default, the volumes defined by your docker-compose.yml file.This flag tells Docker Compose to also remove all named volumes. Use this only during intial setup when you dont have any data in the volume

```Bash
cd tdk-testmanager-deployment/docker
docker compose down -v
```

### Start and stop tomcat in backend container

#### Start and stop tomcat from docker container

```Bash
supervisorctl stop tomcat
supervisorctl start tomcat
```

#### Restart tomcat

```Bash
supervisorctl restart tomcat
```

#### Start and stop nginx in frontend container

Restart nginx

````
nginx -s reload

````



### How to get IP of your ubuntu machine

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
### Volumes Usage

We use Docker volumes in the `docker-compose.yml` file to persist data and files across container restarts and rebuilds.

```yaml
volumes:
  mysql-data:
  backend-webapps:
  frontend-html:
```

#### Purpose

* **`mysql-data`** → Stores MySQL database data so it remains intact even after container rebuilds.
* **`backend-webapps`** → Keeps backend build artifacts, logs, and configuration files persistent.
* **`frontend-html`** → Stores built frontend files (HTML, CSS, JS) used by Nginx.

#### Behavior

* During the **initial setup**, these volumes are automatically created when running:

  ```bash
  docker compose up -d
  ```
* Once created, Docker automatically reuses the existing volume data during future builds or image recreations.
* This ensures that any database data or generated files remain available even after rebuilding containers.

#### Benefits

* Data persists across rebuilds and restarts.
* Faster development setup — no need to reimport or rebuild.
* Safe updates without losing existing files or configurations.
* Makes containers behave more like long-lived environments.

#### To Reset Volumes

If you need to start fresh and remove stored data:

```bash
docker compose down -v
```







 


