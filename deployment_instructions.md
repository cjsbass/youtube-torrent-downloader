# Deployment Instructions for YouTube Torrent API

## 1. Authenticate with Railway

Run the following command to login to Railway:
```
railway login
```

This will open a browser window where you'll need to authenticate with your Railway account.

## 2. Initialize a New Project

Navigate to the backend directory and initialize a new Railway project:
```
cd youtube-torrent/backend
railway init
```

When prompted, name the project "youtube-torrent-api".

## 3. Configure Environment Variables

Set up the necessary environment variables:
```
railway variables set API_KEY="a22a0390f46cdf18754c9c6d172a2432e1a9f39cc1d04266813ea94dfab2b56b"
railway variables set MEDIA_DIR="/srv/media"
railway variables set TORRENTS_DIR="/srv/torrents"
railway variables set BASE_URL="$RAILWAY_PUBLIC_DOMAIN/torrents"
railway variables set TRACKER="udp://tracker.opentrackr.org:1337/announce,udp://open.tracker.cl:1337/announce,udp://tracker.openbittorrent.com:6969/announce"
railway variables set MAX_STORAGE_GB="5"
railway variables set CLEANUP_THRESHOLD_GB="4.5"
```

## 4. Deploy the Application

Deploy the backend:
```
railway up
```

## 5. Generate a Public Domain

Create a custom domain for your API:
```
railway domain
```

This will generate a public URL for your API.

## 6. Set up GitHub Integration (Optional)

To enable automatic deployments from your GitHub repository:

1. Generate a Railway token:
```
railway login
railway whoami --token
```

2. In your GitHub repository:
   - Go to "Settings" > "Secrets and variables" > "Actions"
   - Click "New repository secret"
   - Name: `RAILWAY_TOKEN`
   - Value: Paste the token you copied
   - Click "Add secret"

3. Make sure the GitHub Actions workflow file exists at `.github/workflows/railway-deploy.yml`.

## 7. Install/Update the Chrome Extension

1. Go to `chrome://extensions/`
2. Enable Developer Mode (top-right toggle)
3. Click "Load unpacked" and select the `youtube-torrent/chrome_extension` folder
   OR drag-and-drop the `build/youtube-torrent-extension.zip` file

The extension is now configured to connect to your Railway-hosted API.
