import os
import sys
import subprocess
import tempfile
import uuid
import shutil
import time
import logging
from pathlib import Path
from urllib.parse import quote

from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
import yt_dlp

# Import configuration
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from config.settings import (
    API_KEY, MEDIA_DIR, TORRENTS_DIR, BASE_URL,
    TRACKER, TRACKERS, MAX_STORAGE_GB, CLEANUP_THRESHOLD_GB
)

app = Flask(__name__)
CORS(app)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Ensure directories exist
os.makedirs(MEDIA_DIR, exist_ok=True)
os.makedirs(TORRENTS_DIR, exist_ok=True)

# Check available disk space
def check_disk_space(directory):
    """Return available disk space in GB"""
    stats = shutil.disk_usage(directory)
    return stats.free / (1024 * 1024 * 1024)  # Convert to GB

# Check if cleanup is needed
def cleanup_needed():
    """Check if we need to clean up old files"""
    return check_disk_space(MEDIA_DIR) < (MAX_STORAGE_GB - CLEANUP_THRESHOLD_GB)

# Clean up oldest files
def cleanup_old_files():
    """Remove oldest files when disk space is low"""
    if not cleanup_needed():
        return
        
    logger.info("Cleaning up old files due to low disk space")
    
    # Get list of files with their modification times
    media_files = []
    for file in Path(MEDIA_DIR).iterdir():
        if file.is_file():
            media_files.append((file, file.stat().st_mtime))
    
    # Sort by modification time (oldest first)
    media_files.sort(key=lambda x: x[1])
    
    # Delete oldest files until we have enough space
    deleted_count = 0
    for file, _ in media_files:
        if check_disk_space(MEDIA_DIR) > (MAX_STORAGE_GB - CLEANUP_THRESHOLD_GB):
            break
            
        # Also delete corresponding torrent file
        torrent_file = Path(TORRENTS_DIR) / f"{file.stem}.torrent"
        if torrent_file.exists():
            torrent_file.unlink()
            
        # Delete media file
        file.unlink()
        deleted_count += 1
        
    if deleted_count > 0:
        logger.info(f"Deleted {deleted_count} old files")
        
# Run cleanup check at startup
cleanup_old_files()


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
    """Create a .torrent file for the video with multiple trackers"""
    torrent_path = os.path.join(TORRENTS_DIR, f"{video_name}.torrent")
    
    # Use mktorrent to create the .torrent file
    cmd = ["mktorrent", "-o", torrent_path]
    
    # Add all trackers
    for tracker in TRACKERS:
        if tracker and tracker.strip():
            cmd.extend(["-a", tracker.strip()])
    
    # If no valid trackers, use default
    if "-a" not in cmd:
        cmd.extend(["-a", "udp://tracker.opentrackr.org:1337/announce"])
    
    # Add verbosity and source path
    cmd.extend(["-v", video_path])
    
    try:
        logger.info(f"Creating torrent for {video_name}")
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
        logger.debug(f"mktorrent output: {result.stdout}")
        return torrent_path
    except subprocess.CalledProcessError as e:
        logger.error(f"Error creating torrent: {e.stderr}")
        # Try with just the first tracker if multiple trackers failed
        if len(TRACKERS) > 1:
            logger.info("Retrying with single tracker")
            fallback_cmd = [
                "mktorrent",
                "-a", TRACKERS[0],
                "-o", torrent_path,
                "-v",
                video_path
            ]
            try:
                subprocess.run(fallback_cmd, check=True, capture_output=True, text=True)
                return torrent_path
            except subprocess.CalledProcessError as e2:
                logger.error(f"Fallback also failed: {e2.stderr}")
                raise
        raise


def add_to_transmission(torrent_path):
    """Add the torrent to transmission-daemon"""
    cmd = ["transmission-remote", "-a", torrent_path]
    
    try:
        logger.info(f"Adding torrent to Transmission: {os.path.basename(torrent_path)}")
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
        logger.debug(f"Transmission output: {result.stdout}")
        return True
    except subprocess.CalledProcessError as e:
        logger.error(f"Error adding to Transmission: {e.stderr}")
        # If Transmission isn't available, we don't want to fail the whole process
        # The user can still download the .torrent file
        logger.warning("Continuing without adding to Transmission")
        return False
    except FileNotFoundError:
        logger.error("Transmission command not found - is it installed?")
        # This error indicates Transmission isn't installed
        # Again, don't fail the process as users can still download the .torrent
        logger.warning("Continuing without adding to Transmission")
        return False


@app.route("/api/add", methods=["POST"])
def add_video():
    if not authenticate():
        logger.warning("Unauthorized API access attempt")
        return jsonify({"error": "Unauthorized"}), 401
    
    data = request.get_json()
    
    if not data or "url" not in data:
        logger.warning("Missing URL in request")
        return jsonify({"error": "URL is required"}), 400
    
    # Check available disk space before processing
    available_space_gb = check_disk_space(MEDIA_DIR)
    if available_space_gb < 1.0:  # Require at least 1GB free
        logger.error(f"Low disk space: {available_space_gb:.2f}GB available")
        cleanup_old_files()  # Try to clean up
        
        # Check again after cleanup
        if check_disk_space(MEDIA_DIR) < 1.0:
            return jsonify({"error": "Server storage full. Please try again later."}), 507
    
    try:
        url = data["url"]
        logger.info(f"Processing video request: {url}")
        
        # Download the YouTube video
        try:
            video_info = download_video(url)
        except Exception as e:
            logger.error(f"Video download failed: {str(e)}")
            return jsonify({
                "error": f"Failed to download video: {str(e)}"
            }), 400
        
        # Create torrent file
        try:
            torrent_path = create_torrent(video_info["filepath"], video_info["filename"])
        except Exception as e:
            logger.error(f"Torrent creation failed: {str(e)}")
            return jsonify({
                "error": f"Failed to create torrent file: {str(e)}"
            }), 500
        
        # Add to transmission for seeding (non-critical operation)
        # If this fails, we still return success with the torrent file
        transmission_success = False
        try:
            transmission_success = add_to_transmission(torrent_path)
        except Exception as e:
            logger.warning(f"Non-critical: Transmission seeding failed: {str(e)}")
        
        # Get the filename of the torrent
        torrent_filename = os.path.basename(torrent_path)
        
        # Generate the download URL
        torrent_url = f"{BASE_URL}/{quote(torrent_filename)}"
        
        response = {
            "success": True,
            "torrent_url": torrent_url,
            "video_title": video_info["title"],
            "seeding": transmission_success
        }
        
        logger.info(f"Successfully processed video: {video_info['title']}")
        return jsonify(response)
        
    except yt_dlp.utils.DownloadError as e:
        error_message = str(e)
        logger.error(f"YouTube download error: {error_message}")
        
        if "Video unavailable" in error_message:
            return jsonify({"error": "Video is unavailable or private"}), 400
        elif "This video is available for premium users only" in error_message:
            return jsonify({"error": "This video requires a premium account"}), 403
        else:
            return jsonify({"error": f"Download error: {error_message}"}), 400
        
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}", exc_info=True)
        return jsonify({
            "error": f"Server error: {str(e)}"
        }), 500


@app.route("/torrents/<path:filename>")
def serve_torrent(filename):
    """Serve the torrent file (for local development only)"""
    return send_from_directory(TORRENTS_DIR, filename)


@app.route("/api/health", methods=["GET"])
def health_check():
    """Health check endpoint for monitoring"""
    try:
        # Check disk space
        available_space = check_disk_space(MEDIA_DIR)
        
        # Check if torrents directory is writable
        test_file = os.path.join(TORRENTS_DIR, ".test_write")
        try:
            with open(test_file, "w") as f:
                f.write("test")
            os.remove(test_file)
            torrents_writable = True
        except (IOError, OSError):
            torrents_writable = False
            
        # Check if media directory is writable
        test_file = os.path.join(MEDIA_DIR, ".test_write")
        try:
            with open(test_file, "w") as f:
                f.write("test")
            os.remove(test_file)
            media_writable = True
        except (IOError, OSError):
            media_writable = False
            
        return jsonify({
            "status": "ok",
            "timestamp": time.time(),
            "available_space_gb": round(available_space, 2),
            "torrents_dir_writable": torrents_writable,
            "media_dir_writable": media_writable,
            "version": "1.0.0"
        })
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        return jsonify({
            "status": "error",
            "error": str(e)
        }), 500


@app.route("/", methods=["GET"])
def index():
    """Root endpoint with basic info"""
    return jsonify({
        "name": "YouTube Torrent API",
        "description": "An API for downloading YouTube videos as torrents",
        "version": "1.0.0",
        "endpoints": {
            "/api/add": "POST - Add a YouTube video",
            "/api/health": "GET - Health check",
            "/torrents/{filename}": "GET - Download a torrent file"
        }
    })


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)
