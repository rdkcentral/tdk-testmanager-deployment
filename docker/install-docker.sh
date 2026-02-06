#!/bin/bash
##########################################################################
# If not stated otherwise in this file or this component's LICENSE
# file the following copyright and licenses apply:
#
# Copyright 2025 RDK Management
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
set -e

# =============================================================================
# Docker Installation Script for TDK Test Manager
# Installs Docker Engine 28.1.0 and Docker Compose 2.40.0 on Ubuntu 24.04
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Define versions
DOCKER_VERSION="5:28.1.0-1~ubuntu.24.04~noble"
COMPOSE_VERSION="2.40.0"

echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}   Docker Installation Script for TDK Test Manager                           ${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""
echo "This script will install:"
echo "  - Docker Engine: 28.1.0"
echo "  - Docker Compose: ${COMPOSE_VERSION}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: Please run as root (sudo)${NC}"
    echo "Usage: sudo ./install-docker.sh"
    exit 1
fi

# Check Ubuntu version
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "$VERSION_ID" != "24.04" ]; then
        echo -e "${YELLOW}Warning: This script is tested on Ubuntu 24.04. You are running Ubuntu ${VERSION_ID}.${NC}"
        echo -e "${YELLOW}The Docker version string may need adjustment.${NC}"
        read -p "Do you want to continue? (y/N): " continue_install
        if [[ ! "$continue_install" =~ ^[Yy]$ ]]; then
            echo "Installation cancelled."
            exit 0
        fi
    fi
fi

echo -e "${GREEN}Step 1/9: Updating package index...${NC}"
apt-get update

echo -e "${GREEN}Step 2/9: Installing required packages...${NC}"
apt-get install -y ca-certificates curl

echo -e "${GREEN}Step 3/9: Setting up Docker's GPG key...${NC}"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo -e "${GREEN}Step 4/9: Adding Docker repository...${NC}"
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
tee /etc/apt/sources.list.d/docker.list > /dev/null

echo -e "${GREEN}Step 5/9: Updating package index...${NC}"
apt-get update


echo -e "${GREEN}Step 6/9: Installing Docker Engine version 28.1.0...${NC}"
apt-mark unhold docker-ce docker-ce-cli
apt-get install -y \
    docker-ce=$DOCKER_VERSION \
    docker-ce-cli=$DOCKER_VERSION \
    containerd.io \
    docker-buildx-plugin

echo -e "${GREEN}Step 7/9: Pinning Docker version to prevent auto-updates...${NC}"
apt-mark hold docker-ce docker-ce-cli

echo -e "${GREEN}Step 8/9: Installing Docker Compose version ${COMPOSE_VERSION}...${NC}"
mkdir -p /usr/libexec/docker/cli-plugins
curl -L "https://github.com/docker/compose/releases/download/v${COMPOSE_VERSION}/docker-compose-linux-x86_64" \
    -o /usr/libexec/docker/cli-plugins/docker-compose
chmod +x /usr/libexec/docker/cli-plugins/docker-compose

echo -e "${GREEN}Step 9/9: Verifying installation...${NC}"
echo ""
echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}   Installation Complete!                                                    ${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""
echo "Installed versions:"
echo "  Docker Engine:  $(docker --version)"
echo "  Docker Compose: $(docker compose version)"
echo ""
echo -e "${YELLOW}Note: Docker version is pinned to prevent automatic updates.${NC}"
echo -e "${YELLOW}To unpin later, run: sudo apt-mark unhold docker-ce docker-ce-cli${NC}"
echo ""
