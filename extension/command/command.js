const statusElement = document.getElementById('status');
const command = new URLSearchParams(location.search).get('cmd');

async function run() {
  if (command !== 'idle') {
    showError(`未知命令：${command ?? '（空）'}`);
    return;
  }

  const response = await chrome.runtime.sendMessage({ type: 'idle' });
  if (!response?.ok) {
    showError(response?.message ?? '未能打开页面。');
    return;
  }

  const tab = await chrome.tabs.getCurrent();
  if (tab) {
    await chrome.tabs.remove(tab.id);
  }
}

function showError(message) {
  statusElement.textContent = message;
  statusElement.classList.add('error');
}

run();
