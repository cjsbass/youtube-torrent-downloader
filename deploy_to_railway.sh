#!/bin/bash
# Complete Railway Deployment Script for YouTube Torrent API

set -e

echo "========================================="
echo "YouTube Torrent API - Railway Deployment"
echo "========================================="
echo ""

# Navigate to backend directory
cd "$(dirname "$0")/youtube-torrent/backend"

echo "Step 1: Logging into Railway..."
echo "This will open a browser window for authentication."
railway login

echo ""
echo "Step 2: Initializing Railway project..."
railway init --name youtube-torrent-api

echo ""
echo "Step 3: Setting environment variables..."
railway variables set API_KEY="a22a0390f46cdf18754c9c6d172a2432e1a9f39cc1d04266813ea94dfab2b56b"
railway variables set MEDIA_DIR="/srv/media"
railway variables set TORRENTS_DIR="/srv/torrents"
railway variables set TRACKER="udp://tracker.opentrackr.org:1337/announce,udp://open.tracker.cl:1337/announce,udp://tracker.openbittorrent.com:6969/announce"
railway variables set MAX_STORAGE_GB="5"
railway variables set CLEANUP_THRESHOLD_GB="4.5"

echo ""
echo "Step 4: Deploying application to Railway..."
railway up --detach

echo ""
echo "Step 5: Generating public domain..."
RAILWAY_DOMAIN=$(railway domain)

echo ""
echo "Step 6: Setting BASE_URL with Railway domain..."
railway variables set BASE_URL="https://${RAILWAY_DOMAIN}/torrents"

echo ""
echo "========================================="
echo "✅ Deployment Complete!"
echo "========================================="
echo ""
echo "Your API is now deployed at: https://${RAILWAY_DOMAIN}"
echo "API Key: a22a0390f46cdf18754c9c6d172a2432e1a9f39cc1d04266813ea94dfab2b56b"
echo ""
echo "Next steps:"
echo "1. Reload the Chrome extension at chrome://extensions/"
echo "2. The extension is already configured with:"
echo "   API URL: https://youtube-torrent-api-production.up.railway.app"
echo "3. If your Railway domain is different, update it in the extension popup"
echo ""
echo "To view logs: railway logs"
echo "To open dashboard: railway open"
echo ""
