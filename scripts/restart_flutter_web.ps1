$ErrorActionPreference = 'Stop'

$projectDir = 'c:\Users\USER\Desktop\carpartmarket\mechanic_part'

# Attempt to stop existing Flutter run and debug Chrome instances for this project
try {
  $procs = Get-CimInstance Win32_Process | Where-Object {
    ($_.CommandLine -match 'flutter_tools' -or $_.CommandLine -match 'flutter run') -and ($_.CommandLine -match 'mechanic_part')
  }
  foreach ($p in $procs) {
    Write-Host ("Stopping flutter process PID " + $p.ProcessId)
    Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
  }
  # Stop debug Chrome launched by flutter for this project (heuristic)
  $chrome = Get-CimInstance Win32_Process | Where-Object { $_.Name -ieq 'chrome.exe' -and $_.CommandLine -match '--remote-debugging-port' -and $_.CommandLine -match 'mechanic_part' }
  foreach ($c in $chrome) {
    Write-Host ("Stopping debug Chrome PID " + $c.ProcessId)
    Stop-Process -Id $c.ProcessId -Force -ErrorAction SilentlyContinue
  }
} catch {
  Write-Warning $_
}

# Fetch deps and run the app on Chrome
Push-Location $projectDir
try {
  flutter pub get
  flutter run -d chrome
} finally {
  Pop-Location
}
