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

log_message() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1"
}

log_message "Starting TDK Test Manager application setup..."

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