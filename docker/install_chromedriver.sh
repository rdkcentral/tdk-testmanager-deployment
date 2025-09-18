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

CHROME_DRIVER_VERSION=126.0.6478.61
DOWNLOAD_URL="https://storage.googleapis.com/chrome-for-testing-public/${CHROME_DRIVER_VERSION}/linux64/chromedriver-linux64.zip"
INSTALL_DIR="/root/chrome_setup"

echo "Creating installation directory at ${INSTALL_DIR}..."
mkdir -p "${INSTALL_DIR}"
cd "${INSTALL_DIR}"

# Install Chrome from local .deb if not already installed
if ! command -v google-chrome &> /dev/null; then
    echo "Chrome not found. Attempting to install from local .deb..."

    if [ -f "google-chrome-stable_88.0.4324.150-1_amd64.deb" ]; then
        echo "Installing Chrome from google-chrome-stable_88.0.4324.150-1_amd64.deb..."
        apt-get update
        apt-get install -y ./google-chrome-stable_88.0.4324.150-1_amd64.deb || apt --fix-broken install -y
    elif [ -f "google-chrome-stable_current_amd64.deb" ]; then
        echo "Installing Chrome from google-chrome-stable_current_amd64.deb..."
        apt-get update
        apt-get install -y ./google-chrome-stable_current_amd64.deb || apt --fix-broken install -y
    else
        echo "Error: No local Chrome .deb file found in ${INSTALL_DIR}." >&2
        exit 1
    fi
else
    echo "Chrome is already installed: $(google-chrome --version)"
fi

echo "Downloading ChromeDriver version ${CHROME_DRIVER_VERSION}..."
wget -q "${DOWNLOAD_URL}" -O "${INSTALL_DIR}/chromedriver-linux64.zip"

echo "Unzipping ChromeDriver..."
unzip -q "${INSTALL_DIR}/chromedriver-linux64.zip" -d "${INSTALL_DIR}"

echo "Making ChromeDriver executable..."
chmod +x "${INSTALL_DIR}/chromedriver-linux64/chromedriver"

echo "Cleaning up zip file..."
rm "${INSTALL_DIR}/chromedriver-linux64.zip"

echo "ChromeDriver installed at ${INSTALL_DIR}/chromedriver-linux64/chromedriver"

echo "Verifying ChromeDriver version..."
"${INSTALL_DIR}/chromedriver-linux64/chromedriver" --version

