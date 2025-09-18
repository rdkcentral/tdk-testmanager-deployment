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


# Step 1: Clone the repository (if not already cloned) and navigate to the framework directory
echo "Cloning the repository (if not already done)..."
if [ ! -d "tdk" ]; then
    git clone "https://code.rdkcentral.com/r/rdk/tools/tdk"
fi

cd tdk/ || { echo "Failed to navigate to tdk/framwork directory"; exit 1; }

# Step 2: Git Checkout (switch to the desired branch or commit)
echo "Switching to the correct branch..."
git checkout  feature-tdk-newui # Replace 'main' with your branch or commit

cd tdkservice/tdkservice

# Step 3: Build the WAR using Maven (skip tests)
echo "Building the WAR file using Maven..."
mvn clean install -DskipTests=true

# Step 4: Check if any WAR file exists and rename it to tdkservice.war
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
    exit 1
fi

