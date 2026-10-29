# 计算未声明 key 的扩展 ID：SHA-256(UTF-16LE(绝对路径)) 前 16 字节，十六进制位映射到 a-p。
# 用于填 hook/config.json 的 extensionId。

param(
  [string]$Path = (Join-Path $PSScriptRoot '.')
)

$ErrorActionPreference = 'Stop'

$absolutePath = (Resolve-Path $Path).Path.TrimEnd('\')
$bytes = [Text.Encoding]::Unicode.GetBytes($absolutePath)
$hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
$hex = -join ($hash[0..15] | ForEach-Object { $_.ToString('x2') })

$id = -join ($hex.ToCharArray() | ForEach-Object {
  # 先把十六进制字符转成 0-15 的数值，再映射到 a-p。
  $value = [Convert]::ToInt32($_, 16)
  [char]([int][char]'a' + $value)
})

"路径: $absolutePath"
"ID  : $id"
