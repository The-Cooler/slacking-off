import { loadSettings, saveSettings, originPattern } from '../shared/settings.js';

const targetSelect = document.getElementById('default-target');
const customList = document.getElementById('custom-list');
const targetStatus = document.getElementById('target-status');
const status = document.getElementById('status');
const addForm = document.getElementById('add-target');
const newName = document.getElementById('new-name');
const newUrl = document.getElementById('new-url');
const muteCheckbox = document.getElementById('mute-on-first-idle');
const restoreCheckbox = document.getElementById('restore-last-video');
const pauseModeSelect = document.getElementById('pause-mode');

let { settings, targets } = await loadSettings();
let targetStatusTimer;

renderTargets();
muteCheckbox.checked = settings.muteOnFirstIdle;
restoreCheckbox.checked = settings.restoreLastVideo;
pauseModeSelect.value = settings.pauseMode;

function renderTargets() {
  targetSelect.replaceChildren();

  for (const target of targets) {
    const option = document.createElement('option');
    option.value = target.id;
    option.textContent = `${target.name} — ${target.url}`;
    option.selected = target.id === settings.defaultTargetId;
    targetSelect.append(option);
  }

  renderCustomTargets();
}

function renderCustomTargets() {
  customList.replaceChildren();

  for (const target of targets.filter((entry) => entry.platform === 'custom')) {
    const item = document.createElement('li');

    const text = document.createElement('div');
    text.className = 'custom-text';
    const name = document.createElement('div');
    name.className = 'custom-name';
    name.textContent = target.name;
    const url = document.createElement('div');
    url.className = 'custom-url';
    url.textContent = target.url;
    text.append(name, url);

    const removeButton = document.createElement('button');
    removeButton.type = 'button';
    removeButton.className = 'remove-target';
    removeButton.textContent = '删除';
    removeButton.addEventListener('click', async () => {
      targets = targets.filter((entry) => entry.id !== target.id);
      if (settings.defaultTargetId === target.id) {
        settings.defaultTargetId = targets[0]?.id ?? '';
      }
      await saveSettings(settings, targets);
      renderTargets();
      await chrome.runtime.sendMessage({ type: 'sync-content-scripts' });
      showTargetStatus('已删除。');
    });

    item.append(text, removeButton);
    customList.append(item);
  }
}

targetSelect.addEventListener('change', async () => {
  settings.defaultTargetId = targetSelect.value;
  await saveSettings(settings, targets);
  showStatus('已保存。');
});

addForm.addEventListener('submit', async (event) => {
  event.preventDefault();

  const name = newName.value.trim();
  const url = newUrl.value.trim();
  const origin = originPattern(url);

  if (!origin) {
    showTargetStatus('请填写完整网址，例如 https://example.com。', true);
    return;
  }

  const granted = await chrome.permissions.request({ origins: [origin] });
  if (!granted) {
    showTargetStatus('未授予该网站的访问权限，无法添加。', true);
    return;
  }

  targets.push({ id: `custom-${Date.now()}`, name, url, platform: 'custom' });
  if (!settings.defaultTargetId) {
    settings.defaultTargetId = targets.at(-1).id;
  }

  await saveSettings(settings, targets);
  await chrome.runtime.sendMessage({ type: 'sync-content-scripts' });

  addForm.reset();
  renderTargets();
  showTargetStatus('已添加。');
});

muteCheckbox.addEventListener('change', async () => {
  settings.muteOnFirstIdle = muteCheckbox.checked;
  await saveSettings(settings, targets);
  showStatus('已保存。');
});

restoreCheckbox.addEventListener('change', async () => {
  settings.restoreLastVideo = restoreCheckbox.checked;
  await saveSettings(settings, targets);
  showStatus('已保存。');
});

pauseModeSelect.addEventListener('change', async () => {
  settings.pauseMode = pauseModeSelect.value;
  await saveSettings(settings, targets);
  await chrome.runtime.sendMessage({ type: 'sync-content-scripts' });
  showStatus('已保存。');
});

function showStatus(message, isError = false) {
  status.textContent = message;
  status.classList.toggle('error', isError);
}

function showTargetStatus(message, isError = false) {
  targetStatus.textContent = message;
  targetStatus.classList.toggle('error', isError);
  clearTimeout(targetStatusTimer);
  targetStatusTimer = setTimeout(() => {
    targetStatus.textContent = '';
    targetStatus.classList.remove('error');
  }, 4000);
}
