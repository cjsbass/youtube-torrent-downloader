#!/bin/bash
# Script to test if the Railway API is working

# API URL and key
if [ -z "$1" ]; then
  echo "Usage: $0 <railway-url> [api-key]"
  echo "Example: $0 https://youtube-torrent-api.up.railway.app a22a0390f46cdf18754c9c6d172a2432e1a9f39cc1d04266813ea94dfab2b56b"
  exit 1
fi

API_URL="$1"
API_KEY="${2:-a22a0390f46cdf18754c9c6d172a2432e1a9f39cc1d04266813ea94dfab2b56b}"

echo "Testing API connection to $API_URL..."

# Test the health endpoint
echo "Checking API health..."
health_response=$(curl -s "$API_URL/api/health")
if [ $? -ne 0 ]; then
  echo "❌ Failed to connect to API. Please check the URL."
  exit 1
fi

echo "✅ Connected to API successfully!"
echo "Health check response:"
echo "$health_response" | python -m json.tool 2>/dev/null || echo "$health_response"

# Test the root endpoint
echo -e "\nChecking API info..."
info_response=$(curl -s "$API_URL/")
echo "API info:"
echo "$info_response" | python -m json.tool 2>/dev/null || echo "$info_response"

echo -e "\n✅ API test complete!"
echo "To use this API in your Chrome extension:"
echo "API URL: $API_URL"
echo "API Key: $API_KEY"

