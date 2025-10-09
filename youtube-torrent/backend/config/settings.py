import os
from pathlib import Path
from dotenv import load_dotenv

# Load environment variables from .env file if it exists
env_path = Path(__file__).parent.parent / '.env'
if env_path.exists():
    load_dotenv(env_path)
else:
    # Try one level up (project root)
    env_path = Path(__file__).parent.parent.parent / '.env'
    if env_path.exists():
        load_dotenv(env_path)

# Configuration
API_KEY = os.environ.get("API_KEY", "your-secret-api-key")  # Change this in production
MEDIA_DIR = os.environ.get("MEDIA_DIR", "/srv/media")
TORRENTS_DIR = os.environ.get("TORRENTS_DIR", "/srv/torrents")
BASE_URL = os.environ.get("BASE_URL", "https://example.com/torrents")

# Primary tracker and fallbacks
DEFAULT_TRACKERS = [
    "udp://tracker.opentrackr.org:1337/announce",
    "udp://open.tracker.cl:1337/announce",
    "udp://tracker.openbittorrent.com:6969/announce",
    "udp://exodus.desync.com:6969/announce",
    "udp://open.demonii.com:1337/announce"
]

# Get trackers from environment or use defaults
tracker_string = os.environ.get("TRACKER", ",".join(DEFAULT_TRACKERS[:2]))
TRACKERS = tracker_string.split(",") if "," in tracker_string else [tracker_string]

# For backward compatibility
TRACKER = TRACKERS[0]

# If no valid trackers found, use defaults
if not any(TRACKERS):
    TRACKERS = DEFAULT_TRACKERS[:2]

# Maximum storage limits
MAX_STORAGE_GB = float(os.environ.get("MAX_STORAGE_GB", "50"))  # Default 50GB max storage
CLEANUP_THRESHOLD_GB = float(os.environ.get("CLEANUP_THRESHOLD_GB", "45"))  # Start cleanup at 45GB
