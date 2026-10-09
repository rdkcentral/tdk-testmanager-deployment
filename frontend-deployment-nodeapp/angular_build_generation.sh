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

# Angular Build Generation Script
# This script clones the tdk-testmanager-frontend repository,
# installs dependencies, builds the Angular application, and
# packages the output for deployment.

echo "=== ANGULAR BUILD GENERATION SCRIPT START ==="

# Variables - use command line argument first, then RELEASE_TAG from env file, fallback to defaults
if [ -n "$1" ]; then
    RELEASE_TAG="$1"
    echo "Using command line argument: '$RELEASE_TAG'"
else
    if [ -f ".env" ]; then
        echo "Loading .env file..."
        export $(grep -v '^#' .env | xargs)
        RELEASE_TAG=${RELEASE_TAG:-"main"}
        echo "Using RELEASE_TAG from .env: '$RELEASE_TAG'"
    else
        RELEASE_TAG="main"
        echo "No .env file found, using default: '$RELEASE_TAG'"
    fi
fi

echo "Final RELEASE_TAG: '$RELEASE_TAG'"

# UPGRADE_DIR is mandatory - must be provided as second parameter
if [ -z "$2" ]; then
    echo "ERROR: UPGRADE_DIR not provided!"
    exit 1
fi
UPGRADE_DIR="$2"
echo "Using provided UPGRADE_DIR: $UPGRADE_DIR"

# Optional: backend API URL and Node API URL to bake into config.json
APP_API_URL="$3"
APP_NODE_API_URL="$4"
echo "API_URL: '${APP_API_URL:-<not provided, keeping repo default>}'"
echo "NODE_API_URL: '${APP_NODE_API_URL:-<not provided, keeping repo default>}'"

# Create working directory with release tag at /mnt/AngularBuild/
WORK_DIR="/mnt/AngularBuild/${RELEASE_TAG}"
echo "Creating working directory: $WORK_DIR"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"
echo "Working in directory: $(pwd)"

frontendRepo="https://github.com/rdkcentral/tdk-testmanager-frontend.git"
frontendDir="tdk-testmanager-frontend"

# Clone frontend repo
echo "Cloning frontend repository..."
if [ -d "$frontendDir" ]; then rm -rf "$frontendDir"; fi
git clone -b "$RELEASE_TAG" "$frontendRepo" || {
    echo "Warning: Branch $RELEASE_TAG not found in frontend repo, trying main..."
    git clone -b "main" "$frontendRepo"
}

if [ ! -d "$frontendDir" ]; then
    echo "ERROR: Failed to clone frontend repository."
    exit 1
fi

cd "$frontendDir"
echo "Changed to frontend directory: $(pwd)"

# Update config.json with the correct backend/API URLs for this deployment
CONFIG_FILE="src/assets/config.json"
if [ -f "$CONFIG_FILE" ]; then
    if [ -n "$APP_API_URL" ]; then
        echo "Updating apiUrl in $CONFIG_FILE..."
        sed -i "s|\"apiUrl\": \".*\"|\"apiUrl\": \"$APP_API_URL\"|" "$CONFIG_FILE"
    fi
    if [ -n "$APP_NODE_API_URL" ]; then
        echo "Updating nodeApiUrl in $CONFIG_FILE..."
        sed -i "s|\"nodeApiUrl\": \".*\"|\"nodeApiUrl\": \"$APP_NODE_API_URL\"|" "$CONFIG_FILE"
    fi
    echo "Updated $CONFIG_FILE contents:"
    cat "$CONFIG_FILE"
else
    echo "WARNING: $CONFIG_FILE not found, skipping URL substitution."
fi

# Install Node.js dependencies
echo "Installing Node.js dependencies..."
npm install --force
if [ $? -ne 0 ]; then
    echo "ERROR: npm install failed."
    exit 1
fi
echo "Dependencies installed successfully."

# Build Angular application
echo "Building Angular application..."
npm run build
if [ $? -ne 0 ]; then
    echo "ERROR: Angular build failed."
    exit 1
fi
echo "Angular build completed successfully."

# Determine build output directory
BUILD_OUTPUT_DIR=""
if [ -d "dist/tdktest-manager-app/browser" ]; then
    BUILD_OUTPUT_DIR="dist/tdktest-manager-app/browser"
elif [ -d "dist/tdk-testmanager-frontend/browser" ]; then
    BUILD_OUTPUT_DIR="dist/tdk-testmanager-frontend/browser"
elif [ -d "dist/browser" ]; then
    BUILD_OUTPUT_DIR="dist/browser"
else
    # Fallback: dynamically locate any "browser" folder produced under dist/
    FOUND_BROWSER_DIR=$(find dist -maxdepth 2 -type d -name "browser" 2>/dev/null | head -1)
    if [ -n "$FOUND_BROWSER_DIR" ]; then
        BUILD_OUTPUT_DIR="$FOUND_BROWSER_DIR"
    elif [ -d "dist/tdk-testmanager-frontend" ]; then
        BUILD_OUTPUT_DIR="dist/tdk-testmanager-frontend"
    elif [ -d "dist" ]; then
        BUILD_OUTPUT_DIR="dist"
    else
        echo "ERROR: Build output directory not found."
        exit 1
    fi
fi

echo "Build output directory: $BUILD_OUTPUT_DIR"

# Create UPGRADE_DIR and copy build output
mkdir -p "$UPGRADE_DIR"

# Copy the build output to UPGRADE_DIR/browser (matching deploy.sh expectations)
echo "Copying build output to upgrade directory..."
mkdir -p "$UPGRADE_DIR/browser"
cp -r "$BUILD_OUTPUT_DIR/"* "$UPGRADE_DIR/browser/"
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to copy build output."
    exit 1
fi

echo "Build files copied to: $UPGRADE_DIR/browser"

echo "Angular Build Generation completed."

# Output UPGRADE_DIR for backend to capture
echo "Angular Build Generated at=$UPGRADE_DIR"
