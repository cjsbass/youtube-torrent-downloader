#!/bin/bash
# Setup Vultr server with Docker for auto-deployment

# Set your variables
VULTR_API_KEY="NYSNP3QX2NLIP4TZJXMVC7D5BEONSYWNWX3Q"
API_KEY="a22a0390f46cdf18754c9c6d172a2432e1a9f39cc1d04266813ea94dfab2b56b"

# Create a Vultr instance with Docker pre-installed
echo "Creating Vultr instance with Docker..."
INSTANCE_RESPONSE=$(curl -s -H "Authorization: Bearer ${VULTR_API_KEY}" \
  -H "Content-Type: application/json" \
  -X POST https://api.vultr.com/v2/instances \
  --data '{
    "region": "ewr",
    "plan": "vc2-1c-1gb",
    "os_id": 1743,
    "label": "youtube-torrent-docker",
    "hostname": "youtube-torrent-api",
    "tag": "youtube-torrent"
  }')

# Extract the instance ID and IP
INSTANCE_ID=$(echo $INSTANCE_RESPONSE | grep -o '"id":"[^"]*' | cut -d'"' -f4)
MAIN_IP=$(echo $INSTANCE_RESPONSE | grep -o '"main_ip":"[^"]*' | cut -d'"' -f4)
PASSWORD=$(echo $INSTANCE_RESPONSE | grep -o '"default_password":"[^"]*' | cut -d'"' -f4)

echo "Instance created!"
echo "ID: $INSTANCE_ID"
echo "IP: $MAIN_IP"
echo "Password: $PASSWORD"

# Wait for the instance to initialize
echo "Waiting for server to initialize (60 seconds)..."
sleep 60

# Generate setup script for Docker
cat > docker_setup.sh << EOF
#!/bin/bash
# Install Docker
apt-get update
apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable"
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Create volumes for persistence
docker volume create torrent-data
docker volume create media-data

# Add GitHub secrets for auto-deployment
echo "To enable auto-deployment from GitHub, add these secrets to your GitHub repository:"
echo "VULTR_HOST: $MAIN_IP"
echo "VULTR_PASSWORD: $PASSWORD"
echo "API_KEY: $API_KEY"

# Pull and run the container
# This step will be skipped on first run since the image isn't built yet
# It will be deployed by GitHub Actions after you push
EOF

echo ""
echo "============================"
echo "Setup Instructions:"
echo "============================"
echo ""
echo "1. SSH to your Vultr server:"
echo "   ssh root@$MAIN_IP"
echo "   Password: $PASSWORD"
echo ""
echo "2. Run these commands on your server:"
echo "   # Copy and paste these commands on your server"
echo "   curl -s https://raw.githubusercontent.com/docker/docker-install/master/install.sh | bash"
echo "   docker volume create torrent-data"
echo "   docker volume create media-data"
echo ""
echo "3. Add these secrets to your GitHub repository:"
echo "   VULTR_HOST: $MAIN_IP"
echo "   VULTR_PASSWORD: $PASSWORD"
echo "   API_KEY: $API_KEY"
echo ""
echo "4. Push your code to GitHub to trigger the deployment"
echo "   git add ."
echo "   git commit -m \"Add Docker deployment\""
echo "   git push"
echo ""
echo "Your YouTube torrent API will be automatically deployed to $MAIN_IP"
echo ""
