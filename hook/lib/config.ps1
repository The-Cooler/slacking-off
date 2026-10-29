# 配置读写。与 Agent、与窗口系统无关。

function New-DefaultConfig {
  return [pscustomobject]@{
    enabled     = $true
    chromePath  = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
    extensionId = ''
  }
}

function Read-Config {
  param([string]$Path)

  $config = New-DefaultConfig

  if (-not (Test-Path $Path)) {
    return $config
  }

  try {
    $data = Get-Content -Raw -Encoding UTF8 $Path | ConvertFrom-Json

    if ($null -ne $data.enabled) { $config.enabled = [bool]$data.enabled }
    if ($null -ne $data.chromePath) { $config.chromePath = [string]$data.chromePath }
    if ($null -ne $data.extensionId) { $config.extensionId = [string]$data.extensionId }
  } catch {
  }

  return $config
}

function Save-Config {
  param([string]$Path, $Config)

  $directory = Split-Path -Parent $Path
  if ($directory -and -not (Test-Path $directory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
  }

  $json = $Config | ConvertTo-Json -Compress
  [IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding($false)))
}

# 命令页 URL：Hook 层与插件的唯一接口，格式定义在这里。
function Get-VideoCommandUrl {
  param($Config)

  return "chrome-extension://$($Config.extensionId)/command/command.html?cmd=idle"
}
