#!/bin/bash
set -e

# ==============================================================================
# Startup Script: Prepare Application Host with Docker & Docker Compose
# ==============================================================================

# 1. Update OS and install dependencies
apt-get update
apt-get install -y curl ca-certificates gnupg lsb-release

# 2. Install Docker using Docker's official convenience installer
curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
sh /tmp/get-docker.sh

# 3. Install Docker Compose plugin
apt-get install -y docker-compose-plugin

# 4. Enable and start Docker service
systemctl enable docker
systemctl start docker

# 5. Allow standard users / jenkins deployment access to docker
chmod 666 /var/run/docker.sock
