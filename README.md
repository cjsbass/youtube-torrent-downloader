# YouTube Torrent Downloader

A Chrome extension and backend API for downloading YouTube videos as torrents, enabling reliable, resumable downloads.

## Project Components

1. **Backend API**: A Flask API that downloads YouTube videos, creates torrent files, and serves them.
2. **Chrome Extension**: Adds a "Download as Torrent" button to YouTube video pages.

## Deployment Instructions

### Backend API Deployment (Railway)

1. Install Railway CLI:
```
npm i -g @railway/cli
```

2. Login to Railway:
```
railway login
```

3. Navigate to the backend directory:
```
cd youtube-torrent/backend
```

4. Initialize a new Railway project:
```
railway init
```
Choose "youtube-torrent-api" as the project name.

5. Link to GitHub repository:
```
railway link
```

6. Set environment variables:
```
railway variables set API_KEY=your-secure-api-key
railway variables set MEDIA_DIR=/srv/media
railway variables set TORRENTS_DIR=/srv/torrents
railway variables set BASE_URL=https://your-railway-app-url/torrents
railway variables set TRACKER=udp://tracker.opentrackr.org:1337/announce
```

7. Deploy to Railway:
```
railway up
```

8. Get your deployment URL:
```
railway domain
```

### Chrome Extension Setup

1. Open Chrome and navigate to `chrome://extensions/`
2. Enable "Developer mode" in the top right corner
3. Click "Load unpacked" and select the `youtube-torrent/chrome_extension` folder
4. Click on the extension icon in Chrome toolbar
5. Enter your Railway API URL (e.g., `https://youtube-torrent-api.railway.app`) and API Key
6. Click "Save Settings"

## Usage

1. Navigate to any YouTube video
2. Click the "Download as Torrent" button that appears next to the Share button
3. The torrent file will be downloaded to your computer
4. Open the torrent file with your preferred torrent client
5. The video will download through the torrent network

## Self-Hosting

For instructions on self-hosting the backend on your own server, see the setup script in `server_setup/setup.sh`.

## Security Considerations

- Always use HTTPS for your API endpoint
- Keep your API key secret and change it regularly
- Ensure your server has adequate storage for downloaded videos

## License

MIT License
