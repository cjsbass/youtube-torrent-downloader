#!/bin/bash

# YouTube-to-Torrent Server Setup Script
# This script sets up the entire backend environment on a Debian/Ubuntu VPS

# Exit on error
set -e

echo "=== YouTube-to-Torrent Server Setup ==="
echo "This script will set up the YouTube-to-Torrent backend on this server."

# Check if running as root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Update system packages
echo "Updating system packages..."
apt-get update
apt-get upgrade -y

# Install required dependencies
echo "Installing required dependencies..."
apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    nginx \
    certbot \
    python3-certbot-nginx \
    transmission-daemon \
    mktorrent \
    ffmpeg

# Create necessary directories
echo "Creating directory structure..."
mkdir -p /srv/media
mkdir -p /srv/torrents
mkdir -p /srv/logs
mkdir -p /srv/youtube-torrent

# Set proper permissions
chown -R www-data:www-data /srv/torrents
chown -R debian-transmission:debian-transmission /srv/media

# Stop transmission-daemon before modifying its settings
systemctl stop transmission-daemon

# Configure Transmission
echo "Configuring Transmission..."
cat > /etc/transmission-daemon/settings.json << EOF
{
    "alt-speed-down": 50,
    "alt-speed-enabled": false,
    "alt-speed-time-begin": 540,
    "alt-speed-time-day": 127,
    "alt-speed-time-enabled": false,
    "alt-speed-time-end": 1020,
    "alt-speed-up": 50,
    "bind-address-ipv4": "0.0.0.0",
    "bind-address-ipv6": "::",
    "blocklist-enabled": false,
    "blocklist-url": "http://www.example.com/blocklist",
    "cache-size-mb": 4,
    "dht-enabled": true,
    "download-dir": "/srv/media",
    "download-limit": 100,
    "download-limit-enabled": 0,
    "download-queue-enabled": true,
    "download-queue-size": 5,
    "encryption": 1,
    "idle-seeding-limit": 30,
    "idle-seeding-limit-enabled": false,
    "incomplete-dir": "/srv/media",
    "incomplete-dir-enabled": false,
    "lpd-enabled": false,
    "max-peers-global": 200,
    "message-level": 1,
    "peer-congestion-algorithm": "",
    "peer-id-ttl-hours": 6,
    "peer-limit-global": 200,
    "peer-limit-per-torrent": 50,
    "peer-port": 51413,
    "peer-port-random-high": 65535,
    "peer-port-random-low": 49152,
    "peer-port-random-on-start": false,
    "peer-socket-tos": "default",
    "pex-enabled": true,
    "port-forwarding-enabled": true,
    "preallocation": 1,
    "prefetch-enabled": true,
    "queue-stalled-enabled": true,
    "queue-stalled-minutes": 30,
    "ratio-limit": 2,
    "ratio-limit-enabled": false,
    "rename-partial-files": true,
    "rpc-authentication-required": true,
    "rpc-bind-address": "0.0.0.0",
    "rpc-enabled": true,
    "rpc-host-whitelist": "",
    "rpc-host-whitelist-enabled": false,
    "rpc-password": "{6b9d589d0e2a91fc1b75fe11cb52e55363f1b92eUW6qOMgX",
    "rpc-port": 9091,
    "rpc-url": "/transmission/",
    "rpc-username": "transmission",
    "rpc-whitelist": "127.0.0.1,192.168.*.*",
    "rpc-whitelist-enabled": true,
    "scrape-paused-torrents-enabled": true,
    "script-torrent-done-enabled": false,
    "script-torrent-done-filename": "",
    "seed-queue-enabled": false,
    "seed-queue-size": 10,
    "speed-limit-down": 100,
    "speed-limit-down-enabled": false,
    "speed-limit-up": 100,
    "speed-limit-up-enabled": false,
    "start-added-torrents": true,
    "trash-original-torrent-files": false,
    "umask": 2,
    "upload-limit": 100,
    "upload-limit-enabled": 0,
    "upload-slots-per-torrent": 14,
    "utp-enabled": true
}
EOF

# Start Transmission daemon
systemctl start transmission-daemon

# Clone the application repository
echo "Setting up the YouTube-to-Torrent application..."
cd /srv/youtube-torrent

# Create a Python virtual environment and install dependencies
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install flask flask-cors yt-dlp gunicorn python-dotenv

# Create environment file
cat > /srv/youtube-torrent/.env << EOF
API_KEY=$(openssl rand -hex 32)
MEDIA_DIR=/srv/media
TORRENTS_DIR=/srv/torrents
BASE_URL=https://$(hostname -f)/torrents
TRACKER=udp://tracker.opentrackr.org:1337/announce
EOF

# Configure Nginx
echo "Configuring Nginx..."
cat > /etc/nginx/sites-available/youtube-torrent << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $(hostname -f);

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name $(hostname -f);

    ssl_certificate /etc/letsencrypt/live/$(hostname -f)/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$(hostname -f)/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    # API endpoints
    location /api {
        proxy_pass http://localhost:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Serve torrent files
    location /torrents {
        alias /srv/torrents;
        add_header Content-Disposition "attachment";
        autoindex off;
    }

    # Block access to media files
    location /media {
        deny all;
        return 404;
    }
}
EOF

# Enable the site
ln -sf /etc/nginx/sites-available/youtube-torrent /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default  # Remove default site

# Set up Let's Encrypt
echo "Please enter your email address for Let's Encrypt notifications:"
read EMAIL

certbot --nginx -d $(hostname -f) --non-interactive --agree-tos --email $EMAIL

# Create systemd service for the API
echo "Creating systemd service..."
cat > /etc/systemd/system/youtube-torrent-api.service << EOF
[Unit]
Description=YouTube to Torrent API Service
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=/srv/youtube-torrent
ExecStart=/srv/youtube-torrent/venv/bin/gunicorn -w 4 -b 127.0.0.1:5000 api.app:app
Restart=always
Environment="PATH=/srv/youtube-torrent/venv/bin"
EnvironmentFile=/srv/youtube-torrent/.env

[Install]
WantedBy=multi-user.target
EOF

# Copy your application files
echo "Please copy your application files to /srv/youtube-torrent/api/"
echo "After copying, run: systemctl enable youtube-torrent-api && systemctl start youtube-torrent-api"

# Reload systemd and restart nginx
systemctl daemon-reload
systemctl restart nginx

# Display API key for the user
echo ""
echo "=== Setup Complete ==="
echo "Your API Key is: $(grep API_KEY /srv/youtube-torrent/.env | cut -d= -f2)"
echo ""
echo "Use this API key in your Chrome extension settings."
echo ""
echo "To complete setup:"
echo "1. Copy your application files to /srv/youtube-torrent/api/"
echo "2. Run: systemctl enable youtube-torrent-api && systemctl start youtube-torrent-api"
echo ""
echo "Your torrent files will be available at:"
echo "https://$(hostname -f)/torrents/"
