// This file contains base64-encoded SVG icons
// Since we can't directly create PNG files, we'll use SVG data URLs in the manifest

// Read the SVG content
const fs = require('fs');
const path = require('path');
const svgPath = path.join(__dirname, 'icon.svg');

try {
  const svgContent = fs.readFileSync(svgPath, 'utf8');
  const base64Svg = Buffer.from(svgContent).toString('base64');
  const dataUrl = `data:image/svg+xml;base64,${base64Svg}`;
  
  // Create a JSON file with the icon data URLs
  const icons = {
    "16": dataUrl,
    "48": dataUrl,
    "128": dataUrl
  };
  
  fs.writeFileSync(
    path.join(__dirname, 'icons.json'),
    JSON.stringify(icons, null, 2)
  );
  
  console.log('Icons data URLs saved to icons.json');
} catch (error) {
  console.error('Error generating icons:', error);
}
