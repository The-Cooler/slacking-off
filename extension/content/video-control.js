// 按暂停策略监听页面可见性与窗口焦点，只恢复由本扩展暂停的视频。
let pausedByExtension = false;

function findVideo() {
  return document.querySelector('video');
}

function pauseVideo() {
  const video = findVideo();
  if (!video || video.paused) {
    return;
  }
  video.pause();
  pausedByExtension = true;
}

function resumeVideo() {
  const video = findVideo();
  if (!video || !pausedByExtension) {
    return;
  }
  pausedByExtension = false;
  // 自动播放可能被浏览器拦截，此时保持暂停并等待用户操作。
  video.play().catch(() => {});
}

chrome.storage.local.get('settings').then(({ settings }) => {
  const pauseMode = settings?.pauseMode ?? 'tab-hidden';

  if (pauseMode === 'never') {
    return;
  }

  if (pauseMode === 'tab-hidden') {
    document.addEventListener('visibilitychange', () => {
      if (document.hidden) {
        pauseVideo();
      } else {
        resumeVideo();
      }
    });
    return;
  }

  window.addEventListener('blur', pauseVideo);
  window.addEventListener('focus', resumeVideo);
});
