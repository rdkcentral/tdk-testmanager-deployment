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
FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# Install system tools and Python 3.12
RUN apt-get update && apt-get upgrade -y && apt-get install -y \
    python3.12 \
    python3.12-venv \
    python3.12-dev \
    python3-pip \
    vim \
    net-tools \
    inetutils-ping \
    unzip \
    zip \
    git \
    openjdk-21-jdk \
    wget \
    curl \
    sshpass \
    cmake \
    build-essential \
    pkg-config \
    default-libmysqlclient-dev \
    gcc \
    supervisor \
 && rm -rf /var/lib/apt/lists/*

# Set Python 3.12 as default
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1

# Set JAVA_HOME
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
ENV PATH=$JAVA_HOME/bin:$PATH
# Create and activate virtual environment
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Upgrade pip and install dependencies
RUN pip install --no-cache-dir pip==25.1.1 \
 && pip install --no-cache-dir \
    xlwt-future==0.8.0 \
    tftpy==0.8.4 \
    websocket-client==1.8.0 \
    selenium==3.141.0 \
    requests==2.31.0 \
    pexpect==4.8.0 \
    urllib3==1.26.20 \
    Pillow==10.2.0 \
    numpy==1.26.4 \
    mysqlclient==2.2.4 \
    paramiko==3.4.0 \
    gevent==23.9.1 \
    opencv-python==4.9.0.80 \
    pytesseract==0.3.10

#  Install Maven
ENV MAVEN_VERSION=3.9.9
ENV MAVEN_HOME=/opt/maven
RUN wget https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz -P /tmp \
 && tar -xzvf /tmp/apache-maven-${MAVEN_VERSION}-bin.tar.gz -C /opt \
 && ln -s /opt/apache-maven-${MAVEN_VERSION} /opt/maven \
 && rm /tmp/apache-maven-${MAVEN_VERSION}-bin.tar.gz
ENV PATH=$MAVEN_HOME/bin:$PATH

# Install Tomcat 11
RUN wget https://archive.apache.org/dist/tomcat/tomcat-11/v11.0.6/bin/apache-tomcat-11.0.6.tar.gz -P /tmp \
    && tar xf /tmp/apache-tomcat-11.0.6.tar.gz -C /opt \
    && mv /opt/apache-tomcat-11.0.6 /opt/tomcat \
    && rm /tmp/apache-tomcat-11.0.6.tar.gz

# Set Tomcat env
ENV CATALINA_HOME=/opt/tomcat
ENV PATH=$CATALINA_HOME/bin:$PATH

# Make Tomcat scripts executable
RUN chmod +x $CATALINA_HOME/bin/*.sh

# Copy clone script and make it executable
COPY clone_repo.sh /opt/clone_repo.sh
RUN chmod +x /opt/clone_repo.sh

# Copy environment configuration
COPY .env /opt/.env

# Copy install_chromedriver.sh script and make it executable
COPY install_chromedriver.sh /opt/install_chromedriver.sh

# Add the shell script as executable
RUN chmod +x /opt/install_chromedriver.sh

# Set working directory
WORKDIR /opt

# Run the clone script to build the application
RUN /opt/clone_repo.sh

# Run the ChromeDriver installation script
RUN /opt/install_chromedriver.s || true

# Create setenv.sh for Tomcat to pass environment variables
RUN echo '#!/bin/bash' > /opt/tomcat/bin/setenv.sh && \
    echo 'export CATALINA_OPTS="$CATALINA_OPTS $JAVA_OPTS"' >> /opt/tomcat/bin/setenv.sh && \
    chmod +x /opt/tomcat/bin/setenv.sh

# Copy Supervisor config
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Expose Tomcat port
EXPOSE 8080

# Start supervisor
CMD ["/usr/bin/supervisord", "-n"]

