// Clicking the toolbar button asks every frame of the tab to toggle picture in picture. The
// frame with the right video (see content.js) does it.
chrome.action.onClicked.addListener((tab) => {
  if (tab.id === undefined) return;
  chrome.tabs.sendMessage(tab.id, { type: "pip:toggle" }).catch(() => {});
});
