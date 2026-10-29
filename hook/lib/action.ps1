# 动作编排：把「判断」与「窗口操作」分开。
# 本文件只做流程控制，具体窗口调用来自 platform-*。

function Read-AgentMapping {
  param([string]$Path)

  $mapping = @{}

  if (-not (Test-Path $Path)) {
    return $mapping
  }

  try {
    $data = Get-Content -Raw -Encoding UTF8 $Path | ConvertFrom-Json
    foreach ($property in $data.PSObject.Properties) {
      $mapping[$property.Name] = [string]$property.Value
    }
  } catch {
  }

  return $mapping
}

# Agent 正在执行、用户空闲：打开或聚焦视频浏览器。
function Invoke-RunningAction {
  param($Config, $State, [string]$StatePath)

  if ($State.mode -eq 'watching' -and (Test-WindowAlive $State.browserHwnd)) {
    return
  }

  $foreground = Get-ForegroundWindowHandle
  if ((Get-ProcessNameForWindow $foreground) -ne 'chrome') {
    $State.terminalHwnd = $foreground
  }

  $browserHwnd = Start-VideoBrowser -ChromePath $Config.chromePath -Url (Get-VideoCommandUrl $Config)
  if ($browserHwnd -ne 0) {
    $State.browserHwnd = $browserHwnd
  }

  $State.mode = 'watching'
  Write-State -Path $StatePath -State $State
}

# 需要用户确认/输入，或任务结束：最小化浏览器，回到终端。
function Invoke-AttentionAction {
  param($Config, $State, [string]$StatePath)

  if ($State.mode -eq 'attention') {
    return
  }

  Show-WindowMinimized $State.browserHwnd
  Show-WindowRestoredAndFocused $State.terminalHwnd

  $State.mode = 'attention'
  Write-State -Path $StatePath -State $State
}

function Invoke-HookAction {
  param(
    [string]$Action,
    $Config,
    [string]$StatePath
  )

  if (-not $Config.enabled) {
    return
  }

  $state = Read-State -Path $StatePath
  if (Test-Paused $state) {
    return
  }

  if ($Action -eq 'running') {
    Invoke-RunningAction -Config $Config -State $state -StatePath $StatePath
  } elseif ($Action -eq 'attention') {
    Invoke-AttentionAction -Config $Config -State $state -StatePath $StatePath
  }
}
