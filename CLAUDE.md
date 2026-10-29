# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目

浏览器扩展 + Hook：Agent 工作时自动打开视频页，需要用户介入时切回终端。可行性分析见 `references/项目可行性分析.md`（该目录被 gitignore）。

## 架构约束（不是建议，是用户反复确认过的决定）

**只有两层，不得引入中间层。**

- **Hook 层**（`hook/`）：监听 Agent 事件、判断状态、执行动作（打开浏览器、切窗口）。状态判断必须写在这里。
- **插件层**（`extension/`）：只执行浏览器内操作。

曾有一个独立的「本地状态协调器」进程设计，已被用户否决。不要把状态机、事件优先级之类的逻辑重新塞回插件或新建守护进程。

层间通道只有一条：终端用命令行打开 `chrome-extension://<ID>/command/command.html?cmd=idle`。`externally_connectable`、本地 HTTP/WS、Native Messaging 三个方案都已评估并否决，不要重新提出。

## 关键约束与陷阱

- **扩展 ID 由扩展目录的绝对路径推导**（UTF-16LE → SHA-256 → 前 16 字节 → 十六进制位映射到 a–p），不是固定值。`hook/config.json` 的 `extensionId` 写的是某个特定机器的值，换目录或换机器必须重新计算并同步，否则命令页地址指向不存在的扩展。算法与验证过程见 `extension/QUICKSTART.md`。
- **Hook 会对每个工具调用触发**。接入后 `.claude/settings.json` 的 `PreToolUse` 挂了「打开浏览器」，意味着任何经 Claude 的操作都可能先跳转——这本身是设计意图，不是 bug。需要临时关闭时用 `/slacking pause <分钟>`，不要靠让 Claude 执行命令来规避。注入方式见 `hook/QUICKSTART.md`，注册配置模板见 `hook/agents/claude-code.settings.example.json`。
- **本机 PowerShell 是 5.1（.NET Framework）**。不要用 `[datetime]::UnixEpoch`（.NET 5+）、`ConvertFrom-Json -AsHashtable`（PS 6+）、`??`、`?:`。时间戳一律用 Unix 毫秒整数存，不要存 ISO 字符串——PS 7 的 `ConvertFrom-Json` 会把它自动转成 `DateTime`，5.1 不会。
- **Hook 只能静默失败**：`hook.ps1` 全部包在 try/catch 里并 `exit 0`，Hook 报错绝不能阻塞 Agent。新增逻辑时保持这一点。
- 临时脚本放 `tmp/`，用完删除；不要用内联解释器命令改文件（会被 hook 拦截）。

## 常用命令

```bash
# 查看/切换自动跳转状态
powershell -NoProfile -ExecutionPolicy Bypass -File hook/cli.ps1 status
powershell -NoProfile -ExecutionPolicy Bypass -File hook/cli.ps1 pause 30

# 手动触发一次「打开视频页」（把 <ID> 换成 hook/config.json 里的 extensionId）
"C:\Program Files\Google\Chrome\Application\chrome.exe" "chrome-extension://<ID>/command/command.html?cmd=idle"
```

没有 build、lint、测试步骤。扩展需手动在 `chrome://extensions` 加载（Chrome 137+ 已禁用 `--load-extension`），改动后点刷新。PowerShell 语法校验用 `[System.Management.Automation.Language.Parser]::ParseFile`。

## 代码结构要点

- **Hook 分成三层**：`agents/<agent>.json`（事件名 → 动作，换 Agent 只改这里）→ `lib/action.ps1`（动作编排）→ `lib/platform-windows.ps1`（唯一依赖 Win32 的文件，换平台只替换它）。`hook.ps1` 查表后调用动作，所以新增事件不需要改 `.claude/settings.json`。
- `extension/background.js` 的 `handleIdle()` 是插件侧唯一入口：复用已打开标签页 → 否则按 `restoreLastVideo` 决定 URL → 打开 → 首次触发时按设置静音。`lastVideoUrl` 是**单个全局值**，不是按域名记录（用户明确拒绝过分平台记录）。
- content script 不是写在 manifest 里，而是 `syncContentScripts()` 按用户已授权的域名动态注册；增删自定义 URL 后需重新注册。
- 设置分为 `chrome.storage.local`（持久：`settings` / `targets` / `lastVideoUrl`）和 `chrome.storage.session`（本会话：`firstIdleHandled` / `videoTabId`）。

## 文档

`docs/架构设计.md` 是架构的权威来源，含已否决方案、未验证项和待办清单。改动架构或发现新的未验证项时同步更新。
