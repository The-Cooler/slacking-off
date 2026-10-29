# Windows 窗口操作。整个系统中唯一依赖 Win32 API 的部分，
# 换平台时只需替换本文件。

Add-Type -Namespace SlackingOff -Name Win32 -MemberDefinition @"
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hWnd);
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
"@

$script:SwMinimize = 6
$script:SwRestore = 9
$script:ChromeProcessName = 'chrome'

function Get-ForegroundWindowHandle {
  return [int64][SlackingOff.Win32]::GetForegroundWindow()
}

function Get-ProcessNameForWindow {
  param([int64]$Handle)

  if ($Handle -eq 0) {
    return ''
  }

  [uint32]$processId = 0
  [void][SlackingOff.Win32]::GetWindowThreadProcessId([IntPtr]$Handle, [ref]$processId)

  if ($processId -eq 0) {
    return ''
  }

  try {
    return (Get-Process -Id $processId -ErrorAction Stop).ProcessName.ToLower()
  } catch {
    return ''
  }
}

function Test-WindowAlive {
  param([int64]$Handle)

  if ($Handle -eq 0) {
    return $false
  }

  return [SlackingOff.Win32]::IsWindow([IntPtr]$Handle)
}

function Show-WindowMinimized {
  param([int64]$Handle)

  if (-not (Test-WindowAlive $Handle)) {
    return
  }

  [void][SlackingOff.Win32]::ShowWindow([IntPtr]$Handle, $script:SwMinimize)
}

function Show-WindowRestoredAndFocused {
  param([int64]$Handle)

  if (-not (Test-WindowAlive $Handle)) {
    return
  }

  [void][SlackingOff.Win32]::ShowWindow([IntPtr]$Handle, $script:SwRestore)
  [void][SlackingOff.Win32]::SetForegroundWindow([IntPtr]$Handle)
}

# 启动浏览器打开命令页，并等待它成为前台窗口，返回该窗口句柄供之后最小化。
# 浏览器已在运行时 Chrome 会把 URL 交给现有窗口，即复用同一个浏览器。
function Start-VideoBrowser {
  param([string]$ChromePath, [string]$Url, [int]$TimeoutSeconds = 5)

  Start-Process -FilePath $ChromePath -ArgumentList $Url

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 150

    $handle = Get-ForegroundWindowHandle
    if ((Get-ProcessNameForWindow $handle) -eq $script:ChromeProcessName) {
      return $handle
    }
  }

  return [int64]0
}
