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

backup_path="$1"
deploy_path="$2"
upload_path="$3"

timestamp=$(date +"%Y%m%d_%H%M%S")
log="/mnt/appUpgrade/deployment_logs/deploy_$timestamp.log"

# Ensure log directory exists
mkdir -p "$(dirname "$log")"
mkdir -p "$backup_path"

echo "==== Deployment Started ====" | tee -a "$log"
echo "Backup path: $backup_path" | tee -a "$log"
echo "Deploy path: $deploy_path" | tee -a "$log"
echo "Upload path: $upload_path" | tee -a "$log"

# Use upload_path/browser if it exists
if [ -d "$upload_path/browser" ]; then
  src_path="$upload_path/browser"
else
  src_path="$upload_path"
fi

# Step 1: Backup
echo "[1/4] Backing up current deployment..." | tee -a "$log"
cp -r "$deploy_path" "$backup_path/" || {
  echo "❌ Backup failed" | tee -a "$log"
  exit 1
}

# Step 2: Clean
echo "[2/4] Cleaning old deployment..." | tee -a "$log"
rm -rf "$deploy_path"/* || {
  echo "❌ Failed to clean deployment folder" | tee -a "$log"
  exit 1
}

# Step 3: Copy
echo "[3/4] Copying new build contents to deployment folder..." | tee -a "$log"
cp -r "$src_path/"* "$deploy_path"/ || {
  echo "❌ Failed to copy build files" | tee -a "$log"
  exit 1
}

# Step 4: Permissions
echo "[4/4] Setting ownership and permissions..." | tee -a "$log"
chown -R www-data:www-data "$deploy_path" || echo "⚠️ chown failed. Check user/group." | tee -a "$log"
chmod -R u=rwX,g=rX,o=rX "$deploy_path"

# Restart nginx
echo "Restarting nginx..." | tee -a "$log"
systemctl restart nginx 2>>"$log" || nginx -s reload 2>>"$log"

echo "✅ Deployment completed successfully." | tee -a "$log"

