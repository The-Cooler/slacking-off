# Hook 入口。由 Agent 的 Hook 配置调用，从 stdin 读取事件 JSON，
# 按 agents/<agent>.json 判断动作后执行。

param(
  [Parameter(Mandatory = $true)]
  [string]$Agent
)

$ErrorActionPreference = 'Stop'

try {
  . (Join-Path $PSScriptRoot 'lib\config.ps1')
  . (Join-Path $PSScriptRoot 'lib\state.ps1')
  . (Join-Path $PSScriptRoot 'lib\action.ps1')
  . (Join-Path $PSScriptRoot 'lib\platform-windows.ps1')

  $mapping = Read-AgentMapping -Path (Join-Path $PSScriptRoot "agents\$Agent.json")
  if ($mapping.Count -eq 0) {
    exit 0
  }

  $raw = [Console]::In.ReadToEnd()
  if (-not $raw.Trim()) {
    exit 0
  }

  $eventName = [string](($raw | ConvertFrom-Json).hook_event_name)
  if (-not $eventName -or -not $mapping.ContainsKey($eventName)) {
    exit 0
  }

  $config = Read-Config -Path (Join-Path $PSScriptRoot 'config.json')

  Invoke-HookAction -Action $mapping[$eventName] -Config $config -StatePath (Get-StatePath)
  exit 0
} catch {
  # Hook 出错不能影响 Agent 本身。
  exit 0
}
