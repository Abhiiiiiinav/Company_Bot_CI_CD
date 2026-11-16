#!/bin/bash
set -e

# ==============================================================================
# Startup Script: Provision Jenkins VM with Docker, Jenkins & Terraform CLI
# ==============================================================================

# 1. Update OS and install dependencies
apt-get update
apt-get install -y curl ca-certificates gnupg lsb-release

# 2. Install Docker using official convenience installer
curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
sh /tmp/get-docker.sh
systemctl enable docker
systemctl start docker
chmod 666 /var/run/docker.sock

# 3. Launch Jenkins LTS container
docker run -d \
  --name jenkins \
  --restart unless-stopped \
  -p 8080:8080 -p 50000:50000 \
  -v jenkins_data:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts

# 4. Wait for Jenkins container to start up
until [ "$(docker inspect -f '{{.State.Running}}' jenkins 2>/dev/null)" = "true" ]; do
  sleep 3
done

# 5. Install Terraform CLI and Git inside Jenkins container
docker exec -u 0 jenkins sh -c '
  apt-get update && \
  apt-get install -y curl unzip git openssh-client && \
  curl -fsSL https://releases.hashicorp.com/terraform/1.9.5/terraform_1.9.5_linux_amd64.zip -o /tmp/terraform.zip && \
  unzip -o /tmp/terraform.zip -d /usr/local/bin/ && \
  rm /tmp/terraform.zip
'
