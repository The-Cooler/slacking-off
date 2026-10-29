# 对话内开关：控制是否自动跳转。
# 用法：cli.ps1 status | pause [分钟] | resume | on | off

param(
  [Parameter(Position = 0)]
  [string]$Command = 'status',

  [Parameter(Position = 1)]
  [int]$Minutes = 30
)

$ErrorActionPreference = 'Stop'

try {
  . (Join-Path $PSScriptRoot 'lib\config.ps1')
  . (Join-Path $PSScriptRoot 'lib\state.ps1')

  $configPath = Join-Path $PSScriptRoot 'config.json'
  $statePath = Get-StatePath

  $config = Read-Config -Path $configPath

  switch ($Command.ToLower()) {
    'on' {
      $config.enabled = $true
      Save-Config -Path $configPath -Config $config
      '已开启自动跳转。'
    }
    'off' {
      $config.enabled = $false
      Save-Config -Path $configPath -Config $config
      '已关闭自动跳转。'
    }
    'pause' {
      $state = Read-State -Path $statePath
      Set-Paused -Path $statePath -State $state -Minutes $Minutes
      $until = (Get-UnixEpoch).AddMilliseconds($state.pausedUntil).ToLocalTime()
      "已暂停自动跳转，$($until.ToString('HH:mm')) 自动恢复。"
    }
    'resume' {
      $state = Read-State -Path $statePath
      Clear-Paused -Path $statePath -State $state
      '已恢复自动跳转。'
    }
    default {
      $enabledText = if ($config.enabled) { '开启' } else { '关闭' }
      $state = Read-State -Path $statePath
      $pauseText = if (Test-Paused $state) {
        $until = (Get-UnixEpoch).AddMilliseconds($state.pausedUntil).ToLocalTime()
        "暂停至 $($until.ToString('HH:mm'))"
      } else {
        '未暂停'
      }
      "自动跳转：$enabledText；$pauseText。"
    }
  }
} catch {
  "操作失败：$($_.Exception.Message)"
}

exit 0
