#!/bin/bash
# Setup Railway with GitHub Integration for Auto-Deployment

set -e

echo "========================================="
echo "Setting up Railway with GitHub Integration"
echo "========================================="
echo ""

# Navigate to backend directory
cd "$(dirname "$0")/youtube-torrent/backend"

echo "Step 1: Logging into Railway..."
echo "This will open a browser window for authentication."
railway login

echo ""
echo "Step 2: Creating Railway project from GitHub..."
echo "This will link your GitHub repository for automatic deployments."
railway init

echo ""
echo "Step 3: Linking to your GitHub repository..."
echo "Please follow the prompts to connect to: cjsbass/youtube-torrent-downloader"
railway link

echo ""
echo "Step 4: Setting environment variables..."
railway variables set API_KEY="a22a0390f46cdf18754c9c6d172a2432e1a9f39cc1d04266813ea94dfab2b56b"
railway variables set MEDIA_DIR="/srv/media"
railway variables set TORRENTS_DIR="/srv/torrents"
railway variables set TRACKER="udp://tracker.opentrackr.org:1337/announce,udp://open.tracker.cl:1337/announce,udp://tracker.openbittorrent.com:6969/announce"
railway variables set MAX_STORAGE_GB="5"
railway variables set CLEANUP_THRESHOLD_GB="4.5"

echo ""
echo "Step 5: Generating public domain..."
railway domain

echo ""
echo "Step 6: Getting Railway domain for BASE_URL..."
RAILWAY_DOMAIN=$(railway domain 2>&1 | grep -o 'https://[^[:space:]]*' | head -1 | sed 's/https:\/\///')

if [ -z "$RAILWAY_DOMAIN" ]; then
    echo "⚠️  Could not auto-detect Railway domain."
    echo "Please set BASE_URL manually after deployment:"
    echo "railway variables set BASE_URL=\"https://your-domain.railway.app/torrents\""
else
    railway variables set BASE_URL="https://${RAILWAY_DOMAIN}/torrents"
    echo "✅ BASE_URL set to: https://${RAILWAY_DOMAIN}/torrents"
fi

echo ""
echo "Step 7: Triggering initial deployment..."
railway up --detach

echo ""
echo "========================================="
echo "✅ GitHub Integration Setup Complete!"
echo "========================================="
echo ""
echo "Your Railway project is now linked to GitHub!"
echo "Repository: cjsbass/youtube-torrent-downloader"
echo ""
echo "🔄 Automatic Deployments:"
echo "Every time you push to the 'main' branch, Railway will automatically:"
echo "  1. Pull the latest code"
echo "  2. Build the application"
echo "  3. Deploy the new version"
echo ""
echo "📊 To monitor your deployment:"
echo "  - View logs: railway logs"
echo "  - Open dashboard: railway open"
echo "  - Check status: railway status"
echo ""
echo "🔗 Your API endpoints:"
echo "  - Health check: https://${RAILWAY_DOMAIN}/api/health"
echo "  - Add video: https://${RAILWAY_DOMAIN}/api/add (POST)"
echo ""
echo "🔑 API Key: a22a0390f46cdf18754c9c6d172a2432e1a9f39cc1d04266813ea94dfab2b56b"
echo ""
echo "Next steps:"
echo "1. Reload your Chrome extension"
echo "2. Test by clicking 'Download as Torrent' on a YouTube video"
echo "3. Make code changes and push to GitHub - Railway will auto-deploy!"
echo ""
