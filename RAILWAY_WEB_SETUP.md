# Railway Web Setup - GitHub Auto-Deploy

Follow these steps to set up automatic deployment from GitHub to Railway:

## Step 1: Create Railway Account & Deploy from GitHub

1. Go to https://railway.app/
2. Click "Login" (top right)
3. Sign in with your GitHub account
4. Once logged in, click "New Project"
5. Select "Deploy from GitHub repo"
6. Choose your repository: **cjsbass/youtube-torrent-downloader**
7. Railway will ask which directory to deploy from - enter: **youtube-torrent/backend**

## Step 2: Configure Environment Variables

Once the project is created:

1. Click on your deployment
2. Go to the "Variables" tab
3. Add the following environment variables:

```
API_KEY=a22a0390f46cdf18754c9c6d172a2432e1a9f39cc1d04266813ea94dfab2b56b
MEDIA_DIR=/srv/media
TORRENTS_DIR=/srv/torrents
TRACKER=udp://tracker.opentrackr.org:1337/announce,udp://open.tracker.cl:1337/announce,udp://tracker.openbittorrent.com:6969/announce
MAX_STORAGE_GB=5
CLEANUP_THRESHOLD_GB=4.5
```

4. After adding variables, Railway will automatically redeploy

## Step 3: Get Your Railway Domain

1. Go to the "Settings" tab
2. Under "Networking" section, click "Generate Domain"
3. Railway will create a public URL like: `https://youtube-torrent-api-production.up.railway.app`
4. Copy this URL

## Step 4: Set BASE_URL Variable

1. Go back to the "Variables" tab
2. Add one more variable:
```
BASE_URL=https://your-railway-domain.railway.app/torrents
```
(Replace with your actual Railway domain from Step 3)

## Step 5: Verify Deployment

1. Wait for the deployment to complete (watch the "Deployments" tab)
2. Once deployed, test the health check:
   - Visit: `https://your-railway-domain.railway.app/api/health`
   - You should see a JSON response with status "ok"

## Step 6: Update Chrome Extension (if needed)

1. Open the Chrome extension popup
2. Verify the API URL matches your Railway domain
3. Click "Save Settings"

## ✅ Done!

Your backend is now:
- ✅ Running in Railway's cloud
- ✅ Connected to your GitHub repository
- ✅ Will auto-deploy on every push to main branch
- ✅ Available 24/7 without your computer running

## Testing

1. Go to any YouTube video
2. Click "Download as Torrent"
3. The extension will connect to your Railway backend
4. The torrent file will be downloaded

## Troubleshooting

If the health check fails:
- Check the "Logs" tab in Railway for errors
- Verify all environment variables are set correctly
- Make sure the deployment completed successfully

If the extension doesn't connect:
- Verify the API URL in the extension matches your Railway domain
- Check that BASE_URL is set correctly in Railway
- Look at browser console for error messages (F12 → Console)
