import { loadSettings, originPattern } from './shared/settings.js';

chrome.action.onClicked.addListener(() => {
  chrome.runtime.openOptionsPage();
});

chrome.runtime.onInstalled.addListener(syncContentScripts);
chrome.runtime.onStartup.addListener(syncContentScripts);

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message.type === 'idle') {
    handleIdle().then(sendResponse);
    return true;
  }

  if (message.type === 'sync-content-scripts') {
    syncContentScripts().then(() => sendResponse({ ok: true }));
    return true;
  }
});

// 只记录最近一次停留的页面，供下次启动时恢复。
chrome.tabs.onUpdated.addListener((_tabId, changeInfo, tab) => {
  if (changeInfo.url && tab.url.startsWith('http')) {
    rememberVideoUrl(tab.url);
  }
});

chrome.tabs.onRemoved.addListener(async (tabId) => {
  const { videoTabId } = await chrome.storage.session.get('videoTabId');
  if (tabId === videoTabId) {
    await chrome.storage.session.remove('videoTabId');
  }
});

async function rememberVideoUrl(url) {
  const { lastVideoUrl } = await chrome.storage.local.get('lastVideoUrl');
  if (lastVideoUrl !== url) {
    await chrome.storage.local.set({ lastVideoUrl: url });
  }
}

async function handleIdle() {
  const { settings, targets } = await loadSettings();
  const target = targets.find((item) => item.id === settings.defaultTargetId) ?? targets[0];

  if (!target) {
    return { ok: false, message: '设置里没有可打开的页面。' };
  }

  const { firstIdleHandled, videoTabId } = await chrome.storage.session.get([
    'firstIdleHandled',
    'videoTabId'
  ]);
  const existingTab = videoTabId ? await chrome.tabs.get(videoTabId).catch(() => null) : null;

  if (existingTab) {
    await chrome.tabs.update(existingTab.id, { active: true });
    await chrome.windows.update(existingTab.windowId, { focused: true });
    return { ok: true };
  }

  const url = settings.restoreLastVideo ? await getRestoreUrl(target.url) : target.url;
  const tab = await chrome.tabs.create({ url });
  await chrome.windows.update(tab.windowId, { focused: true });
  await chrome.storage.session.set({ videoTabId: tab.id });

  if (!firstIdleHandled) {
    await chrome.tabs.update(tab.id, { muted: settings.muteOnFirstIdle });
    await chrome.storage.session.set({ firstIdleHandled: true });
  }

  return { ok: true };
}

// 上次停留的页面返回错误状态时，改用默认页面。
async function getRestoreUrl(fallbackUrl) {
  const { lastVideoUrl } = await chrome.storage.local.get('lastVideoUrl');

  if (!lastVideoUrl) {
    return fallbackUrl;
  }

  try {
    const response = await fetch(lastVideoUrl, { method: 'HEAD', redirect: 'follow' });
    return response.ok ? lastVideoUrl : fallbackUrl;
  } catch {
    return fallbackUrl;
  }
}

async function syncContentScripts() {
  const { targets } = await loadSettings();
  const origins = [...new Set(targets.map((target) => originPattern(target.url)).filter(Boolean))];

  const granted = [];
  for (const origin of origins) {
    if (await chrome.permissions.contains({ origins: [origin] })) {
      granted.push(origin);
    }
  }

  const registered = await chrome.scripting.getRegisteredContentScripts({ ids: ['video-control'] });
  if (registered.length > 0) {
    await chrome.scripting.unregisterContentScripts({ ids: ['video-control'] });
  }

  if (granted.length === 0) {
    return;
  }

  await chrome.scripting.registerContentScripts([
    {
      id: 'video-control',
      matches: granted,
      js: ['content/video-control.js'],
      runAt: 'document_idle'
    }
  ]);
}
