#!/bin/bash
# Chrome Extension Packaging Script

echo "=== YouTube Torrent Chrome Extension Packager ==="

# Create a zip package for Chrome Web Store or manual installation
echo "Creating ZIP package..."

# Get directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Package name
ZIP_NAME="youtube-torrent-extension.zip"

# Remove old package if exists
if [ -f "$ZIP_NAME" ]; then
    rm "$ZIP_NAME"
    echo "Removed old package."
fi

# Create the ZIP file (excluding unnecessary files)
zip -r "$ZIP_NAME" \
    background.js \
    content.js \
    manifest.json \
    popup.html \
    popup.js \
    styles.css \
    images/icon.svg

echo ""
echo "=== PACKAGING COMPLETE ==="
echo ""
echo "Your extension package is available at:"
echo "$SCRIPT_DIR/$ZIP_NAME"
echo ""
echo "To install manually in Chrome:"
echo "1. Open chrome://extensions/"
echo "2. Enable 'Developer mode'"
echo "3. Drag and drop the ZIP file to the page OR"
echo "   Click 'Load unpacked' and select this directory"
echo ""
