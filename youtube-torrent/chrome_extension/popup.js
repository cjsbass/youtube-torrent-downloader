// Get DOM elements
const apiUrlInput = document.getElementById('api-url');
const apiKeyInput = document.getElementById('api-key');
const saveButton = document.getElementById('save-settings');
const cookiesInput = document.getElementById('cookies');
const uploadCookiesButton = document.getElementById('upload-cookies');
const statusDiv = document.getElementById('status');

// Default configuration
const DEFAULT_API_URL = 'https://barcelona-cancellation-palace-relatives.trycloudflare.com';
const DEFAULT_API_KEY = 'a22a0390f46cdf18754c9c6d172a2432e1a9f39cc1d04266813ea94dfab2b56b';

// Load saved settings when popup opens
document.addEventListener('DOMContentLoaded', () => {
  chrome.storage.sync.get(['apiUrl', 'apiKey'], (result) => {
    // Use stored values or defaults
    apiUrlInput.value = result.apiUrl || DEFAULT_API_URL;
    apiKeyInput.value = result.apiKey || DEFAULT_API_KEY;
    
    // Also make sure the default values are saved if none exist
    if (!result.apiUrl || !result.apiKey) {
      chrome.storage.sync.set({
        apiUrl: DEFAULT_API_URL,
        apiKey: DEFAULT_API_KEY
      });
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

// Upload cookies when button is clicked
uploadCookiesButton.addEventListener('click', async () => {
  const apiUrl = apiUrlInput.value.trim();
  const apiKey = apiKeyInput.value.trim();
  const cookies = cookiesInput.value.trim();
  
  if (!apiUrl || !apiKey) {
    showStatus('Please save API settings first', false);
    return;
  }
  
  if (!cookies) {
    showStatus('Please paste cookies first', false);
    return;
  }
  
  try {
    const response = await fetch(`${apiUrl.replace(/\/$/, '')}/api/upload-cookies`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': apiKey
      },
      body: JSON.stringify({ cookies })
    });
    
    const data = await response.json();
    
    if (data.success) {
      showStatus('Cookies uploaded successfully!', true);
      cookiesInput.value = '';  // Clear the textarea
    } else {
      showStatus(data.error || 'Upload failed', false);
    }
  } catch (error) {
    showStatus('Failed to upload cookies: ' + error.message, false);
  }
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
