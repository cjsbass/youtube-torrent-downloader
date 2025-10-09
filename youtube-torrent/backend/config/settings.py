import os
from pathlib import Path
from dotenv import load_dotenv

# Load environment variables from .env file if it exists
env_path = Path(__file__).parent / '.env'
if env_path.exists():
    load_dotenv(env_path)

# Configuration
API_KEY = os.environ.get("API_KEY", "your-secret-api-key")  # Change this in production
MEDIA_DIR = os.environ.get("MEDIA_DIR", "/srv/media")
TORRENTS_DIR = os.environ.get("TORRENTS_DIR", "/srv/torrents")
BASE_URL = os.environ.get("BASE_URL", "https://example.com/torrents")
TRACKER = os.environ.get("TRACKER", "udp://tracker.opentrackr.org:1337/announce")
