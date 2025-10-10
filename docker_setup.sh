#!/bin/bash
# Install Docker
apt-get update
apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Create volumes for persistence
docker volume create torrent-data
docker volume create media-data

# Add GitHub secrets for auto-deployment
echo "To enable auto-deployment from GitHub, add these secrets to your GitHub repository:"
echo "VULTR_HOST: "
echo "VULTR_PASSWORD: "
echo "API_KEY: a22a0390f46cdf18754c9c6d172a2432e1a9f39cc1d04266813ea94dfab2b56b"

# Pull and run the container
# This step will be skipped on first run since the image isn't built yet
# It will be deployed by GitHub Actions after you push
