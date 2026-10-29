# QUICKSTART

给智能体看的接入指南：如何把本项目的 Hook 接到一个新 Agent 上。

不要跳过「先确认事件名」这一步。Agent 的事件名不能猜，必须查官方文档；文档说不清就实际跑一次确认。

## 1. 先看它有什么事件

查该 Agent 的 Hook / 事件文档，找出三类时机分别对应哪些事件名：

| 需要识别的时机 | 含义 |
| --- | --- |
| Agent 正在执行，用户在等 | 映射为 `running` |
| 需要用户确认或输入 | 映射为 `attention` |
| 任务结束、会话结束 | 映射为 `attention` |

以 Claude Code 为例（已确认）：`UserPromptSubmit`、`PreToolUse` 是 `running`；`PermissionRequest`、`Notification`、`Stop`、`SessionEnd` 是 `attention`。完整示例见 `agents/claude-code.json`。

文档描述不清时，写一个只打印 stdin 的临时脚本注册上去，实际触发一次看输出，不要依据推测填写。

## 2. 写映射文件

新建 `agents/<agent-name>.json`，键是事件名，值只能是 `running` 或 `attention`：

```json
{
  "SessionStart": "running",
  "ToolCallStart": "running",
  "NeedsUserInput": "attention",
  "TaskFinished": "attention"
}
```

`<agent-name>` 必须和注册命令里 `-Agent` 参数一致。文件名不匹配时 `hook.ps1` 找不到映射，会静默退出。

没有列出的表事件会被忽略，这是正常行为，不需要列全。

## 3. 写注册配置

复制 `agents/claude-code.settings.example.json` 为新 Agent 的配置，把里面所有 `-Agent claude-code` 改成 `-Agent <agent-name>`。

每个事件名一条 entry，命令体保持一致。`hook.ps1` 内部查表决定动作，所以所有事件的命令**完全相同**，不要把动作写进命令里。

需要注意的两点：

- **`async: true`**：除会话结束类事件外都应加，避免阻塞 Agent。会话结束类事件在 Claude Code 里预算只有 1.5 秒，加了 async 反而可能来不及执行，所以 Claude Code 的 `SessionEnd` 没有加。
- **项目根目录变量**：示例用的是 Claude Code 的 `${CLAUDE_PROJECT_DIR}`。其他 Agent 没有这个变量时，换成绝对路径或它自己的变量。

## 4. 自测

不要直接接入正式配置。先手动验证四件事：

```powershell
# 语法
powershell -NoProfile -Command "& { $e = $null; [void][System.Management.Automation.Language.Parser]::ParseFile('hook/hook.ps1', [ref]$null, [ref]$e); $e }"

# 未映射事件、未知 Agent、空 stdin 都必须静默 exit 0
'{"hook_event_name":"UnknownEvent"}' | powershell -NoProfile -File hook/hook.ps1 -Agent claude-code

# 暂停期内必须什么都不做
powershell -NoProfile -File hook/cli.ps1 pause 1
'{"hook_event_name":"<running 类事件>"}' | powershell -NoProfile -File hook/hook.ps1 -Agent <agent-name>
powershell -NoProfile -File hook/cli.ps1 resume

# 先关闭总开关再真实触发，确认没有异常输出
powershell -NoProfile -File hook/cli.ps1 off
```

确认无误后再开启：`cli.ps1 on`。

## 5. 允许修改的范围

| 文件 | 新增 Agent 时 |
| --- | --- |
| `agents/<agent>.json` | 新建 |
| `agents/<agent>.settings.example.json` | 新建 |
| 该 Agent 自己的 Hook 注册配置 | 修改 |
| `hook.ps1`、`lib/*.ps1` | **不要改** |

核心代码与 Agent 无关。如果发现必须改 `lib/action.ps1` 才能接入，说明映射粒度不够，先停下来讨论，不要为此在核心代码里加 Agent 分支。

## 6. 改动的硬规则

- `hook.ps1` 出错必须静默 `exit 0`。Hook 报错不能阻塞 Agent。
- 不要用 PowerShell 7 专属写法。目标环境可能是 5.1（.NET Framework），以下都不可用：`[datetime]::UnixEpoch`、`ConvertFrom-Json -AsHashtable`、`??`、`?:`。
- 时间戳用 Unix 毫秒整数，不要存 ISO 字符串。
- 状态文件只有一个：`%LOCALAPPDATA%\slacking-off\state.json`。不要为单个 Agent 新建状态文件。

## 参考

- 动作定义与平台调用：`lib/action.ps1`、`lib/platform-windows.ps1`
- 完整说明：`README.md`
- 架构位置：`../docs/架构设计.md`
