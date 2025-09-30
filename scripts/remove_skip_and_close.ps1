$ErrorActionPreference = 'Stop'

$path = 'c:\Users\USER\Desktop\carpartmarket\mechanic_part\lib\main.dart'
if (!(Test-Path -LiteralPath $path)) {
  Write-Error "File not found: $path"
  exit 1
}

$backup = $path + '.bak-' + (Get-Date -Format 'yyyyMMddHHmmss')
Copy-Item -LiteralPath $path -Destination $backup

# Read file as raw text
$text = Get-Content -LiteralPath $path -Raw

# 1) Remove the Skip for now button block including its preceding comment and following spacer
$patternSkip = @'
\s*//\s*Skip button\s*\r?\n\s*TextButton\([\s\S]*?\)\s*,\s*\r?\n\s*\r?\n?\s*const\s+SizedBox\(height:\s*16\),\s*\r?\n'@
$text = [regex]::Replace($text, $patternSkip, "`r`n", [System.Text.RegularExpressions.RegexOptions]::Multiline)

# 2) Remove the AppBar leading close IconButton in Complete Profile page
$patternLeading = @'
\s*leading:\s*IconButton\(\s*\r?\n\s*icon:\s*const\s*Icon\(Icons\.close\),\s*\r?\n\s*onPressed:\s*\(\)\s*=>\s*context\.go\('/home'\),\s*\r?\n\s*\),\s*'@
$text = [regex]::Replace($text, $patternLeading, "", [System.Text.RegularExpressions.RegexOptions]::Multiline)

Set-Content -LiteralPath $path -Value $text -Encoding UTF8

Write-Host "Backup created at: $backup"
Write-Host "Removed 'Skip for now' and AppBar close from Complete Profile page."
