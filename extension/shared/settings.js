export const DEFAULT_TARGETS = [
  { id: 'bilibili', name: '哔哩哔哩', url: 'https://www.bilibili.com/', platform: 'bilibili' }
];

export const DEFAULT_SETTINGS = {
  defaultTargetId: 'bilibili',
  muteOnFirstIdle: false,
  pauseMode: 'tab-hidden',
  restoreLastVideo: true
};

export async function loadSettings() {
  const { settings, targets } = await chrome.storage.local.get(['settings', 'targets']);
  return {
    settings: { ...DEFAULT_SETTINGS, ...settings },
    targets: targets ?? DEFAULT_TARGETS
  };
}

export async function saveSettings(settings, targets) {
  await chrome.storage.local.set({ settings, targets });
}

export function originPattern(url) {
  try {
    return `${new URL(url).origin}/*`;
  } catch {
    return null;
  }
}
