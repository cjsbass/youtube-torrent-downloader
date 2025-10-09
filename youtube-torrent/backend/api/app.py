import os
import subprocess
import tempfile
import uuid
from pathlib import Path
from urllib.parse import quote

from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
import yt_dlp

app = Flask(__name__)
CORS(app)

# Configuration
API_KEY = os.environ.get("API_KEY", "your-secret-api-key")  # Change this in production
MEDIA_DIR = os.environ.get("MEDIA_DIR", "/srv/media")
TORRENTS_DIR = os.environ.get("TORRENTS_DIR", "/srv/torrents")
BASE_URL = os.environ.get("BASE_URL", "https://example.com/torrents")
TRACKER = os.environ.get("TRACKER", "udp://tracker.opentrackr.org:1337/announce")

# Ensure directories exist
os.makedirs(MEDIA_DIR, exist_ok=True)
os.makedirs(TORRENTS_DIR, exist_ok=True)


def authenticate():
    api_key = request.headers.get('X-API-Key')
    return api_key == API_KEY


def sanitize_filename(filename):
    """Sanitize filename for filesystem safety"""
    # Remove invalid chars and replace spaces
    safe_filename = "".join(c if c.isalnum() or c in "._- " else "_" for c in filename)
    # Limit length
    return safe_filename[:100].strip()


def download_video(url):
    """Download YouTube video using yt-dlp"""
    video_info = {}
    
    # Get video info first
    with yt_dlp.YoutubeDL({"quiet": True}) as ydl:
        info = ydl.extract_info(url, download=False)
        video_info["title"] = sanitize_filename(info.get("title", "video"))
        video_info["id"] = info.get("id", str(uuid.uuid4()))
    
    # Generate unique filename
    filename = f"{video_info['title']}-{video_info['id']}"
    output_path = os.path.join(MEDIA_DIR, filename)
    
    # Download the video
    ydl_opts = {
        "format": "best",
        "outtmpl": f"{output_path}.%(ext)s",
        "quiet": True,
    }
    
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(url, download=True)
        video_info["filepath"] = f"{output_path}.{info['ext']}"
        video_info["filename"] = f"{filename}.{info['ext']}"
    
    return video_info


def create_torrent(video_path, video_name):
    """Create a .torrent file for the video"""
    torrent_path = os.path.join(TORRENTS_DIR, f"{video_name}.torrent")
    
    # Use mktorrent to create the .torrent file
    cmd = [
        "mktorrent",
        "-a", TRACKER,
        "-o", torrent_path,
        "-v",  # verbose
        video_path
    ]
    
    try:
        subprocess.run(cmd, check=True, capture_output=True, text=True)
        return torrent_path
    except subprocess.CalledProcessError as e:
        print(f"Error creating torrent: {e.stderr}")
        raise


def add_to_transmission(torrent_path):
    """Add the torrent to transmission-daemon"""
    cmd = ["transmission-remote", "-a", torrent_path]
    
    try:
        subprocess.run(cmd, check=True, capture_output=True, text=True)
        return True
    except subprocess.CalledProcessError as e:
        print(f"Error adding to Transmission: {e.stderr}")
        raise


@app.route("/api/add", methods=["POST"])
def add_video():
    if not authenticate():
        return jsonify({"error": "Unauthorized"}), 401
    
    data = request.get_json()
    
    if not data or "url" not in data:
        return jsonify({"error": "URL is required"}), 400
    
    try:
        # Download the YouTube video
        video_info = download_video(data["url"])
        
        # Create torrent file
        torrent_path = create_torrent(video_info["filepath"], video_info["filename"])
        
        # Add to transmission for seeding
        add_to_transmission(torrent_path)
        
        # Get the filename of the torrent
        torrent_filename = os.path.basename(torrent_path)
        
        # Generate the download URL
        torrent_url = f"{BASE_URL}/{quote(torrent_filename)}"
        
        return jsonify({
            "success": True,
            "torrent_url": torrent_url,
            "video_title": video_info["title"]
        })
        
    except Exception as e:
        return jsonify({
            "error": str(e)
        }), 500


@app.route("/torrents/<path:filename>")
def serve_torrent(filename):
    """Serve the torrent file (for local development only)"""
    return send_from_directory(TORRENTS_DIR, filename)


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)
