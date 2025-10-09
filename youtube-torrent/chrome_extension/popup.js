// Get DOM elements
const apiUrlInput = document.getElementById('api-url');
const apiKeyInput = document.getElementById('api-key');
const saveButton = document.getElementById('save-settings');
const statusDiv = document.getElementById('status');

// Load saved settings when popup opens
document.addEventListener('DOMContentLoaded', () => {
  chrome.storage.sync.get(['apiUrl', 'apiKey'], (result) => {
    if (result.apiUrl) {
      apiUrlInput.value = result.apiUrl;
    }
    
    if (result.apiKey) {
      apiKeyInput.value = result.apiKey;
    }
  });
});

// Save settings when button is clicked
saveButton.addEventListener('click', () => {
  const apiUrl = apiUrlInput.value.trim();
  const apiKey = apiKeyInput.value.trim();
  
  // Basic validation
  if (!apiUrl) {
    showStatus('Please enter the API URL', false);
    return;
  }
  
  if (!apiKey) {
    showStatus('Please enter your API key', false);
    return;
  }
  
  // Save to Chrome storage
  chrome.storage.sync.set({ apiUrl, apiKey }, () => {
    showStatus('Settings saved successfully!', true);
    
    // Update the content script with new settings
    chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
      const currentTab = tabs[0];
      
      if (currentTab && currentTab.url.includes('youtube.com')) {
        chrome.tabs.sendMessage(currentTab.id, { 
          action: 'updateSettings',
          apiUrl,
          apiKey
        });
      }
    });
  });
});

// Helper function to show status messages
function showStatus(message, isSuccess) {
  statusDiv.textContent = message;
  statusDiv.className = `status ${isSuccess ? 'success' : 'error'}`;
  statusDiv.style.display = 'block';
  
  // Hide the message after 3 seconds
  setTimeout(() => {
    statusDiv.style.display = 'none';
  }, 3000);
}
