// Simple script to create icon files using the Canvas API
const fs = require('fs');
const { createCanvas } = require('canvas');

// Function to draw the icon at a specific size
function createIcon(size) {
  const canvas = createCanvas(size, size);
  const ctx = canvas.getContext('2d');
  
  // Red background (YouTube red)
  ctx.fillStyle = '#FF0000';
  ctx.fillRect(0, 0, size, size);
  
  // White down arrow and rectangle (torrent symbol)
  ctx.fillStyle = 'white';
  
  // Arrow stem
  const stemWidth = Math.max(2, Math.round(size * 0.1));
  const stemHeight = Math.round(size * 0.3);
  ctx.fillRect(size/2 - stemWidth/2, size * 0.2, stemWidth, stemHeight);
  
  // Arrow head
  const arrowWidth = Math.round(size * 0.4);
  ctx.beginPath();
  ctx.moveTo(size/2 - arrowWidth/2, size * 0.4);
  ctx.lineTo(size/2 + arrowWidth/2, size * 0.4);
  ctx.lineTo(size/2, size * 0.5);
  ctx.closePath();
  ctx.fill();
  
  // Rectangle at bottom
  ctx.fillRect(size * 0.2, size * 0.6, size * 0.6, size * 0.25);
  
  // Dots in rectangle (red)
  const dotSize = Math.max(1, Math.round(size * 0.06));
  const dotY = size * 0.6 + size * 0.25 / 2;
  
  ctx.fillStyle = '#FF0000';
  ctx.beginPath();
  ctx.arc(size * 0.3, dotY, dotSize, 0, Math.PI * 2);
  ctx.fill();
  
  ctx.beginPath();
  ctx.arc(size * 0.5, dotY, dotSize, 0, Math.PI * 2);
  ctx.fill();
  
  // Save to PNG file
  const buffer = canvas.toBuffer('image/png');
  fs.writeFileSync(`icon${size}.png`, buffer);
  console.log(`Created icon${size}.png`);
}

// Create icons in different sizes
createIcon(16);
createIcon(48);
createIcon(128);
