#!/bin/bash
# Vultr Cloud-Init Startup Script
# This script will automatically set up the YouTube Torrent API on a new Vultr instance

set -e

echo "=== YouTube Torrent API - Automated Setup ==="

# Update system
apt-get update
apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
rm get-docker.sh

# Install Docker Compose
apt-get install -y docker-compose

# Clone the repository
cd /root
git clone https://github.com/cjsbass/youtube-torrent-downloader.git
cd youtube-torrent-downloader/youtube-torrent/backend

# Create docker-compose override for this specific server
cat > docker-compose.override.yml << EOF
version: '3.8'
services:
  youtube-torrent-api:
    environment:
      - BASE_URL=http://\$(curl -s http://169.254.169.254/v1/interfaces/0/ipv4/address)/torrents
    ports:
      - "80:5000"
EOF

# Create volumes
docker volume create torrent-data
docker volume create media-data

# Build and run
docker-compose up -d --build

# Set up auto-update script
cat > /root/update_youtube_torrent.sh << 'UPDATEEOF'
#!/bin/bash
cd /root/youtube-torrent-downloader
git pull
cd youtube-torrent/backend
docker-compose up -d --build
UPDATEEOF

chmod +x /root/update_youtube_torrent.sh

# Add cron job to auto-update every hour
echo "0 * * * * /root/update_youtube_torrent.sh >> /var/log/youtube-torrent-update.log 2>&1" | crontab -

echo ""
echo "=== Setup Complete ==="
echo "YouTube Torrent API is now running!"
echo "The API will automatically pull updates from GitHub every hour."
echo ""

