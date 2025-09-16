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
# ----------- Stage 1: Build Angular App ------------
FROM node:22.15.0-alpine AS builder

# Set environment variables
ENV ANGULAR_CLI_VERSION=17.3.10

# Install Angular CLI
RUN npm install -g npm@11.3.0 \
    && npm install -g @angular/cli@${ANGULAR_CLI_VERSION}

# Set working directory inside the container
WORKDIR /app

# Install Git and clone your Angular repo
# Replace <YOUR_REPO_URL> with the actual URL of your Git repository
RUN apk add --no-cache git && \
    git clone "https://code.rdkcentral.com/r/rdk/tools/tdk" && \
    cd tdk/ && git checkout feature-tdk-newui


# Set working directory to the Angular project inside the cloned repo
WORKDIR /app/tdk/tdktestmanagerapp

# Substitute environment variables (used for dynamic Angular config setup)
#RUN envsubst < src/app/utility/global-constants.template.ts > src/app/utility/global-constants.ts
# Define build-time argument
ARG API_URL

# Replace the default 'localhost' URL with your dynamic backend URL
RUN sed -i "s|http://localhost:8080/|${API_URL}|g" /app/tdk/tdktestmanagerapp/src/assets/config.json
# Install dependencies and build the Angular app
RUN npm install --force && \
    npm run build
# ----------- Stage 2: Serve using NGINX ------------
FROM nginx:1.28.0-alpine

# Install bash (optional for debugging; safe to skip in prod)
RUN apk add --no-cache bash

# Remove default config and add your custom NGINX config
RUN rm -f /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/nginx.conf

# Copy built Angular app from builder stage to NGINX's web root
COPY --from=builder /app/tdk/tdktestmanagerapp/dist/tdktest-manager-app/browser /var/www/html/

# Set proper permissions (optional)
RUN chmod -R 755 /var/www/html \
    && chown -R nginx:nginx /var/www/html

# Expose the NGINX port
EXPOSE 8443

# Start NGINX in the foreground
CMD ["nginx", "-g", "daemon off;"]

