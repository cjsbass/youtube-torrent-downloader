#!/bin/bash
# Railway deployment helper script

# Generate a secure API key if one isn't provided
if [ -z "$1" ]; then
    API_KEY=$(openssl rand -hex 32)
    echo "Generated API key: $API_KEY"
else
    API_KEY=$1
    echo "Using provided API key"
fi

# Check if Railway CLI is installed
if ! command -v railway &> /dev/null; then
    echo "Railway CLI not found. Installing..."
    npm install -g @railway/cli
fi

# Login to Railway (opens browser)
echo "Please login to Railway in your browser window..."
railway login

# Initialize a new project
echo "Creating a new Railway project..."
railway init
echo "Please name your project 'youtube-torrent-api' when prompted"

# Link to GitHub repository
echo "Linking to GitHub repository..."
railway link

# Set environment variables
echo "Setting environment variables..."
railway variables set API_KEY="$API_KEY"
railway variables set MEDIA_DIR="/srv/media"
railway variables set TORRENTS_DIR="/srv/torrents"

# Get the domain (will be set later)
echo "Getting your Railway domain..."
DOMAIN=$(railway domain)
if [ -z "$DOMAIN" ]; then
    echo "Domain not yet available. Using a placeholder."
    DOMAIN="your-railway-app-url"
fi

railway variables set BASE_URL="https://$DOMAIN/torrents"

# Set trackers
railway variables set TRACKER="udp://tracker.opentrackr.org:1337/announce,udp://open.tracker.cl:1337/announce,udp://tracker.openbittorrent.com:6969/announce"

# Set storage limits
railway variables set MAX_STORAGE_GB="5"
railway variables set CLEANUP_THRESHOLD_GB="4.5"

# Deploy
echo "Deploying to Railway..."
railway up

echo ""
echo "=== DEPLOYMENT COMPLETE ==="
echo ""
echo "Your API Key is: $API_KEY"
echo "Save this key for use in your Chrome extension"
echo ""
echo "Your API URL should be: https://$DOMAIN"
echo "If this is not correct, run 'railway domain' to get your URL"
echo ""
echo "To complete setup:"
echo "1. Open the Chrome extension"
echo "2. Enter your API URL and API Key"
echo "3. Click Save Settings"
echo ""
