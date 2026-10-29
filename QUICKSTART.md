# QUICKSTART

给智能体看的安装指南：让本项目在用户机器上跑起来。

安装分三步：**算出扩展 ID → 指导用户加载扩展 → 写入 Hook 配置**。ID 依赖扩展目录的绝对路径，必须先算，不能猜。

用户自己动手的部分（加载扩展、点刷新）你无法代劳，只能给出步骤并等待确认。

## 1. 算出扩展 ID

未在 `manifest.json` 声明 `key` 时，Chrome 用扩展目录的**绝对路径**推导 ID：

```
扩展ID = SHA-256( UTF-16LE(路径) )[前 16 字节]
        每个十六进制位 0-f 映射为 a-p
```

必须用 UTF-16LE。用 UTF-8 算出来不匹配，这是实际验证过的。

在当前项目根目录执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File extension/get-extension-id.ps1
```

输出形如：

```
路径: <扩展目录绝对路径>
ID  : <32 位扩展 ID>
```

脚本会先 `Resolve-Path` 取绝对路径并去掉尾部反斜杠，再按上面的算法计算。不要自己拼路径，直接用脚本输出。

Python 等价写法（用于交叉核对）：

```python
import hashlib
digest = hashlib.sha256(r"<扩展目录绝对路径>".encode("utf-16-le")).hexdigest()[:32]
print("".join(chr(ord("a") + int(c, 16)) for c in digest))
```

自检：路径 `C:\example\extension` 应得到 `khljnbaehneoiakcfkbmegihfaokaboc`。对不上时依次检查：编码是否为 UTF-16LE、路径末尾是否带了反斜杠、是不是取到了父目录。

**算出的 ID 必须和用户在 `chrome://extensions` 看到的完全一致**，不一致就说明路径取错了（例如取到了父目录，或用了正斜杠）。

## 2. 指导用户加载扩展

Chrome 137 起稳定版已禁用 `--load-extension`，只能手动加载。给用户以下步骤，然后等确认：

1. 地址栏打开 `chrome://extensions`
2. 打开右上角「开发者模式」
3. 点「加载已解压的扩展程序」→ 选择本仓库的 `extension/` 目录
4. 记下卡片上显示的 **ID**，与第 1 步算出的结果核对

用户回复后，确认 ID 与计算结果一致。不一致时不要继续，先查原因。

## 3. 写 Hook 配置

编辑 `hook/config.json`，填入第 1 步的结果。字段只有三个，不要增删：

```json
{
  "enabled": true,
  "chromePath": "<Chrome 可执行文件路径>",
  "extensionId": "<扩展 ID>"
}
```

仓库里的 `chromePath` 是 Windows 默认安装位置，`extensionId` 为空。`chromePath` 要与用户机器一致，不确定就问用户。`extensionId` 留空时命令页地址会指向不存在的扩展，浏览器不会有任何反应。

## 4. 接入 Claude Code

项目根目录需要有 `.claude/settings.json`，内容从 `hook/agents/claude-code.settings.example.json` 复制。若该文件已存在，把 `hooks` 字段合并进去，不要覆盖其他配置。

还需要 `.claude/commands/slacking.md`，用于对话内开关：

```markdown
---
description: 查看或切换自动跳转（status / pause [分钟] / resume / on / off）
argument-hint: status | pause [分钟] | resume | on | off
disable-model-invocation: true
allowed-tools: Bash(powershell *)
---

!`powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PROJECT_DIR}/hook/cli.ps1" $ARGUMENTS`
```

配置在**会话启动时**加载。刚写完不会对当前会话生效，需要用户新开一个会话。

## 5. 验证

先关闭总开关，避免验证过程中反复跳窗口：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File hook/cli.ps1 off
```

手动触发一次，确认真能打开目标页面。`<chromePath>` 取 `hook/config.json` 里刚填的值，`<ID>` 取第 1 步的结果：

```powershell
& "<chromePath>" "chrome-extension://<ID>/command/command.html?cmd=idle"
```

预期：打开用户设置的视频页，命令页自己关闭。确认后再开启：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File hook/cli.ps1 on
```

最后让用户新开会话实际体验一次。

## 排错

| 现象 | 原因 |
| --- | --- |
| 命令页打开后提示「未知命令」 | URL 里的 `cmd` 参数不是 `idle` |
| 命令页报错「设置里没有可打开的页面」 | 设置页还没选默认页面 |
| 浏览器没被打开 | `extensionId` 与用户实际扩展 ID 不符 |
| 窗口不跳转 | 总开关关闭，或处于 `/slacking pause` 暂停期 |

## 后续

- 改扩展代码：`extension/QUICKSTART.md`
- 接入其他 Agent：`hook/QUICKSTART.md`
- 项目功能与技术说明：`README.md`
