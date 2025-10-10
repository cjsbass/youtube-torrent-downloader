#!/bin/bash
# YouTube Torrent API - One-Command Installer
set -e

echo "=== YouTube Torrent API - Cloud Setup ==="

# Update system
echo "Updating system..."
apt-get update && apt-get upgrade -y

# Install Docker
echo "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
rm get-docker.sh

# Install docker-compose
echo "Installing Docker Compose..."
apt-get install -y docker-compose git

# Clone repository
echo "Cloning repository..."
cd /root
git clone https://github.com/cjsbass/youtube-torrent-downloader.git
cd youtube-torrent-downloader/youtube-torrent/backend

# Create volumes
docker volume create torrent-data
docker volume create media-data

# Get server IP
SERVER_IP=$(curl -s ifconfig.me)

# Create docker-compose override
echo "Configuring for IP: $SERVER_IP"
cat > docker-compose.override.yml << DOCKEREOF
version: '3.8'
services:
  youtube-torrent-api:
    environment:
      - BASE_URL=http://${SERVER_IP}/torrents
    ports:
      - "80:5000"
DOCKEREOF

# Build and start
echo "Building and starting Docker container..."
docker-compose up -d --build

# Set up auto-update cron
echo "Setting up auto-update..."
cat > /root/update.sh << 'UPDATEEOF'
#!/bin/bash
cd /root/youtube-torrent-downloader
git pull
cd youtube-torrent/backend
docker-compose up -d --build
UPDATEEOF

chmod +x /root/update.sh
echo "0 * * * * /root/update.sh >> /var/log/youtube-torrent-update.log 2>&1" | crontab -

echo ""
echo "=== Setup Complete ==="
echo "API URL: http://${SERVER_IP}"
echo "API Key: a22a0390f46cdf18754c9c6d172a2432e1a9f39cc1d04266813ea94dfab2b56b"
echo ""
echo "Your YouTube Torrent API is now running!"
echo "Auto-updates from GitHub will run hourly."
echo ""

