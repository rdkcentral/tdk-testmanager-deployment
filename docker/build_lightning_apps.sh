##########################################################################
# If not stated otherwise in this file or this component's Licenses.txt
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
#!/bin/bash

set -e

echo "Updating local package list..."
apt update -y

# Install Node.js (v16.x) and npm
NODE_VERSION=16.x
echo "Installing Node.js $NODE_VERSION..."
curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION} | bash -
apt-get install -y nodejs
npm set unsafe-perm true

# Verify installation
echo "npm version:"
npm --version || echo "npm is not installed."
echo "node version:"
node --version || echo "node is not installed."

# Install Lightning CLI
echo "Installing Lightning-CLI..."
npm install -g rdkcentral/Lightning-CLI

# Restart Tomcat
echo "Restarting Tomcat..."
/etc/init.d/tomcat7 stop || echo "Tomcat7 not found"
sleep 5
/etc/init.d/tomcat7 start || echo "Tomcat7 not found"
echo "Waiting for Tomcat to stabilize..."
sleep 50

# Function to build Lightning App
build_lightning_app() {
    local app_dir="$1"
    local app_name="$2"

    echo "Building ${app_name}..."

    cd "${app_dir}" || { echo "Directory ${app_dir} not found"; exit 1; }
    npm install
    if build_response=$(lng build); then
        echo "${app_name} built successfully"
    else
        echo "Error: Problem building ${app_name}" >&2
        exit 1
    fi
    rm -rf node_modules
    cd - >/dev/null
}

# Updated path
LIGHTNING_DIR="/opt/tomcat/webapps/tdkservice/fileStore/lightning-apps"
if [[ -d "${LIGHTNING_DIR}" ]]; then
    echo "Lightning apps found. Starting build process..."

    chmod -R 755 "${LIGHTNING_DIR}"
    cd "${LIGHTNING_DIR}"

    build_lightning_app "tdkunifiedplayer" "TDK Unified Player"
    build_lightning_app "tdkanimations" "TDK Animations Player"
    build_lightning_app "tdkmultianimations" "TDK Multi Animations"
    build_lightning_app "tdkobjectanimations" "TDK Object Animations"
    build_lightning_app "tdkipchange" "TDK IP Change"

    echo "All Lightning apps built successfully."
else
    echo "Error: Lightning app directory not found: ${LIGHTNING_DIR}" >&2
    exit 1
fi

