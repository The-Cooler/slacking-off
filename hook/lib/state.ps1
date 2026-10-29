# 状态读写与暂停判断。
# pausedUntil 统一用 Unix 毫秒整数存储：PowerShell 5.1 与 7 对 ISO 日期字符串的
# ConvertFrom-Json 处理不同（PS7 会自动转成 DateTime），用整数可避开这个差异。

function Get-StatePath {
  return (Join-Path (Join-Path $env:LOCALAPPDATA 'slacking-off') 'state.json')
}

function New-DefaultState {
  return [pscustomobject]@{
    mode         = 'idle'
    terminalHwnd = [int64]0
    browserHwnd  = [int64]0
    pausedUntil  = [int64]0
  }
}

# 兼容旧版本写入的 ISO 字符串，避免升级后旧状态导致解析失败。
function ConvertTo-EpochMilliseconds {
  param($Value)

  if ($null -eq $Value) {
    return [int64]0
  }

  $number = [int64]0
  if ([int64]::TryParse([string]$Value, [ref]$number)) {
    return $number
  }

  $date = [datetime]::MinValue
  if ([datetime]::TryParse([string]$Value, [ref]$date)) {
    return ([int64]($date.ToUniversalTime() - (Get-UnixEpoch)).TotalMilliseconds)
  }

  return [int64]0
}

function Read-State {
  param([string]$Path)

  $state = New-DefaultState

  if (-not (Test-Path $Path)) {
    return $state
  }

  try {
    $data = Get-Content -Raw -Encoding UTF8 $Path | ConvertFrom-Json

    if ($null -ne $data.mode) { $state.mode = [string]$data.mode }
    if ($null -ne $data.terminalHwnd) { $state.terminalHwnd = [int64]$data.terminalHwnd }
    if ($null -ne $data.browserHwnd) { $state.browserHwnd = [int64]$data.browserHwnd }
    $state.pausedUntil = ConvertTo-EpochMilliseconds $data.pausedUntil
  } catch {
  }

  return $state
}

function Write-State {
  param([string]$Path, $State)

  $directory = Split-Path -Parent $Path
  if ($directory -and -not (Test-Path $directory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
  }

  $json = $State | ConvertTo-Json -Compress
  [IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding($false)))
}

# .NET Framework（PowerShell 5.1）没有 [datetime]::UnixEpoch，显式定义以兼容不同版本。
function Get-UnixEpoch {
  return [datetime]::SpecifyKind((New-Object datetime 1970, 1, 1), [System.DateTimeKind]::Utc)
}

function Get-CurrentEpochMilliseconds {
  return ([int64]([datetime]::UtcNow - (Get-UnixEpoch)).TotalMilliseconds)
}

function Test-Paused {
  param($State)

  return ($State.pausedUntil -gt (Get-CurrentEpochMilliseconds))
}

function Set-Paused {
  param([string]$Path, $State, [int]$Minutes)

  $State.pausedUntil = (Get-CurrentEpochMilliseconds) + ([int64]$Minutes * 60000)
  Write-State -Path $Path -State $State
}

function Clear-Paused {
  param([string]$Path, $State)

  $State.pausedUntil = [int64]0
  Write-State -Path $Path -State $State
}
