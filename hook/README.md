# Hook 层

监听 Agent 的 Hook 事件，自行判断状态并执行动作，不经过其他进程。

接入新 Agent 的步骤见 [QUICKSTART.md](QUICKSTART.md)，安装与验证见 [../QUICKSTART.md](../QUICKSTART.md)。本文件只说明内部设计与实现细节。

## 结构

```
hook/
├── config.json              # 总开关、Chrome 路径、扩展 ID
├── hook.ps1                 # 入口：读 stdin 事件 → 查映射 → 执行动作
├── cli.ps1                  # /slacking 入口：status / pause / resume / on / off
├── agents/
│   ├── claude-code.json     # 事件名 → 动作 的映射
│   └── claude-code.settings.example.json  # 该 Agent 的注册配置示例
└── lib/
    ├── config.ps1           # 配置读写、命令页 URL 生成
    ├── state.ps1            # 状态读写、暂停判断
    ├── action.ps1           # 动作编排（running / attention）
    └── platform-windows.ps1 # Win32 窗口操作，换平台只替换此文件
```

## 分工

| 文件 | 依赖 | 换 Agent 时 | 换平台时 |
| --- | --- | --- | --- |
| `agents/*.json` | — | 改 | 不变 |
| `lib/action.ps1` | 平台函数 | 不变 | 不变 |
| `lib/config.ps1` | — | 不变 | 不变 |
| `lib/state.ps1` | — | 不变 | 不变 |
| `lib/platform-windows.ps1` | Win32 | 不变 | 替换 |

新增 Agent 只需加一份 `agents/<name>.json`，并在它的 Hook 配置里调用
`hook.ps1 -Agent <name>`，核心代码不动。

## 事件映射（claude-code）

| 事件 | 动作 |
| --- | --- |
| `UserPromptSubmit`、`PreToolUse` | running |
| `PermissionRequest`、`Notification`、`Stop`、`SessionEnd` | attention |

映射在 `hook.ps1` 内部查表完成，因此新增事件不需要改 `.claude/settings.json`。

## 动作

- **running**：若不在看视频，记录前台窗口为终端，用命令行打开
  `chrome-extension://<扩展ID>/command/command.html?cmd=idle`，等待 Chrome 成为前台并记录其窗口句柄。
- **attention**：最小化浏览器窗口，恢复并激活终端窗口。

`hook.ps1` 全部包在 try/catch 中，出错静默 `exit 0`，不影响 Agent。

## 状态

`%LOCALAPPDATA%\slacking-off\state.json`：

```json
{"mode":"idle","terminalHwnd":0,"browserHwnd":0,"pausedUntil":0}
```

`pausedUntil` 用 **Unix 毫秒整数**，不用 ISO 字符串——PowerShell 7 的 `ConvertFrom-Json`
会把 ISO 日期字符串自动转成 `DateTime`，5.1 不会，用整数可避开这个差异。读取时仍兼容旧版
写入的 ISO 字符串。

## 对话内开关

在 Claude Code 里用 `/slacking` 控制，不经过模型：

| 命令 | 作用 |
| --- | --- |
| `/slacking` | 查看状态 |
| `/slacking pause 30` | 暂停 30 分钟，到点自动恢复 |
| `/slacking resume` | 立即恢复 |
| `/slacking on` / `off` | 总开关 |

暂停只停止窗口跳转，不影响插件已有的播放。

## 安装

注册配置模板在 `agents/claude-code.settings.example.json`，接入步骤（含 ID 计算与验证）见 [../QUICKSTART.md](../QUICKSTART.md)。接入其他 Agent 见 [QUICKSTART.md](QUICKSTART.md)。

## 版本兼容

本机是 PowerShell 5.1（.NET Framework）。已避开的高版本专属写法：

- `[datetime]::UnixEpoch`：仅 .NET 5+ 存在，改用 `Get-UnixEpoch` 显式构造。
- `ConvertFrom-Json -AsHashtable`：仅 PS 6+ 存在。
- 三元运算符 `? :`、空合并 `??`：仅 PS 7+。

其余用到的 `Add-Type`、`$PSScriptRoot`、`ConvertTo-Json -Compress`、`[pscustomobject]`
自 PS 3.0 起均可用。

## 未验证

- `permission_mode` 为 `auto` / `bypassPermissions` 时，`PermissionRequest` 是否仍会触发。
- 浏览器窗口句柄依赖"打开命令页后 Chrome 在 5 秒内成为前台窗口"，被其他窗口打断时记不到句柄。
- `SessionEnd` 的 Hook 预算只有 1.5 秒。
- `/slacking` 的 `!` 注入是否仍触发 `UserPromptSubmit`。

## TODO

用 C++ / Rust 编译原生可执行文件替换 PowerShell，彻底消除不同设备 PowerShell 版本差异。
当前未开始。

完整架构见 [../docs/架构设计.md](../docs/架构设计.md)。
