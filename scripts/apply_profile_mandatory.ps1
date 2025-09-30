$ErrorActionPreference = 'Stop'

$path = 'c:\Users\USER\Desktop\carpartmarket\mechanic_part\lib\main.dart'
if (!(Test-Path -LiteralPath $path)) {
  Write-Error "File not found: $path"
  exit 1
}

$backup = $path + '.bak-' + (Get-Date -Format 'yyyyMMddHHmmss')
Copy-Item -LiteralPath $path -Destination $backup

$text = Get-Content -LiteralPath $path -Raw

# Remove the 'Skip for now' button block (from the comment line to following const SizedBox(height: 16),)
$skipAnchor = "// Skip button"
$skipIdx = $text.IndexOf($skipAnchor)
if ($skipIdx -ge 0) {
  $sizedBoxPattern = "const SizedBox(height: 16)"
  $sizedIdx = $text.IndexOf($sizedBoxPattern, $skipIdx)
  if ($sizedIdx -ge 0) {
    # Move to end of the SizedBox line (include trailing comma and potential newline)
    # Find end of line after the pattern
    $lineEndIdx = $text.IndexOf("`n", $sizedIdx)
    if ($lineEndIdx -lt 0) { $lineEndIdx = $text.Length - 1 }
    $removeEnd = $lineEndIdx + 1
    $text = $text.Substring(0, $skipIdx) + $text.Substring($removeEnd)
  }
}

# Remove the AppBar leading close button on Complete Profile page
$leadAnchor = "leading: IconButton("
$leadIdx = $text.IndexOf($leadAnchor)
if ($leadIdx -ge 0) {
  # Find the end of this IconButton block which ends with ")," on its own line
  $endIdx = $text.IndexOf(")\,", $leadIdx)
  if ($endIdx -ge 0) {
    # Move to end of line
    $lineEndIdx2 = $text.IndexOf("`n", $endIdx)
    if ($lineEndIdx2 -lt 0) { $lineEndIdx2 = $text.Length - 1 }
    $removeEnd2 = $lineEndIdx2 + 1
    $text = $text.Substring(0, $leadIdx) + $text.Substring($removeEnd2)
  }
}

Set-Content -LiteralPath $path -Value $text -Encoding UTF8

Write-Host "Backup created at: $backup"
Write-Host "Mandatory profile completion enforced: removed 'Skip for now' and AppBar close."
