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

echo "=================================================="
echo "Setting up tools for SVS Suite"
echo "=================================================="

# Fix broken packages if any
echo "Fixing broken packages if any..."
apt --fix-broken install -y
apt-get update -y

# Install nmap
echo "Installing nmap..."
apt-get install -y nmap
nmap --version || echo "nmap is not installed!"

# Install sslscan prerequisites
echo "Installing build tools and cloning sslscan..."
apt-get install -y build-essential git zlib1g-dev

# Clone and build sslscan
cd /home
if [[ -d "sslscan" ]]; then
    echo "sslscan directory already exists. Removing..."
    rm -rf sslscan
fi

git clone https://github.com/rbsec/sslscan.git
cd sslscan
make static

echo "SVS Suite prerequisite tools installed successfully."

