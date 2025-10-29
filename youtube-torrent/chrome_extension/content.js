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

  console.log('YouTube Torrent: Attempting to add button...');

  // Try multiple selectors for the YouTube share button (YouTube's UI changes frequently)
  const selectors = [
    'ytd-button-renderer#share-button',
    'button[aria-label="Share"]',
    '#top-level-buttons-computed ytd-button-renderer:nth-child(3)',
    '.ytd-menu-renderer button[aria-label="Share"]',
    '#actions #button-shape button',
    '#actions-inner button'
  ];

  let shareButtons = null;
  for (const selector of selectors) {
    shareButtons = document.querySelector(selector);
    if (shareButtons) {
      console.log('YouTube Torrent: Found button with selector:', selector);
      break;
    }
  }

  if (!shareButtons) {
    console.log('YouTube Torrent: Share button not found, retrying in 2 seconds...');
    // If we can't find the share button, retry after a short delay
    setTimeout(addTorrentButton, 2000);
    return;
  }

  // Create our button container to match YouTube's style
  const torrentContainer = document.createElement('div');
  torrentContainer.style.display = 'inline-block';
  torrentContainer.style.marginLeft = '8px';

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
  
  // Add the button to our container
  torrentContainer.appendChild(torrentButton);

  // Try different insertion methods
  try {
    // Try method 1: Insert after share button
    const parentElement = shareButtons.parentElement;
    if (parentElement) {
      parentElement.insertBefore(torrentContainer, shareButtons.nextSibling);
      console.log('YouTube Torrent: Button added successfully (method 1)');
      return;
    }
    
    // Try method 2: Insert next to share button
    const grandParent = shareButtons.parentElement?.parentElement;
    if (grandParent) {
      grandParent.appendChild(torrentContainer);
      console.log('YouTube Torrent: Button added successfully (method 2)');
      return;
    }

    // Try method 3: Find the actions container
    const actionsContainer = document.querySelector('#actions') || 
                             document.querySelector('#menu-container') ||
                             document.querySelector('ytd-menu-renderer');
    if (actionsContainer) {
      actionsContainer.appendChild(torrentContainer);
      console.log('YouTube Torrent: Button added successfully (method 3)');
      return;
    }
  } catch (e) {
    console.error('YouTube Torrent: Error adding button:', e);
  }

  console.log('YouTube Torrent: Could not add button, will retry in 3 seconds');
  setTimeout(addTorrentButton, 3000);
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
    
    // Default configuration
    const DEFAULT_API_URL = 'http://66.135.31.40';
    const DEFAULT_API_KEY = 'a22a0390f46cdf18754c9c6d172a2432e1a9f39cc1d04266813ea94dfab2b56b';
    
    // Get API settings from Chrome storage
    const settings = await new Promise((resolve) => {
      chrome.storage.sync.get(['apiUrl', 'apiKey'], resolve);
    });
    
    // Use stored values or defaults
    const apiUrl = settings.apiUrl || DEFAULT_API_URL;
    const apiKey = settings.apiKey || DEFAULT_API_KEY;
    
    // Save defaults if none exist
    if (!settings.apiUrl || !settings.apiKey) {
      chrome.storage.sync.set({
        apiUrl: DEFAULT_API_URL,
        apiKey: DEFAULT_API_KEY
      });
    }
    
    // Send request to the backend API
    const apiEndpoint = `${apiUrl.replace(/\/$/, '')}/api/add`;
    let response;
    try {
      response = await Promise.race([
        fetch(apiEndpoint, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-API-Key': apiKey
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
    
    if (!data.success || !data.job_id) {
      throw new Error(data.error || 'Unknown error');
    }
    
    // Start tracking progress via Server-Sent Events
    const jobId = data.job_id;
    const progressUrl = `${apiUrl.replace(/\/$/, '')}/api/progress/${jobId}`;
    
    const eventSource = new EventSource(progressUrl);
    
    eventSource.onmessage = function(event) {
      const progress = JSON.parse(event.data);
      
      if (progress.status === 'downloading') {
        const percent = progress.percent || 0;
        const speed = progress.speed_mbps || 0;
        const eta = progress.eta_seconds || 0;
        button.innerHTML = `Downloading... ${percent.toFixed(0)}% (${speed.toFixed(1)} MB/s, ETA: ${Math.floor(eta/60)}m ${eta%60}s)`;
      } else if (progress.status === 'creating_torrent') {
        button.innerHTML = 'Creating torrent...';
      } else if (progress.status === 'seeding') {
        button.innerHTML = 'Starting seeding...';
      } else if (progress.status === 'complete') {
        eventSource.close();
        
        // Download the torrent file
        chrome.runtime.sendMessage({
          action: 'download',
          url: progress.torrent_url,
          filename: `${progress.video_title}.torrent`
        });
        
        // Reset button state with success message
        button.innerHTML = 'Torrent Ready!';
        setTimeout(() => {
          button.innerHTML = originalContent;
          button.disabled = false;
        }, 3000);
      } else if (progress.status === 'error') {
        eventSource.close();
        throw new Error(progress.error || 'Processing failed');
      }
    };
    
    eventSource.onerror = function(error) {
      eventSource.close();
      throw new Error('Lost connection to server');
    };
    
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

// Initialize the extension
function initExtension() {
  console.log('YouTube Torrent: Extension initialized');
  
  // Run immediately
  addTorrentButton();
  
  // Run when page is fully loaded
  window.addEventListener('load', addTorrentButton);

  // Also run when navigation occurs (for YouTube's SPA behavior)
  let lastUrl = location.href;
  new MutationObserver(() => {
    if (location.href !== lastUrl) {
      console.log('YouTube Torrent: URL changed from', lastUrl, 'to', location.href);
      lastUrl = location.href;
      // Try multiple times as YouTube loads its UI dynamically
      setTimeout(addTorrentButton, 1000);
      setTimeout(addTorrentButton, 2000);
      setTimeout(addTorrentButton, 4000);
    }
  }).observe(document, { subtree: true, childList: true });
  
  // Run periodically to handle dynamic content loading
  setInterval(addTorrentButton, 5000);
}

// Start the extension
console.log('YouTube Torrent: Content script loaded');
initExtension();

// Listen for messages from popup
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.action === 'updateSettings') {
    // Settings were updated, no need to do anything here
    // The next download will use the new settings
    sendResponse({ success: true });
  }
  
  return true; // Keep the message channel open for async response
});
