// Listen for messages from content scripts
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.action === 'download') {
    // Download the torrent file
    chrome.downloads.download({
      url: message.url,
      filename: message.filename,
      saveAs: false // Auto-save to Downloads folder
    });
    
    sendResponse({ success: true });
  }
  
  return true; // Keep the message channel open for async response
});
