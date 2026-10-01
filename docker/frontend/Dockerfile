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
# ----------- Stage 1: Build Angular App ------------
FROM node:22.15.0-alpine AS builder

# Build argument for branch name
ARG RELEASE_TAG=main
# Note: 'main' is the default branch name if not set from environment variable

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
    git clone "https://github.com/rdkcentral/tdk-testmanager-frontend.git" && \
    cd tdk-testmanager-frontend/ && git checkout ${RELEASE_TAG}


# Set working directory to the Angular project inside the cloned repo
WORKDIR /app/tdk-testmanager-frontend

# Substitute environment variables (used for dynamic Angular config setup)
#RUN envsubst < src/app/utility/global-constants.template.ts > src/app/utility/global-constants.ts
# Define build-time argument
ARG API_URL

# Replace the default 'localhost' URL with your dynamic backend URL
RUN sed -i "s|http://localhost:8080/|${API_URL}|g" /app/tdk-testmanager-frontend/src/assets/config.json
# Install dependencies and build the Angular app
RUN npm install --force && \
    npm run build


# ---------- Stage 2: Node.js API Server Setup ----------
FROM node:18-alpine AS nodeapp

# Build argument for branch name (needs to be redeclared in each stage)
ARG RELEASE_TAG=develop

WORKDIR /nodeapp

RUN apk add --no-cache git

# Clone deployment repo
RUN git clone "https://github.com/rdkcentral/tdk-testmanager-deployment.git"

# Switch to the specified branch
RUN cd tdk-testmanager-deployment && git checkout ${RELEASE_TAG}

# Move into nodeapp
WORKDIR /nodeapp/tdk-testmanager-deployment/frontend-deployment-nodeapp

# Install dependencies
RUN npm install --force

# ----------- Stage 3: Serve using NGINX + Node.js ----------
FROM nginx:1.28.0-alpine

# Install bash, git and Node.js
RUN apk add --no-cache bash git nodejs npm

# Remove default config and add your custom NGINX config
RUN rm -f /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/nginx.conf

# Copy built Angular app from builder stage to NGINX's web root
COPY --from=builder /app/tdk-testmanager-frontend/dist/tdktest-manager-app/browser /var/www/html/

# Set proper permissions
RUN chmod -R 755 /var/www/html \
    && chown -R nginx:nginx /var/www/html

# Copy Node.js app files and scripts from nodeapp stage
COPY --from=nodeapp /nodeapp/tdk-testmanager-deployment/frontend-deployment-nodeapp/server.js /app/
COPY --from=nodeapp /nodeapp/tdk-testmanager-deployment/frontend-deployment-nodeapp/node_modules /app/node_modules/
COPY --from=nodeapp /nodeapp/tdk-testmanager-deployment/frontend-deployment-nodeapp/deploy.sh /app/
COPY --from=nodeapp /nodeapp/tdk-testmanager-deployment/frontend-deployment-nodeapp/angular_build_generation.sh /app/

# Give execute permission to shell scripts
RUN chmod +x /app/deploy.sh /app/angular_build_generation.sh

# Set working directory for Node.js app
WORKDIR /app

# Expose ports
EXPOSE 8443 3000

# Start Node.js server in background, then start NGINX
CMD node server.js & nginx -g 'daemon off;'


