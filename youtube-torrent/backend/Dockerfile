FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    mktorrent \
    ffmpeg \
    nginx \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create necessary directories
RUN mkdir -p /srv/media /srv/torrents && \
    chown -R www-data:www-data /srv/torrents

# Set up Nginx
COPY nginx.conf /etc/nginx/sites-available/default
RUN ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/

# Expose ports
EXPOSE 80

# Create a script to start both services
RUN echo '#!/bin/bash\n\
nginx\n\
gunicorn -w 4 -b 0.0.0.0:5000 api.app:app\n\
' > /app/start.sh && chmod +x /app/start.sh

# Set environment variables
ENV MEDIA_DIR=/srv/media \
    TORRENTS_DIR=/srv/torrents \
    TRACKER="udp://tracker.opentrackr.org:1337/announce,udp://open.tracker.cl:1337/announce,udp://tracker.openbittorrent.com:6969/announce" \
    MAX_STORAGE_GB=20 \
    CLEANUP_THRESHOLD_GB=15

# Start the services
CMD ["/app/start.sh"]
