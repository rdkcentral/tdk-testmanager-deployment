#!/bin/bash
# TDK Test Manager - Complete Setup Script
# Validates Docker versions and launches the application

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REQUIRED_DOCKER_MAJOR="28"
REQUIRED_DOCKER_MINOR="1"
REQUIRED_COMPOSE_MAJOR="2"
REQUIRED_COMPOSE_MINOR="40"

display_status() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

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
    bash "$launch_script"
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

# Version mismatch or not installed
display_status "Version check results:"
display_status "  Docker   - Installed: ${CURRENT_DOCKER_VER:-Not found}, Required: ${REQUIRED_DOCKER_MAJOR}.${REQUIRED_DOCKER_MINOR}.X"
display_status "  Compose  - Installed: ${CURRENT_COMPOSE_VER:-Not found}, Required: ${REQUIRED_COMPOSE_MAJOR}.${REQUIRED_COMPOSE_MINOR}.X"

echo ""
read -p "Do you want to (re)install the recommended Docker versions? (Y/N): " USER_CHOICE

case "${USER_CHOICE^^}" in
    Y|YES)
        display_status "User chose to install recommended versions"
        if [[ -n "$CURRENT_DOCKER_VER" ]]; then
            remove_existing_docker
        fi
        execute_docker_install
        if [[ $? -ne 0 ]]; then
            display_status "ERROR: Docker installation failed"
            exit 1
        fi
        display_status "Docker installation completed successfully"
        ;;
    *)
        display_status "WARNING: Proceeding with non-recommended versions"
        display_status "  Recommended: Docker ${REQUIRED_DOCKER_MAJOR}.${REQUIRED_DOCKER_MINOR}.X, Compose ${REQUIRED_COMPOSE_MAJOR}.${REQUIRED_COMPOSE_MINOR}.X"
        display_status "  Installed:   Docker ${CURRENT_DOCKER_VER:-N/A}, Compose ${CURRENT_COMPOSE_VER:-N/A}"
        display_status "Continuing with application launch..."
        ;;
esac

execute_app_launch
APP_STATUS=$?

if [[ $APP_STATUS -eq 0 ]]; then
    display_status "Setup complete! TDK Test Manager is now running."
else
    display_status "ERROR: Application launch failed (exit code: $APP_STATUS)"
fi

exit $APP_STATUS