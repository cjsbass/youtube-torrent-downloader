FROM python:3.11-slim

# Install system dependencies in one layer
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    mktorrent \
    ffmpeg \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY api ./api
COPY config ./config

# Create necessary directories
RUN mkdir -p /srv/media /srv/torrents && \
    chmod 777 /srv/media /srv/torrents

# Expose port
EXPOSE 5000

# Set environment variables
ENV MEDIA_DIR=/srv/media \
    TORRENTS_DIR=/srv/torrents \
    TRACKER="udp://tracker.opentrackr.org:1337/announce,udp://open.tracker.cl:1337/announce,udp://tracker.openbittorrent.com:6969/announce" \
    MAX_STORAGE_GB=20 \
    CLEANUP_THRESHOLD_GB=15 \
    PORT=5000 \
    PYTHONUNBUFFERED=1

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:5000/api/health || exit 1

# Run gunicorn directly
CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:5000", "api.app:app", "--access-logfile", "-", "--error-logfile", "-"]
