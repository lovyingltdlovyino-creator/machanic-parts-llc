$ErrorActionPreference = 'Stop'
$path = 'c:\Users\USER\Desktop\carpartmarket\mechanic_part\lib\main.dart'
if (!(Test-Path -LiteralPath $path)) { Write-Error "File not found: $path"; exit 1 }
$text = Get-Content -LiteralPath $path -Raw
# Ensure the two anchor lines are comments
$fixed = [regex]::Replace($text, '^(\s*)Check if user is trying to chat with themselves\s*$', '$1// Check if user is trying to chat with themselves', 'Multiline')
Set-Content -LiteralPath $path -Value $fixed -Encoding UTF8
Write-Host "Anchors fixed in: $path"
