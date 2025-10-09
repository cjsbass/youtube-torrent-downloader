// Function to add the "Download as Torrent" button to YouTube
function addTorrentButton() {
  // Check if we're on a YouTube watch page
  if (!window.location.href.includes('youtube.com/watch')) {
    return;
  }

  // Check if the button already exists
  if (document.getElementById('download-as-torrent-btn')) {
    return;
  }

  // Find the YouTube share buttons container
  const shareButtons = document.querySelector('ytd-button-renderer#share-button');
  if (!shareButtons) {
    // If we can't find the share button, retry after a short delay
    setTimeout(addTorrentButton, 1000);
    return;
  }

  // Create the "Download as Torrent" button
  const torrentButton = document.createElement('button');
  torrentButton.id = 'download-as-torrent-btn';
  torrentButton.className = 'torrent-download-btn';
  torrentButton.innerHTML = `
    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <path d="M12 2v8"></path>
      <path d="m16 6-4 4-4-4"></path>
      <rect width="20" height="8" x="2" y="14" rx="2"></rect>
      <path d="M6 18h.01"></path>
      <path d="M10 18h.01"></path>
    </svg>
    Download as Torrent
  `;

  // Add click event listener
  torrentButton.addEventListener('click', handleTorrentDownload);

  // Insert the button after the share button
  const parentElement = shareButtons.parentElement;
  parentElement.insertBefore(torrentButton, shareButtons.nextSibling);
}

// Function to handle the torrent download
async function handleTorrentDownload() {
  try {
    // Get the current video URL
    const videoUrl = window.location.href;
    
    // Show loading state
    const button = document.getElementById('download-as-torrent-btn');
    const originalContent = button.innerHTML;
    button.innerHTML = 'Processing...';
    button.disabled = true;
    
    // Get API settings from Chrome storage
    const settings = await new Promise((resolve) => {
      chrome.storage.sync.get(['apiUrl', 'apiKey'], resolve);
    });
    
    if (!settings.apiUrl || !settings.apiKey) {
      throw new Error('Please configure the API URL and API Key in the extension settings');
    }
    
    // Send request to the backend API
    const apiEndpoint = `${settings.apiUrl.replace(/\/$/, '')}/api/add`;
    let response;
    try {
      response = await Promise.race([
        fetch(apiEndpoint, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-API-Key': settings.apiKey
          },
          body: JSON.stringify({ url: videoUrl })
        }),
        new Promise((_, reject) => 
          setTimeout(() => reject(new Error('Request timeout: The server is not responding')), 30000)
        )
      ]);
    } catch (fetchError) {
      throw new Error(`Cannot connect to server: ${fetchError.message}. Please check if the API URL is correct and the server is running.`);
    }
    
    if (!response.ok) {
      if (response.status === 401) {
        throw new Error('Authentication failed: Invalid API Key');
      } else if (response.status === 404) {
        throw new Error('API endpoint not found. Please check the API URL configuration');
      } else if (response.status >= 500) {
        throw new Error('Server error: The API server encountered an error');
      } else {
        throw new Error(`Request failed with status: ${response.status}`);
      }
    }
    
    const data = await response.json();
    
    if (!data.success) {
      throw new Error(data.error || 'Unknown error');
    }
    
    // Download the torrent file
    chrome.runtime.sendMessage({
      action: 'download',
      url: data.torrent_url,
      filename: `${data.video_title}.torrent`
    });
    
    // Reset button state with success message
    button.innerHTML = 'Torrent Ready!';
    setTimeout(() => {
      button.innerHTML = originalContent;
      button.disabled = false;
    }, 3000);
    
  } catch (error) {
    console.error('Error downloading torrent:', error);
    
    // Show detailed error state
    const button = document.getElementById('download-as-torrent-btn');
    button.innerHTML = 'Error!';
    button.classList.add('error');
    button.title = error.message || 'Unknown error occurred';
    
    // Show error message in a tooltip or alert
    if (error.message) {
      // Option 1: Show as tooltip (already set above)
      // Option 2: Show as alert (uncomment if preferred)
      // alert(`YouTube Torrent Error: ${error.message}`);
      
      // Option 3: Show a custom error popup
      const errorPopup = document.createElement('div');
      errorPopup.id = 'yt-torrent-error';
      errorPopup.innerHTML = `
        <div class="error-popup">
          <h3>Download Error</h3>
          <p>${error.message}</p>
          <button id="error-dismiss">OK</button>
        </div>
      `;
      document.body.appendChild(errorPopup);
      
      document.getElementById('error-dismiss').addEventListener('click', () => {
        document.getElementById('yt-torrent-error').remove();
      });
      
      // Auto-dismiss after 8 seconds
      setTimeout(() => {
        const popup = document.getElementById('yt-torrent-error');
        if (popup) popup.remove();
      }, 8000);
    }
    
    // Reset after a delay
    setTimeout(() => {
      button.innerHTML = 'Download as Torrent';
      button.classList.remove('error');
      button.disabled = false;
    }, 5000);
  }
}

// Run when the page loads
window.addEventListener('load', addTorrentButton);

// Also run when navigation occurs (for YouTube's SPA behavior)
let lastUrl = location.href;
new MutationObserver(() => {
  if (location.href !== lastUrl) {
    lastUrl = location.href;
    setTimeout(addTorrentButton, 1000);
  }
}).observe(document, { subtree: true, childList: true });

// Listen for messages from popup
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.action === 'updateSettings') {
    // Settings were updated, no need to do anything here
    // The next download will use the new settings
    sendResponse({ success: true });
  }
  
  return true; // Keep the message channel open for async response
});
