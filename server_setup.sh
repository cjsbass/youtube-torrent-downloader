#!/bin/bash
# YouTube Torrent Server Setup Script

# Exit on error
set -e

echo "=== YouTube-to-Torrent Server Setup ==="
echo "Setting up the YouTube-to-Torrent backend..."

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
    mktorrent \
    ffmpeg \
    git

# Create necessary directories
echo "Creating directory structure..."
mkdir -p /srv/media
mkdir -p /srv/torrents
mkdir -p /srv/logs
mkdir -p /srv/youtube-torrent

# Set proper permissions
chown -R www-data:www-data /srv/torrents

# Clone the repository
echo "Cloning the repository..."
cd /srv
git clone https://github.com/cjsbass/youtube-torrent-downloader.git

# Set up Python environment
echo "Setting up Python environment..."
cd /srv/youtube-torrent
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r /srv/youtube-torrent-downloader/youtube-torrent/backend/requirements.txt

# Create environment file
echo "Setting up environment variables..."
cat > /srv/youtube-torrent/.env << EOF
API_KEY=a22a0390f46cdf18754c9c6d172a2432e1a9f39cc1d04266813ea94dfab2b56b
MEDIA_DIR=/srv/media
TORRENTS_DIR=/srv/torrents
BASE_URL=http://$(hostname -I | awk '{print $1}')/torrents
TRACKER=udp://tracker.opentrackr.org:1337/announce,udp://open.tracker.cl:1337/announce,udp://tracker.openbittorrent.com:6969/announce
MAX_STORAGE_GB=20
CLEANUP_THRESHOLD_GB=15
EOF

# Link backend code
ln -sf /srv/youtube-torrent-downloader/youtube-torrent/backend /srv/youtube-torrent/app

# Configure Nginx
echo "Configuring Nginx..."
cat > /etc/nginx/sites-available/youtube-torrent << EOF
server {
    listen 80;
    server_name _;

    location /api {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /torrents {
        alias /srv/torrents;
        add_header Content-Disposition "attachment";
        autoindex off;
    }
}
EOF

# Enable the site
ln -sf /etc/nginx/sites-available/youtube-torrent /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Create systemd service for the API
echo "Creating systemd service..."
cat > /etc/systemd/system/youtube-torrent.service << EOF
[Unit]
Description=YouTube Torrent API Service
After=network.target

[Service]
User=root
Group=root
WorkingDirectory=/srv/youtube-torrent-downloader/youtube-torrent/backend
ExecStart=/srv/youtube-torrent/venv/bin/gunicorn -w 4 -b 0.0.0.0:5000 api.app:app
Restart=always
Environment="PATH=/srv/youtube-torrent/venv/bin"
EnvironmentFile=/srv/youtube-torrent/.env

[Install]
WantedBy=multi-user.target
EOF

# Set up basic firewall
echo "Setting up firewall..."
apt-get install -y ufw
ufw allow ssh
ufw allow http
ufw allow https
ufw --force enable

# Reload systemd and restart nginx
echo "Starting services..."
systemctl daemon-reload
systemctl enable youtube-torrent
systemctl start youtube-torrent
systemctl restart nginx

# Display server info
echo ""
echo "=== Setup Complete ==="
echo ""
echo "Your YouTube Torrent API is now running!"
echo ""
echo "API URL: http://$(hostname -I | awk '{print $1}')"
echo "API Key: a22a0390f46cdf18754c9c6d172a2432e1a9f39cc1d04266813ea94dfab2b56b"
echo ""
echo "You should now update your Chrome extension with these details."
echo ""
