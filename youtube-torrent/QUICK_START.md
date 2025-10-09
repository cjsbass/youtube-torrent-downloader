# YouTube Torrent Downloader - Quick Start Guide

This guide will help you quickly set up and use the YouTube Torrent Downloader.

## Initial Setup

### Backend API Setup (Railway)

1. First, deploy the backend API to Railway:

```bash
cd youtube-torrent/backend
./deploy_railway.sh
```

2. Follow the prompts to:
   - Log in to Railway
   - Create a new project named "youtube-torrent-api"
   - Link to your GitHub repository
   - Set environment variables

3. Note the API Key and URL displayed at the end of the deployment process.

### Chrome Extension Setup

1. Package the extension:

```bash
cd youtube-torrent/chrome_extension
./package_extension.sh
```

2. Install in Chrome:
   - Open `chrome://extensions/`
   - Enable "Developer mode"
   - Click "Load unpacked" and select the `youtube-torrent/chrome_extension` folder

3. Configure the extension:
   - Click the extension icon in your toolbar
   - Enter the API URL (from Railway deployment)
   - Enter the API Key (from Railway deployment)
   - Click "Save Settings"

## Usage

1. Go to any YouTube video
2. You'll see a "Download as Torrent" button next to the Share button
3. Click it to process the video
4. The torrent file will be downloaded to your computer
5. Open the torrent file with your preferred torrent client
6. The video will download through the torrent network

## Troubleshooting

If the "Download as Torrent" button doesn't appear:
- Make sure you're on a YouTube watch page
- Try refreshing the page
- Check that the extension is enabled

If you get an error when downloading:
- Check your API URL and API Key settings
- Make sure your Railway deployment is running
- Verify your internet connection

If the torrent doesn't download the video:
- Ensure you have a torrent client installed
- Check if the video is available on YouTube
- Try a different public tracker in your Railway environment variables

## Advanced Configuration

See the main README.md file for advanced configuration options and self-hosting instructions.
