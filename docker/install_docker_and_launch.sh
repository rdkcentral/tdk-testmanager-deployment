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

# TDK Test Manager - Complete Setup Script
# Validates Docker versions and launches the application

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REQUIRED_DOCKER_MAJOR="28"
REQUIRED_DOCKER_MINOR="1"
REQUIRED_COMPOSE_MAJOR="2"
REQUIRED_COMPOSE_MINOR="40"

# Log file setup
LOG_FILE="${SCRIPT_DIR}/install_docker_and_launch_$(date '+%Y%m%d_%H%M%S').log"

# Release tag argument (optional)
RELEASE_TAG="$1"

display_status() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}


# Redirect all output to both console and log file
exec > >(tee -a "$LOG_FILE") 2>&1

display_status "Log file: $LOG_FILE"


extract_docker_version() {
    docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
}

extract_compose_version() {
    docker compose version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
}

validate_version_match() {
    local current_ver="$1"
    local req_major="$2"
    local req_minor="$3"
    
    local cur_major=$(echo "$current_ver" | cut -d. -f1 | tr -d '[:space:]')
    local cur_minor=$(echo "$current_ver" | cut -d. -f2 | tr -d '[:space:]')
    
    [[ "$cur_major" -eq "$req_major" && "$cur_minor" -eq "$req_minor" ]]
}

remove_existing_docker() {
    display_status "Removing existing Docker installation..."
    apt-get remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin 2>/dev/null || true
    apt-get autoremove -y 2>/dev/null || true
    rm -f /usr/libexec/docker/cli-plugins/docker-compose 2>/dev/null || true
    display_status "Existing Docker components removed"
}

execute_docker_install() {
    local install_script="${SCRIPT_DIR}/install-docker.sh"
    if [[ ! -f "$install_script" ]]; then
        display_status "ERROR: install-docker.sh not found at $install_script"
        return 1
    fi
    bash "$install_script"
    return $?
}

execute_app_launch() {
    local launch_script="${SCRIPT_DIR}/launch-application.sh"
    if [[ ! -f "$launch_script" ]]; then
        display_status "ERROR: launch-application.sh not found at $launch_script"
        return 1
    fi
    if [[ -n "$RELEASE_TAG" ]]; then
        display_status "Passing release tag to launch script: $RELEASE_TAG"
        bash "$launch_script" "$RELEASE_TAG"
    else
        bash "$launch_script"
    fi
    return $?
}

# Main execution starts here
display_status "TDK Test Manager - Complete Setup Starting..."

if [[ "$(id -u)" -ne 0 ]]; then
    display_status "ERROR: Root privileges required. Please run with sudo."
    exit 1
fi

CURRENT_DOCKER_VER=$(extract_docker_version)
CURRENT_COMPOSE_VER=$(extract_compose_version)

DOCKER_OK=false
COMPOSE_OK=false

if [[ -n "$CURRENT_DOCKER_VER" ]]; then
    validate_version_match "$CURRENT_DOCKER_VER" "$REQUIRED_DOCKER_MAJOR" "$REQUIRED_DOCKER_MINOR" && DOCKER_OK=true
fi

if [[ -n "$CURRENT_COMPOSE_VER" ]]; then
    validate_version_match "$CURRENT_COMPOSE_VER" "$REQUIRED_COMPOSE_MAJOR" "$REQUIRED_COMPOSE_MINOR" && COMPOSE_OK=true
fi

if $DOCKER_OK && $COMPOSE_OK; then
    display_status "Docker $CURRENT_DOCKER_VER and Compose $CURRENT_COMPOSE_VER detected - versions are compatible"
    display_status "Proceeding directly to application launch..."
    execute_app_launch
    exit $?
fi

# Version mismatch or not installed - proceed with reinstallation
display_status "Version check results:"
display_status "  Docker   - Installed: ${CURRENT_DOCKER_VER:-Not found}, Required: ${REQUIRED_DOCKER_MAJOR}.${REQUIRED_DOCKER_MINOR}.X"
display_status "  Compose  - Installed: ${CURRENT_COMPOSE_VER:-Not found}, Required: ${REQUIRED_COMPOSE_MAJOR}.${REQUIRED_COMPOSE_MINOR}.X"

if [[ -n "$CURRENT_DOCKER_VER" ]]; then
    display_status "Proceeding with Docker and Compose reinstallation..."
    remove_existing_docker
else
    display_status "Proceeding with Docker and Compose installation as no existing version was found..."
fi
execute_docker_install
if [[ $? -ne 0 ]]; then
    display_status "ERROR: Docker and Compose installation failed"
    exit 1
fi
display_status "Docker and Compose installation completed successfully"

execute_app_launch
APP_STATUS=$?

if [[ $APP_STATUS -eq 0 ]]; then
    display_status "Setup complete! TDK Test Manager is now running."
else
    display_status "ERROR: Application launch failed (exit code: $APP_STATUS)"
fi

display_status "Full execution log saved to: $LOG_FILE"

exit $APP_STATUS