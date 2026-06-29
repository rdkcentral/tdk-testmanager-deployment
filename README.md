# TDK Test Manager Deployment

This repository contains deployment configurations and files for the TDK Test Manager application.

### Table of Contents

- [Overview](#overview)
- [Application setup](#application-setup)
- [Troubleshooting](#troubleshooting)
- [Miscellaneous](#miscellaneous)

## Overview

This project uses Docker Compose to orchestrate multiple services including the backend application, frontend, and database for tdk-testmanager. It also contains the data dump and other release migration related configurations

## Application-Setup

This project uses Docker Compose to orchestrate multiple services including the backend application, frontend, and database.

### Environment

Before proceeding, ensure you have:

**Ubuntu**: Version 24.04 is recommended and verified

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

1. _Get your IP address_ : Refer to the section [Network Configuration](#network-configuration) under Miscellaneous to get your IP.

2. _Update the BACKEND_URL_ : Change backend URL from `http://localhost:8443/tdkservice/` to `http://{Your-IP}:8443/tdkservice/`

Example : If your IP is 192.168.162.65, backend url should be changed like this

```bash
BACKEND_URL=http://192.168.162.65:8443/tdkservice/

```

#### 4. Make the docker installation and app setup scripts executable

Run the following command from the terminal

```bash
chmod  +x  install_docker_and_launch.sh install-docker.sh launch-application.sh

```

#### 5. Install/Reinstall Docker , Docker Compose and Launch application

Run the script _install_docker_and_launch.sh_. This will install the required version of docker and bring up the application

To deploy the latest tagged release run the following

```bash
 ./install_docker_and_launch.sh

```

To deploy a specific tagged release, pass it as argument

```bash

./install_docker_and_launch.sh <RELEASE-TAG>

Example : ./install_docker_and_launch.sh TDK_M149

```

##### What to expect :

- The script checks if Docker 28.1.X and Docker Compose 2.40.X are installed on your system
- If versions are correct:
  - A confirmation message is displayed
  - Application launch begins automatically
- If versions are incorrect or missing:
  - Current and required versions are displayed
  - Existing Docker installation is automatically removed (if present)
  - Required Docker and Compose versions are installed automatically
- Application containers will be built and started (first run may take several minutes)
- A success message confirms the application is running
- All output is saved to `install_docker_and_launch_<timestamp>.log` for troubleshooting

#### 6. Verify Application Startup

- **Frontend**: Open _http://{IP}:8443_ in your browser, you will be able to see the login screen

  _Example : http://192.168.162.65:8443_

- **Backend API**: The backend API is proxied behind nginx, So the app is available in 8443 port under path tdkservice.
  - http://{IP}:8443/tdkservice/actuator/health - Use this endpoint to check if the app is up
  - The Rest api will return the app health status like given below:

  ```bash
    {"status":"UP"}
  ```

  _Example : http://192.168.162.65:8443/tdkservice/actuator/health_

#### 7. Login to the Application

To access the TDK application, navigate to the following URL in your web browser:

_http://{IP}:8443/login_

_Example : http://192.168.162.65:8443/login_

Use the default administrator credentials provided below to log in:

- **Username**: `admin`
- **Password**: `tdkforrdk`

Please refer to the link below for instructions on how to change the password:
https://wiki.rdkcentral.com/spaces/TDK/pages/474701332/TDK+Test+Manager+User+Guide#TDKTestManagerUserGuide-ChangePassword

## Troubleshooting

<details>
<summary><strong>Docker Daemon Not Running After Installation</strong></summary>

**Error:**

```
Docker and Compose installation completed successfully
Starting TDK Test Manager application setup...
Configuring directory permissions...
Configuring file permissions...
Building Docker images (no cache)...
Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?
ERROR: Docker build failed with exit code 1
ERROR: Application launch failed (exit code: 1)
```

**Cause:**

During Docker installation, the post-install hook (`deb-systemd-invoke`) attempted to start the Docker daemon automatically but was blocked by the system's `policy-rc.d` restriction. As a result, Docker was installed successfully but the daemon was never started.

**Resolution:**

Start and enable the Docker daemon manually:

```bash
systemctl enable docker
systemctl start docker
```

Then re-run the deployment script:

```bash
./install_docker_and_launch.sh
```

</details>

---

<details>
<summary><strong>Port 3306 Already in Use (MySQL Conflict)</strong></summary>

**Error:**

```
Error response from daemon: failed to set up container networking: driver failed programming external connectivity on endpoint mysql-db: failed to bind host port for 0.0.0.0:3306:172.18.0.2:3306/tcp: address already in use
ERROR: Failed to start containers (exit code: 1)
```

**Cause:**

A native MySQL instance is already running on the host server and occupying port 3306. The Docker `mysql-db` container cannot bind to the same port.

**Diagnosis:**

Run the following command to confirm whether port 3306 is in use by the native MySQL service:

```bash
ss -tlnp | grep 3306
```

If you see a response similar to the following, it confirms that the host's native MySQL is running and using port 3306:

```
LISTEN 0      151        127.0.0.1:3306       0.0.0.0:*    users:(("mysqld",pid=3586492,fd=23))
LISTEN 0      70         127.0.0.1:33060      0.0.0.0:*    users:(("mysqld",pid=3586492,fd=21))
```

**Resolution:**

Stop and disable the native MySQL service to free port 3306:

```bash
systemctl stop mysql
systemctl disable mysql
```

> **Note:** These commands only stop the MySQL process and prevent it from starting on reboot. Your existing database files at `/var/lib/mysql/` remain intact and can be restored at any time by running:
>
> ```bash
> systemctl enable mysql && systemctl start mysql
> ```

Then re-run the deployment script:

```bash
./install_docker_and_launch.sh
```

</details>

---

## Miscellaneous

### Docker Architecture

The Docker setup consists of three main services/containers:

- **tdk-frontend**: Angular application served by Nginx
- **tdk-backend**: Spring Boot application on Tomcat 11
- **mysql-db**: MySQL 8.4 database

All services run on a shared Docker network (`tdk-net`) for internal communication.

---

### Accessing Containers After Deployment

<details>
<summary><strong>View Docker Containers</strong></summary>

```bash
docker ps -a
```

</details>

---

<details>
<summary><strong>Enter tdk-frontend Container</strong></summary>

Enter the front-end docker container with the below command:

```bash
docker exec -it tdk-frontend bash
```

</details>

---

<details>
<summary><strong>Enter mysql-db Container</strong></summary>

Enter the mysql-db docker container with the below command:

```bash
docker exec -it mysql-db bash
```

</details>

---

<details>
<summary><strong>Enter tdk-backend Container</strong></summary>

Enter the back-end docker container with the below command:

```bash
docker exec -it tdk-backend bash
```

</details>

---

### Managing Containers

<details>
<summary><strong>Stop All Containers</strong></summary>

If something went wrong during the initial setup and you want to rebuild docker compose, run the below command. It stops and removes the containers, networks, and volumes defined by your docker-compose.yml file.

> **Warning**: Use this only during initial setup when you don't have any data in the volume.

```bash
cd tdk-testmanager-deployment/docker
docker compose down -v
```

</details>

---

<details>
<summary><strong>Start and Stop Tomcat in Backend Container</strong></summary>

Start and stop tomcat from docker container:

```bash
supervisorctl stop tomcat
supervisorctl start tomcat
```

Restart tomcat:

```bash
supervisorctl restart tomcat
```

</details>

---

<details>
<summary><strong>Restart Nginx in Frontend Container</strong></summary>

Reload nginx configuration:

```bash
nginx -s reload
```

</details>

---

### Network Configuration

<details>
<summary><strong>Get IP of Your Ubuntu Machine (Same Network)</strong></summary>

If you are going to access the test manager from the same network, run the below command to get your local IP:

```bash
ip addr show
```

Take the IP address assigned to your VM's network interface (e.g., eth0). Example output:

```
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether d4:cf:f9:49:e8:c9 brd ff:ff:ff:ff:ff:ff
    inet 192.168.162.65/24 brd 192.168.162.255 scope global eth0
       valid_lft forever preferred_lft forever
```

</details>

---

<details>
<summary><strong>Get IP of Your Ubuntu Machine (External Network)</strong></summary>

If you are going to access the test manager from another network, get the public IP by running:

```bash
curl ifconfig.me
```

</details>

---

### Volumes Usage

We use Docker volumes in the `docker-compose.yml` file to persist data and files across container restarts and rebuilds.

<details>
<summary><strong>Volume Definition</strong></summary>

```yaml
volumes:
  mysql-data:
  backend-webapps:
  frontend-html:
```

</details>

---

<details>
<summary><strong>Volume Purpose</strong></summary>

| Volume            | Purpose                                                                       |
| ----------------- | ----------------------------------------------------------------------------- |
| `mysql-data`      | Stores MySQL database data so it remains intact even after container rebuilds |
| `backend-webapps` | Keeps backend build artifacts, logs, and configuration files persistent       |
| `frontend-html`   | Stores built frontend files (HTML, CSS, JS) used by Nginx                     |

</details>

---

<details>
<summary><strong>Volume Behavior</strong></summary>

- During the **initial setup**, these volumes are automatically created when running:

  ```bash
  docker compose up -d
  ```

- Once created, Docker automatically reuses the existing volume data during future builds or image recreations.
- This ensures that any database data or generated files remain available even after rebuilding containers.

</details>

---

<details>
<summary><strong>Volume Data Location</strong></summary>

Docker volumes are stored on the Ubuntu host at `/var/lib/docker/volumes/`. The full paths for each volume are:

| Volume            | Host Path                                              |
| ----------------- | ------------------------------------------------------ |
| `mysql-data`      | `/var/lib/docker/volumes/docker_mysql-data/_data`      |
| `backend-webapps` | `/var/lib/docker/volumes/docker_backend-webapps/_data` |
| `frontend-html`   | `/var/lib/docker/volumes/docker_frontend-html/_data`   |

</details>

---

<details>
<summary><strong>Useful Volume Commands</strong></summary>

List all volumes:

```bash
docker volume ls
```

Inspect a specific volume (shows mount point and details):

```bash
docker volume inspect docker_mysql-data
```

</details>

---

<details>
<summary><strong>Benefits of Volumes</strong></summary>

- Data persists across rebuilds and restarts.
- Faster development setup — no need to reimport or rebuild.
- Safe updates without losing existing files or configurations.
- Makes containers behave more like long-lived environments.

</details>

---

### Docker Containers Health Check and Disk Cleanup

<details>
<summary><strong>Check Docker Disk Usage</strong></summary>

```bash
docker system df -v
```

Displays detailed information about disk space used by Docker components, including:

- Images
- Containers
- Local volumes
- Build cache

The `-v` (verbose) flag provides per-object level details, making it useful for identifying what is consuming the most space.

**Use Case:**

- Periodic health checks
- Troubleshooting disk space issues
- Capacity planning

</details>

---

<details>
<summary><strong>Remove Docker Builder Cache (All)</strong></summary>

```bash
docker builder prune -a
```

Deletes all Docker build cache, including:

- Intermediate image layers
- Cache from previous `docker build` operations

The `-a` flag removes all cache, not just unused cache.

**Use Case:**

- Resolve build inconsistencies
- Recover significant disk space

</details>

---

<details>
<summary><strong>Remove Unused Docker Builder Cache (Default)</strong></summary>

```bash
docker builder prune
```

Removes only unused Docker build cache. Compared to `docker builder prune -a`, this is a safer option, as it preserves cache layers that may still be reused.

**Use Case:**

- Routine maintenance
- Safe cleanup without impacting ongoing builds

</details>
