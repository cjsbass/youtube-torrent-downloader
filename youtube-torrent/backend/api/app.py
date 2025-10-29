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

from flask import Flask, request, jsonify, send_from_directory, Response, stream_with_context
from flask_cors import CORS
import yt_dlp
import json
import threading
from queue import Queue

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

# Global progress tracking
progress_store = {}
progress_lock = threading.Lock()

def update_progress(job_id, data):
    """Update progress for a specific job"""
    with progress_lock:
        progress_store[job_id] = {
            **data,
            'timestamp': time.time()
        }

def get_progress(job_id):
    """Get progress for a specific job"""
    with progress_lock:
        return progress_store.get(job_id, {'status': 'not_found'})


def authenticate():
    api_key = request.headers.get('X-API-Key')
    return api_key == API_KEY


def sanitize_filename(filename):
    """Sanitize filename for filesystem safety"""
    # Remove invalid chars and replace spaces
    safe_filename = "".join(c if c.isalnum() or c in "._- " else "_" for c in filename)
    # Limit length
    return safe_filename[:100].strip()


def download_video(url, progress_callback=None):
    """Download YouTube video using yt-dlp with progress tracking"""
    video_info = {}
    
    # Progress hook for yt-dlp
    def progress_hook(d):
        if progress_callback and d['status'] == 'downloading':
            percent = d.get('downloaded_bytes', 0) / d.get('total_bytes', 1) * 100
            speed = d.get('speed', 0)
            eta = d.get('eta', 0)
            progress_callback({
                'status': 'downloading',
                'percent': round(percent, 1),
                'speed_mbps': round(speed / 1024 / 1024, 2) if speed else 0,
                'eta_seconds': eta
            })
    
    # Get video info first
    with yt_dlp.YoutubeDL({"quiet": True}) as ydl:
        info = ydl.extract_info(url, download=False)
        video_info["title"] = sanitize_filename(info.get("title", "video"))
        video_info["id"] = info.get("id", str(uuid.uuid4()))
        video_info["duration"] = info.get("duration", 0)
        video_info["filesize"] = info.get("filesize", 0) or info.get("filesize_approx", 0)
    
    # Generate unique filename
    filename = f"{video_info['title']}-{video_info['id']}"
    output_path = os.path.join(MEDIA_DIR, filename)
    
    # Download the video with progress tracking
    # Check if cookies file exists
    cookies_file = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "youtube_cookies.txt"))
    
    ydl_opts = {
        "format": "best",
        "outtmpl": f"{output_path}.%(ext)s",
        "quiet": True,
        "progress_hooks": [progress_hook] if progress_callback else [],
    }
    
    # Use cookies if available
    logger.info(f"Checking for cookies at: {cookies_file}")
    logger.info(f"Cookies file exists: {os.path.exists(cookies_file)}")
    
    if os.path.exists(cookies_file):
        logger.info(f"Using YouTube cookies for authentication from {cookies_file}")
        ydl_opts["cookiefile"] = cookies_file
        # Also try cookies parameter as alternative
        ydl_opts["cookiesfrombrowser"] = None  # Don't use browser cookies
    else:
        logger.warning(f"No cookies file found at {cookies_file} - downloads may fail for some videos")
        # Fallback to Android client
        ydl_opts["extractor_args"] = {
            "youtube": {
                "player_client": ["android"],
                "player_skip": ["webpage", "configs"],
                "skip": ["dash", "hls"]
            }
        }
    
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(url, download=True)
        video_info["filepath"] = f"{output_path}.{info['ext']}"
        video_info["filename"] = f"{filename}.{info['ext']}"
    
    if progress_callback:
        progress_callback({'status': 'complete', 'percent': 100})
    
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


@app.route("/api/progress/<job_id>", methods=["GET"])
def progress_stream(job_id):
    """Stream download progress via Server-Sent Events"""
    def generate():
        while True:
            progress = get_progress(job_id)
            yield f"data: {json.dumps(progress)}\n\n"
            
            if progress.get('status') in ['complete', 'error', 'not_found']:
                break
            
            time.sleep(0.5)  # Update every 500ms
    
    return Response(stream_with_context(generate()), mimetype='text/event-stream')


@app.route("/api/add", methods=["POST"])
def add_video():
    if not authenticate():
        logger.warning("Unauthorized API access attempt")
        return jsonify({"error": "Unauthorized"}), 401
    
    data = request.get_json()
    
    if not data or "url" not in data:
        logger.warning("Missing URL in request")
        return jsonify({"error": "URL is required"}), 400
    
    # Generate job ID for progress tracking
    job_id = str(uuid.uuid4())
    
    # Check available disk space before processing
    available_space_gb = check_disk_space(MEDIA_DIR)
    if available_space_gb < 1.0:  # Require at least 1GB free
        logger.error(f"Low disk space: {available_space_gb:.2f}GB available")
        cleanup_old_files()  # Try to clean up
        
        # Check again after cleanup
        if check_disk_space(MEDIA_DIR) < 1.0:
            return jsonify({"error": "Server storage full. Please try again later."}), 507
    
    # Start processing in background thread
    def process_video():
        try:
            url = data["url"]
            logger.info(f"Processing video request: {url}")
            
            update_progress(job_id, {'status': 'starting', 'percent': 0, 'message': 'Initializing download...'})
            
            # Download the YouTube video with progress tracking
            try:
                def progress_cb(progress_data):
                    update_progress(job_id, progress_data)
                
                video_info = download_video(url, progress_callback=progress_cb)
            except Exception as e:
                logger.error(f"Video download failed: {str(e)}")
                update_progress(job_id, {'status': 'error', 'error': f"Failed to download video: {str(e)}"})
                return
        
            update_progress(job_id, {'status': 'creating_torrent', 'percent': 90, 'message': 'Creating torrent file...'})
            
            # Create torrent file
            try:
                torrent_path = create_torrent(video_info["filepath"], video_info["filename"])
            except Exception as e:
                logger.error(f"Torrent creation failed: {str(e)}")
                update_progress(job_id, {'status': 'error', 'error': f"Failed to create torrent file: {str(e)}"})
                return
            
            # Add to transmission for seeding (non-critical operation)
            update_progress(job_id, {'status': 'seeding', 'percent': 95, 'message': 'Starting seeding...'})
            transmission_success = False
            try:
                transmission_success = add_to_transmission(torrent_path)
            except Exception as e:
                logger.warning(f"Non-critical: Transmission seeding failed: {str(e)}")
            
            # Get the filename of the torrent
            torrent_filename = os.path.basename(torrent_path)
            
            # Generate the download URL
            torrent_url = f"{BASE_URL}/{quote(torrent_filename)}"
            
            # Mark as complete
            update_progress(job_id, {
                'status': 'complete',
                'percent': 100,
                'message': 'Complete!',
                'torrent_url': torrent_url,
                'video_title': video_info["title"],
                'seeding': transmission_success
            })
            
            logger.info(f"Successfully processed video: {video_info['title']}")
            
        except Exception as e:
            logger.error(f"Unexpected error: {str(e)}", exc_info=True)
            update_progress(job_id, {'status': 'error', 'error': f"Server error: {str(e)}"})
    
    # Start background thread
    thread = threading.Thread(target=process_video)
    thread.daemon = True
    thread.start()
    
    # Return job ID immediately for progress tracking
    return jsonify({
        "success": True,
        "job_id": job_id,
        "message": "Processing started. Use /api/progress/{job_id} to track progress."
    })


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


@app.route("/api/upload-cookies", methods=["POST"])
def upload_cookies():
    """Upload YouTube cookies for authentication"""
    if not authenticate():
        logger.warning("Unauthorized cookie upload attempt")
        return jsonify({"error": "Unauthorized"}), 401
    
    data = request.get_json()
    
    if not data or "cookies" not in data:
        return jsonify({"error": "Cookies data is required"}), 400
    
    try:
        cookies_file = os.path.join(os.path.dirname(__file__), "..", "youtube_cookies.txt")
        
        # Save cookies to file
        with open(cookies_file, "w") as f:
            f.write(data["cookies"])
        
        logger.info("YouTube cookies updated successfully")
        
        return jsonify({
            "success": True,
            "message": "Cookies uploaded successfully",
            "cookie_count": len(data["cookies"].split('\n'))
        })
        
    except Exception as e:
        logger.error(f"Cookie upload failed: {str(e)}")
        return jsonify({"error": f"Failed to upload cookies: {str(e)}"}), 500


@app.route("/", methods=["GET"])
def index():
    """Root endpoint with basic info"""
    cookies_file = os.path.join(os.path.dirname(__file__), "..", "youtube_cookies.txt")
    cookies_exist = os.path.exists(cookies_file)
    
    return jsonify({
        "name": "YouTube Torrent API",
        "description": "An API for downloading YouTube videos as torrents",
        "version": "1.0.0",
        "cookies_configured": cookies_exist,
        "endpoints": {
            "/api/add": "POST - Add a YouTube video",
            "/api/health": "GET - Health check",
            "/api/upload-cookies": "POST - Upload YouTube cookies",
            "/torrents/{filename}": "GET - Download a torrent file"
        }
    })


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)
