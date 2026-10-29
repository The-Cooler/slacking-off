# slacking off

终端里的 AI Agent 干活时，自动打开视频页面；需要你确认或输入时，自动最小化浏览器、切回终端。

> 安装步骤见 [`QUICKSTART.md`](QUICKSTART.md)。

## 组成部分

- **浏览器扩展**（`extension/`）：打开页面、播放控制、设置界面
- **Hook 层**（`hook/`）：监听 Agent 事件，决定何时跳转与召回

## 工作原理

Hook 层不通过常驻进程与浏览器通信，而是直接用命令行打开扩展内的一个页面：

```
chrome.exe "chrome-extension://<扩展ID>/command/command.html?cmd=idle"
```

该页面在扩展上下文中运行，读取设置、打开视频页，然后关闭自己。浏览器已打开时命令落到现有窗口，等于复用同一个浏览器。

这个方案取代了三种被否决的做法：`externally_connectable`（需要网页承载）、本地 HTTP/WebSocket（需要常驻进程）、Native Messaging（需要注册表与宿主程序）。

## 行为

| 时机 | 动作 |
| --- | --- |
| Agent 开始执行 | 打开或聚焦视频浏览器 |
| 需要确认 / 输入 / 本轮结束 | 最小化浏览器，回到终端 |
| 标签页切走或浏览器失焦 | 暂停视频，切回后恢复（可配置为不暂停） |
| 下次启动 | 优先打开上次停留的页面（可关闭） |

## 扩展设置

点扩展图标打开设置页：

- 默认打开页面（下拉选择）
- 首次启动静音
- 回到上次的页面
- 切到后台时是否暂停
- 自定义 URL（任意 http/https 网站）

界面明暗主题跟随系统。

## 控制开关

`/slacking` 不经过模型，执行时不会再触发跳转。

| 命令 | 作用 |
| --- | --- |
| `/slacking` | 查看状态 |
| `/slacking pause 30` | 暂停 30 分钟，到点自动恢复 |
| `/slacking resume` | 立即恢复 |
| `/slacking on` / `off` | 总开关 |

暂停只停止窗口跳转，不影响正在播放的视频。

## 架构

只有两层，没有中间进程。Agent 的事件名差异被隔离在映射文件里，核心动作代码与 Agent 无关。

```
extension/          # 插件层：只执行浏览器内操作
hook/
├── agents/         # 事件名 → 动作（换 Agent 只改这里）
├── lib/action.ps1  # 动作编排
└── lib/platform-windows.ps1  # 唯一依赖 Win32 的文件
```

详见 [`docs/架构设计.md`](docs/架构设计.md)。

## 控制开关实现在哪

`/slacking` 调用 `hook/cli.ps1`，后者读写 `hook/config.json` 的 `enabled` 和 `%LOCALAPPDATA%\slacking-off\state.json` 的 `pausedUntil`。`hook/hook.ps1` 每次触发先检查这两项，命中就直接退出。

## 支持范围

- **系统**：仅 Windows，Hook 层依赖 PowerShell 与 Win32 API
- **浏览器**：Chrome / Edge（Manifest V3），需手动加载
- **Agent**：Claude Code，其他 Agent 可按 `hook/QUICKSTART.md` 接入
- **视频平台**：B 站，另可添加任意自定义网址
- **平台专属适配**：尚无，`extension/platforms/` 为空占位

## 已知限制

- **扩展 ID 绑定路径**：由扩展目录绝对路径推导，移动目录或换机器需重新计算并同步 `hook/config.json`
- **窗口句柄捕获有时序依赖**：打开命令页后若 Chrome 未在 5 秒内成为前台窗口，就记不到句柄，召回时只切终端、不最小化浏览器
- **「回到上次页面」的回退探测不可靠**：用 `fetch` HEAD 判断，视频被删除但返回 200 时识别不出
- **浏览器会拦截有声自动播放**：首次可能需要手动点一下播放
- **PowerShell 版本**：代码按 5.1 编写，避开了 PS 7 专属语法

## 文档

| 文件 | 面向 |
| --- | --- |
| `QUICKSTART.md` | 安装：算 ID、加载扩展、写配置、验证 |
| `extension/QUICKSTART.md` | 开发：改扩展代码 |
| `hook/QUICKSTART.md` | 扩展：接入新 Agent |
| `docs/架构设计.md` | 架构决策与待办 |
| `CLAUDE.md` | Claude Code：项目约定 |

## 许可

[MIT](LICENSE)
