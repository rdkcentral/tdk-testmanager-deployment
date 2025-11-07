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

# Variables - use command line argument first, then RELEASE_REFERENCE from env file, fallback to defaults
echo "=== CLONE SCRIPT START ==="

# If command line argument provided, use it directly (Docker execution)
if [ -n "$1" ]; then
    RELEASE_BRANCH="$1"
    echo "Using command line argument: '$RELEASE_BRANCH'"
else
    # No command line argument, try to load from .env file (manual execution)
    echo "No command line argument provided, checking for .env file..."
    if [ -f ".env" ]; then
        echo "Loading .env file..."
        export $(grep -v '^#' .env | xargs)
        RELEASE_BRANCH=${RELEASE_REFERENCE:-"develop"}
        echo "Using RELEASE_REFERENCE from .env: '$RELEASE_BRANCH'"
    else
        RELEASE_BRANCH="develop"
        echo "No .env file found, using default: '$RELEASE_BRANCH'"
    fi
fi

echo "Final RELEASE_BRANCH: '$RELEASE_BRANCH'"

backendRepo="https://github.com/rdkcentral/tdk-testmanager-backend.git"
coreRepo="https://github.com/rdkcentral/tdk-core.git"
broadbandRepo="https://github.com/rdkcentral/tdk-broadband.git"
deploymentRepo="https://github.com/rdkcentral/tdk-testmanager-deployment.git"

backendDir="tdk-testmanager-backend"
coreDir="tdk-core"
broadbandDir="tdk-broadband"
deploymentDir="tdk-testmanager-deployment"

# Clone backend repo
echo "Cloning backend repository..."
if [ -d "$backendDir" ]; then rm -rf "$backendDir"; fi
git clone -b "$RELEASE_BRANCH" "$backendRepo" || {
    echo "Warning: Branch $RELEASE_BRANCH not found in backend repo, trying develop..."
    git clone -b "develop" "$backendRepo"
}

# Clone core repo
echo "Cloning core repository..."
if [ -d "$coreDir" ]; then rm -rf "$coreDir"; fi
git clone -b "$RELEASE_BRANCH" "$coreRepo" || {
    echo "Warning: Branch $RELEASE_BRANCH not found in core repo, trying rdk-next..."
    git clone -b "rdk-next" "$coreRepo"
}

# Clone broadband repo
echo "Cloning broadband repository..."
if [ -d "$broadbandDir" ]; then rm -rf "$broadbandDir"; fi
git clone -b "$RELEASE_BRANCH" "$broadbandRepo" || {
    echo "Warning: Branch $RELEASE_BRANCH not found in broadband repo, trying main..."
    git clone -b "main" "$broadbandRepo"
}

# Clone deployment repo for datamigration folder
echo "Cloning deployment repository..."
if [ -d "$deploymentDir" ]; then rm -rf "$deploymentDir"; fi
git clone -b "$RELEASE_BRANCH" "$deploymentRepo" || {
    echo "Warning: Branch $RELEASE_BRANCH not found in deployment repo, trying main..."
    git clone -b "main" "$deploymentRepo"
}

# Copy fileStore from core to backend
echo "Copying fileStore from core to backend..."
cp -r "$coreDir/framework/fileStore" "$backendDir/src/main/webapp/"

# Create testscriptsRDKB folder in fileStore
echo "Creating testscriptsRDKB directory..."
mkdir -p "$backendDir/src/main/webapp/fileStore/testscriptsRDKB"

# Copy component folder from tdk-broadband to testscriptsRDKB
echo "Copying component folder from broadband repo..."
if [ -d "$broadbandDir/testscripts/RDKB/component" ]; then
    cp -r "$broadbandDir/testscripts/RDKB/component" "$backendDir/src/main/webapp/fileStore/testscriptsRDKB/"
    echo "Component folder copied successfully."
else
    echo "Warning: Component folder not found in broadband repo."
fi

# Copy integration folder from core to testscriptsRDKB
echo "Copying integration folder from core repo..."
if [ -d "$coreDir/framework/web-app/fileStore/testscriptsRDKBAdvanced/integration" ]; then
    cp -r "$coreDir/framework/fileStore/testscriptsRDKBAdvanced/integration" "$backendDir/src/main/webapp/fileStore/testscriptsRDKB/"
    echo "Integration folder copied successfully."
else
    echo "Warning: Integration folder not found in core repo."
fi

# Copy datamigration folder contents to backend resources/db folder
echo "Copying datamigration folder from deployment repo..."
if [ -d "$deploymentDir/datamigration" ]; then
    # Create the db directory if it doesn't exist
    mkdir -p "$backendDir/src/main/resources/db"

    # Copy all contents from datamigration to the backend db folder
    cp -r "$deploymentDir/datamigration/"* "$backendDir/src/main/resources/db/"
    echo "Datamigration files copied to backend src/main/resources/db successfully."
else
    echo "Warning: Datamigration folder not found in deployment repo."
fi


# Build WAR file using Maven
echo "Building WAR file with Maven..."
cd "$backendDir"
mvn clean install -DskipTests=true

# Check if any WAR file exists and rename it to tdkservice.war
WAR_FILE=$(ls target/*.war 2>/dev/null)

if [ -n "$WAR_FILE" ]; then
        echo "WAR file found: $WAR_FILE"
        # Rename the WAR file to tdkservice.war
        mv "$WAR_FILE" target/tdkservice.war
        echo "WAR file renamed to tdkservice.war."
        # Copy the renamed WAR file to the Tomcat webapps directory
        echo "Copying WAR file to Tomcat webapps..."
        cp target/tdkservice.war /opt/tomcat/webapps/
else
        echo "No WAR file found in target directory."
fi

echo "Build and deployment complete."

