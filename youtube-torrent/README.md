# YouTube-to-Torrent Relay System

A bridge between YouTube and uTorrent that allows you to download videos as torrents for reliable, resumable downloads.

## Overview

This project provides a complete system that:

1. Adds a "Download as Torrent" button to YouTube pages via a Chrome extension
2. Sends the video URL to a backend server
3. Downloads the video on the server, creates a .torrent file, and starts seeding
4. Returns the .torrent file to the user
5. Automatically loads the torrent into uTorrent for reliable, resumable downloads

This system is especially useful when:
- You have unreliable internet connections
- You need to pause/resume large downloads
- You want to download videos for offline viewing without relying on centralized services

## Components

The project consists of three main components:

1. **Chrome Extension**: Adds a "Download as Torrent" button to YouTube pages
2. **Backend API**: Flask-based API that handles downloading videos and creating torrents
3. **Server Setup Scripts**: Scripts to configure a VPS with Transmission and Nginx

## Requirements

### Backend Server (VPS)

- Ubuntu 20.04+ or Debian 11+
- 1-2 vCPUs
- 2GB RAM
- 50GB+ storage
- 1Gbps network uplink
- Public IP address

Recommended VPS providers: Hetzner, Contabo, OVH, DigitalOcean

### Client (User)

- Google Chrome browser
- uTorrent or similar torrent client
- Internet connection

## Installation

### 1. Server Setup

1. Rent a VPS with the requirements mentioned above
2. SSH into your server
3. Clone this repository:

```bash
git clone https://github.com/yourusername/youtube-torrent.git
cd youtube-torrent
```

4. Copy the backend files to the server:

```bash
scp -r backend/* user@your-vps:/tmp/
```

5. Copy the server setup script:

```bash
scp server_setup/setup.sh user@your-vps:/tmp/
```

6. SSH into your VPS and run the setup script:

```bash
chmod +x /tmp/setup.sh
sudo /tmp/setup.sh
```

7. Follow the prompts in the setup script
8. Copy the API key displayed at the end of the script setup

### 2. Chrome Extension Setup

1. Open Chrome and navigate to `chrome://extensions/`
2. Enable "Developer mode" (toggle in the top right)
3. Click "Load unpacked" and select the `chrome_extension` directory
4. Click on the extension icon in your toolbar
5. Enter your server's API URL and the API key from the server setup
6. Save the settings

### 3. uTorrent Configuration

1. Open uTorrent
2. Go to Settings > Preferences
3. Select "Directories" in the left panel
4. Check "Automatically load .torrent files from:"
5. Set the directory to your Downloads folder
6. Click "Apply" and "OK"

## Usage

1. Navigate to any YouTube video
2. Click the "Download as Torrent" button added by the extension
3. The .torrent file will be downloaded automatically
4. uTorrent will automatically load the torrent (if configured)
5. The download will begin, and you can pause/resume it at any time

## Troubleshooting

### The "Download as Torrent" button doesn't appear
- Make sure the extension is enabled
- Reload the YouTube page
- Check if you're on a video page (youtube.com/watch?v=...)

### API connection error
- Verify your server is running
- Check that your API URL and API key are correct in the extension settings
- Check your server's firewall settings

### uTorrent doesn't automatically load the torrent
- Verify your uTorrent settings for automatically loading torrents
- Check if the .torrent file was downloaded to the correct directory

## Advanced Configuration

### Changing API Keys

1. On your server, edit the .env file:

```bash
sudo nano /srv/youtube-torrent/.env
```

2. Change the API_KEY value
3. Restart the API service:

```bash
sudo systemctl restart youtube-torrent-api
```

4. Update the API key in your Chrome extension settings

### Customizing Video Quality

By default, the system downloads videos in the highest available quality. To change this:

1. Edit the backend app.py file:

```bash
sudo nano /srv/youtube-torrent/api/app.py
```

2. Find the `download_video` function and modify the `ydl_opts` dictionary:

```python
ydl_opts = {
    "format": "best[height<=720]",  # Example: limit to 720p
    "outtmpl": f"{output_path}.%(ext)s",
    "quiet": True,
}
```

3. Restart the API service:

```bash
sudo systemctl restart youtube-torrent-api
```

## Security Considerations

- The API is protected with an API key
- HTTPS is enforced for all connections
- The media directory is not accessible via the web
- Only .torrent files are served publicly

## License

MIT License

## Contributors

- Your Name
- Other Contributors
