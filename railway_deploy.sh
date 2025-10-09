#!/bin/bash
# Railway deployment script using CLI

# Exit on error
set -e

# Generate API key if not provided
API_KEY=$(openssl rand -hex 32)
echo "Generated API key: $API_KEY"

# Variables
PROJECT_NAME="youtube-torrent-api"
GITHUB_REPO="youtube-torrent-downloader"
ROOT_DIR="youtube-torrent/backend"

# Step 1: Login to Railway
echo "Step 1: Please login to Railway (this will open a browser)"
railway login

# Step 2: Initialize a new project
echo "Step 2: Creating new Railway project: $PROJECT_NAME"
railway init --name "$PROJECT_NAME"

# Step 3: Set the GitHub repository integration
echo "Step 3: Setting up GitHub integration"
echo "⚠️ IMPORTANT: You'll need to manually connect your GitHub repo in the Railway dashboard"
echo "After logging in, go to your project, click 'Settings' → 'Source' → 'GitHub' and select your repository"

# Step 4: Set environment variables
echo "Step 4: Setting environment variables"
railway variables set API_KEY="$API_KEY"
railway variables set MEDIA_DIR="/srv/media"
railway variables set TORRENTS_DIR="/srv/torrents"
railway variables set TRACKER="udp://tracker.opentrackr.org:1337/announce,udp://open.tracker.cl:1337/announce,udp://tracker.openbittorrent.com:6969/announce"
railway variables set MAX_STORAGE_GB="5"
railway variables set CLEANUP_THRESHOLD_GB="4.5"

# Step 5: Set the root directory for the service
echo "Step 5: Setting root directory to $ROOT_DIR"
echo "⚠️ NOTE: You'll need to manually set the root directory in the Railway dashboard"
echo "Go to your project, click 'Settings' → 'Source' → Set 'Root Directory' to '$ROOT_DIR'"
echo "And set 'Health Check Path' to '/api/health'"

# Step 6: Deploy the application
echo "Step 6: Deploying application to Railway"
railway up --detach

# Step 7: Generate a domain
echo "Step 7: Generating a Railway domain"
railway domain

# Final instructions
echo ""
echo "=== DEPLOYMENT COMPLETE ==="
echo ""
echo "Your API Key is: $API_KEY"
echo "Save this key for use in your Chrome extension"
echo ""
echo "To view your Railway domain, run: railway domain"
echo "To view your service logs, run: railway logs"
echo "To open the Railway dashboard, run: railway open"
echo ""
echo "Remember to configure your Chrome extension with:"
echo "API URL: https://your-railway-domain.up.railway.app"
echo "API Key: $API_KEY"
echo ""
echo "From now on, pushing to your main branch will automatically deploy to Railway!"

