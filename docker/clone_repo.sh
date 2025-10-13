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

# Variables
backendRepo="https://github.com/rdkcentral/tdk-testmanager-backend.git"
coreRepo="https://github.com/rdkcentral/tdk-core.git"
backendBranch="develop"
coreBranch="rdk-next"
backendDir="tdk-testmanager-backend"
coreDir="tdk-core"

# Clone backend repo
if [ -d "$backendDir" ]; then rm -rf "$backendDir"; fi
git clone -b "$backendBranch" "$backendRepo"

# Clone core repo
if [ -d "$coreDir" ]; then rm -rf "$coreDir"; fi
git clone -b "$coreBranch" "$coreRepo"

# Copy fileStore from core to backend
cp -r "$coreDir/framework/web-app/fileStore" "$backendDir/src/main/webapp/"


# Build WAR file using Maven
cd "$backendDir"
mvn clean install -DskipTests=true

# Check if any WAR file exists and rename it to tdkservice.war
WAR_FILE=$(ls target/*.war 2>/dev/null)

if [ -n "$WAR_FILE" ]; then
	echo "WAR file found: $WAR_FILE"
	# Step 5: Rename the WAR file to tdkservice.war
	mv "$WAR_FILE" target/tdkservice.war
	echo "WAR file renamed to tdkservice.war."
	# Step 6: Copy the renamed WAR file to the Tomcat webapps directory
	echo "Copying WAR file to Tomcat webapps..."
	cp target/tdkservice.war /opt/tomcat/webapps/
else
	echo "No WAR file found in target directory."
fi

echo "Build and deployment complete."


