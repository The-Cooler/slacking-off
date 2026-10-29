# QUICKSTART

给智能体看的开发指南：如何修改、扩展本浏览器扩展。

安装（加载扩展、生成 ID、接入 Hook）见根目录 `QUICKSTART.md`。

## 1. 代码结构

| 文件 | 职责 |
| --- | --- |
| `manifest.json` | MV3 声明、权限 |
| `background.js` | service worker：处理命令、打开页面、静音、动态注册 content script |
| `shared/settings.js` | 设置的默认值与读写 |
| `command/` | 终端命令入口页，由 Hook 通过命令行打开 |
| `options/` | 设置页 |
| `content/video-control.js` | 页面内暂停 / 恢复 |
| `platforms/` | 平台专属适配的预留位置，当前为空占位 |
| `get-extension-id.ps1` | 按目录路径计算扩展 ID，供安装时使用 |

改动任何文件后，需在 `chrome://extensions` 点扩展卡片上的刷新按钮才会生效。

## 2. 命令入口

Hook 打开的唯一入口：

```
chrome-extension://<扩展ID>/command/command.html?cmd=idle
```

`command.js` 读 `cmd` 参数 → 发消息给 `background.js` → `handleIdle()` 执行 → 关闭自己这个标签页。

新增命令时：

1. 在 `command.js` 加分支
2. 在 `background.js` 的 `chrome.runtime.onMessage` 加对应处理
3. 同步更新 `hook/lib/config.ps1` 里 `Get-VideoCommandUrl` 的格式说明

## 3. 设置项

| 存储位置 | 键 | 内容 |
| --- | --- | --- |
| `storage.local` | `settings` | `defaultTargetId`、`muteOnFirstIdle`、`pauseMode`、`restoreLastVideo` |
| `storage.local` | `targets` | 可打开的页面列表，内置 B 站 + 用户自定义 |
| `storage.local` | `lastVideoUrl` | 最近一次停留的页面，**单个全局值** |
| `storage.session` | `firstIdleHandled` | 本次浏览器会话是否已处理过首次静音 |
| `storage.session` | `videoTabId` | 当前视频标签页，用于复用 |

默认值定义在 `shared/settings.js`。新增设置项必须同时加默认值，否则老用户读到 `undefined`。

## 4. content script 是动态注册的

不在 manifest 里声明，而是 `syncContentScripts()` 按用户已授权的域名动态注册：

- 用户添加自定义 URL 时申请该域名权限
- 增删页面后调 `sync-content-scripts` 消息重新注册
- 没有授权的域名不会被注入

改注入逻辑时注意：停止注册比注册更容易漏，先 `unregister` 再 `register`。

## 5. 硬规则

- **UI 必须同时适配明暗模式**：所有颜色走 CSS 变量，在 `prefers-color-scheme` 里各定义一套。下拉框和输入框要单独设背景色，避免与文字同色。
- **不要记录多个网站的播放进度**：`lastVideoUrl` 是单个值，用户明确拒绝过按域名分别记录。
- **不要在扩展里做 Agent 状态判断**：窗口跳转和状态判断属于 Hook 层，扩展只执行。
- 权限用 `optional_host_permissions` + 运行时申请，不要在 manifest 里写死 `<all_urls>`。

## 参考

- 完整架构：`../docs/架构设计.md`
- Hook 接入指南：`../hook/QUICKSTART.md`
