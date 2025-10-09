#!/bin/bash

# This script generates simple icon files for the Chrome extension
# It requires ImageMagick to be installed

# Generate a 128x128 icon (red background with white torrent symbol)
convert -size 128x128 xc:red \
  -fill white -draw "rectangle 54,26 74,64" \
  -fill white -draw "polygon 38,48 90,48 64,64" \
  -fill white -draw "rectangle 26,77 102,109" \
  -fill red -draw "circle 38,93 38,87" \
  -fill red -draw "circle 64,93 64,87" \
  icon128.png

# Scale down for other sizes
convert icon128.png -resize 48x48 icon48.png
convert icon128.png -resize 16x16 icon16.png

echo "Icons generated: icon16.png, icon48.png, icon128.png"
