#!/bin/bash

##########################################################################
# If not stated otherwise in this file or this component's LICENSE
# file the following copyright and licenses apply:
#
# Copyright 2026 RDK Management
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##########################################################################

# TDK Test Manager - Application Launch Script
# Sets up permissions and starts Docker services

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


# Optional release tag argument
RELEASE_TAG_ARG="$1"

update_release_tag() {
    local new_tag="$1"
    local env_file="${SCRIPT_DIR}/.env"
    
    if [[ -z "$new_tag" ]]; then
        return 0
    fi
    
    if [[ ! -f "$env_file" ]]; then
        log_message "ERROR: .env file not found at $env_file"
        return 1
    fi
    
    log_message "Updating RELEASE_TAG to: $new_tag"
    sed -i "s|^RELEASE_TAG=.*|RELEASE_TAG=$new_tag|" "$env_file"
    log_message "RELEASE_TAG updated successfully"
}

log_message() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1"
}

log_message "Starting TDK Test Manager application setup..."


# Update release tag if argument provided
if [[ -n "$RELEASE_TAG_ARG" ]]; then
    update_release_tag "$RELEASE_TAG_ARG"
fi

# Verify database directory exists
if [ ! -d "${SCRIPT_DIR}/database" ]; then
    log_message "ERROR: database directory not found at ${SCRIPT_DIR}/database"
    exit 1
fi

# Configure directory permissions
log_message "Configuring directory permissions..."
chmod 755 "${SCRIPT_DIR}/database/"
chmod 755 "${SCRIPT_DIR}/database/init/"

# Configure file permissions
log_message "Configuring file permissions..."
chmod 644 "${SCRIPT_DIR}/database/init/tdk-master-data-dump.sql"

# Verify Docker daemon is running before proceeding
log_message "Checking Docker daemon status..."
MAX_WAIT=30
WAIT_COUNT=0
while ! docker info >/dev/null 2>&1; do
    WAIT_COUNT=$((WAIT_COUNT + 1))
    if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
        log_message "ERROR: Docker daemon is not running. Cannot connect to Docker at unix:///var/run/docker.sock"
        log_message "Try running: sudo systemctl start docker"
        exit 1
    fi
    log_message "Waiting for Docker daemon to be ready... (${WAIT_COUNT}/${MAX_WAIT})"
    sleep 1
done
log_message "Docker daemon is running."

# Check if port 3306 is occupied by a non-Docker process
log_message "Checking if port 3306 is available..."
PORT_PID=$(ss -tlnp 2>/dev/null | grep ':3306 ' | grep -oP 'pid=\K[0-9]+' | head -1)
if [ -n "$PORT_PID" ]; then
    PORT_PROCESS=$(ps -p "$PORT_PID" -o comm= 2>/dev/null || echo "unknown")
    # Check if the process holding the port is a Docker container process
    if ! grep -q docker /proc/"$PORT_PID"/cgroup 2>/dev/null; then
        log_message "WARNING: Port 3306 is in use by non-Docker process '${PORT_PROCESS}' (PID: ${PORT_PID})"
        # Attempt to stop and disable native MySQL/MariaDB
        if systemctl is-active --quiet mysql 2>/dev/null; then
            log_message "Stopping and disabling native mysql service..."
            systemctl stop mysql
            systemctl disable mysql
            log_message "Native mysql service stopped and disabled."
        elif systemctl is-active --quiet mysqld 2>/dev/null; then
            log_message "Stopping and disabling native mysqld service..."
            systemctl stop mysqld
            systemctl disable mysqld
            log_message "Native mysqld service stopped and disabled."
        elif systemctl is-active --quiet mariadb 2>/dev/null; then
            log_message "Stopping and disabling native mariadb service..."
            systemctl stop mariadb
            systemctl disable mariadb
            log_message "Native mariadb service stopped and disabled."
        else
            log_message "ERROR: Port 3306 is occupied by '${PORT_PROCESS}' (PID: ${PORT_PID}) but could not identify a known database service to stop."
            log_message "Please free port 3306 manually and retry."
            exit 1
        fi
        # Verify port is now free
        sleep 2
        if ss -tlnp 2>/dev/null | grep -q ':3306 '; then
            log_message "ERROR: Port 3306 is still in use after stopping the service. Please free it manually."
            exit 1
        fi
        log_message "Port 3306 is now available."
    else
        log_message "Port 3306 is in use by a Docker process — skipping conflict check."
    fi
else
    log_message "Port 3306 is available."
fi

# Build and launch containers
log_message "Building Docker images (no cache)..."
docker compose build --no-cache
BUILD_RESULT=$?

if [ $BUILD_RESULT -ne 0 ]; then
    log_message "ERROR: Docker build failed with exit code $BUILD_RESULT"
    exit $BUILD_RESULT
fi

log_message "Starting Docker containers..."
docker compose up -d
LAUNCH_RESULT=$?

if [ $LAUNCH_RESULT -eq 0 ]; then
    log_message "TDK Test Manager launched successfully!"
else
    log_message "ERROR: Failed to start containers (exit code: $LAUNCH_RESULT)"
fi

exit $LAUNCH_RESULT