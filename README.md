# TDK Test Manager Backend

Contains TDK test manager tool backend implementations - a Spring Boot application for managing and executing test suites in the RDK ecosystem.

## Table of Contents

- [Overview](#overview)
- [Docker Setup](#docker-setup)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)

## Overview

The TDK Test Manager Backend is a comprehensive Spring Boot application that provides:
- Test execution and management capabilities
- Database integration with MySQL
- RESTful API for frontend communication
- Docker-based deployment with multi-service architecture

## Docker Setup

This project uses Docker Compose to orchestrate multiple services including the backend application, frontend, and database.

### Prerequisites

Before running the application, ensure you have:

- **Docker Engine**: Version 20.10 or higher
- **Docker Compose**: Version 2.0 or higher
- **Environment Variables**: Configure the required environment variables (see Configuration section)

#### Installing Docker on Ubuntu

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

#### Main Docker Command

Once Docker is installed, use this command to build and run the entire application:

```bash
docker compose --env-file .env up -d --build
```

### Architecture

The Docker setup consists of three main services:

- **tdk-frontend**: Angular application served by Nginx (Port: 8443)
- **tdk-backend**: Spring Boot application on Tomcat 11 (Ports: 8080, 8089)
- **mysql-db**: MySQL 8.4 database (Port: 3306)

All services run on a shared Docker network (`tdk-net`) for internal communication.

## Quick Start

### 1. Clone the Repository
```bash
git clone <repository-url>
cd tdk-testmanager-deployment
```

### 2. Configure Environment Variables
Create a `.env` file in the `do` directory:

```env
# Database Configuration
MYSQL_ROOT_PASSWORD=
MYSQL_DATABASE=tdktestmanagerproddb
MYSQL_USER=tdktestuser
MYSQL_PASSWORD=

# Spring Boot Database Configuration
SPRING_DATASOURCE_URL=jdbc:mysql://mysql-db:3306/tdktestmanagerproddb
SPRING_DATASOURCE_USERNAME=root
SPRING_DATASOURCE_PASSWORD=root

# JWT Configuration
JWT_SECRET=your_jwt_secret_key

# Backend URL for Frontend
BACKEND_URL=http://localhost:8080/
```

### 3. Build and Start Services
```bash
cd devops-dockerfiles
docker compose --env-file .env up -d --build
```

This single command will:
- Load environment variables from `.env` file
- Build all Docker images
- Start all services in detached mode
- Create the complete application stack

### 4. Verify Deployment
- **Frontend**: Open https://localhost:8443 in your browser
- **Backend API**:
  - http://localhost:8080/tdkservice - Main API endpoint
- **Database**: Connect to localhost:3306 with configured credentials

## Configuration
Generating Your JWT Secret
 
**⚠️ IMPORTANT**: You must generate your own unique JWT secret. Do NOT use the default placeholder value in production!
 
#### Requirements for JWT Secret:
- **Minimum length**: 32 characters (longer is better)
- **Character variety**: Mix of uppercase, lowercase, numbers, and special characters
- **Randomness**: Use cryptographically secure random generation
- **Uniqueness**: Each environment should have its own secret
 
#### How to Generate a Secure JWT Secret:
 
#####Using Online Secure Generators
Visit a reputable online password generator:
- [passwords-generator.org](https://passwords-generator.org/) - Set length to 64+ characters
- [1password.com/password-generator](https://1password.com/password-generator/) - Use 64+ characters
### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `MYSQL_ROOT_PASSWORD` | MySQL root password | - | Yes |
| `MYSQL_DATABASE` | Database name | - | Yes |
| `MYSQL_USER` | Database user | - | Yes |
| `MYSQL_PASSWORD` | Database password | - | Yes |
| `SPRING_DATASOURCE_URL` | JDBC connection URL | - | Yes |
| `SPRING_DATASOURCE_USERNAME` | Database username for Spring | - | Yes |
| `SPRING_DATASOURCE_PASSWORD` | Database password for Spring | - | Yes |
| `JWT_SECRET` | JWT signing secret | - | Yes |
| `BACKEND_URL` | Backend URL for frontend | http://localhost:8080/tdkservice | Yes |
