$ErrorActionPreference = 'Stop'
$nodeCommand = Get-Command node.exe -ErrorAction SilentlyContinue
if ($nodeCommand) { $plannerNodePath = $nodeCommand.Source }
else {
  $plannerNodePath = Get-ChildItem 'C:\Program Files\WindowsApps\OpenAI.CodexPrimaryRuntime.*\dependencies\node\bin\node.exe' -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
  if (-not $plannerNodePath) {
    $plannerNodePath = Get-ChildItem 'C:\Program Files\WindowsApps\OpenAI.CodexPrimaryRuntime.*\dependencies\node.exe' -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
  }
}
if (-not $plannerNodePath) { throw 'Node.js 20+ is required. Install Node.js, then run start.cmd again.' }
$plannerPort = if ($env:PORT) { [int]$env:PORT } else { 3000 }
$plannerUrl = "http://127.0.0.1:$plannerPort"
try {
  $existing = Invoke-RestMethod "$plannerUrl/api/sections" -TimeoutSec 2
  if ($existing.sections) { Start-Process $plannerUrl; Write-Host "Already running: $plannerUrl"; exit 0 }
} catch { }
$plannerServer = Start-Process -FilePath $plannerNodePath -ArgumentList @("`"$PSScriptRoot\server.mjs`"") -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -PassThru
try {
  $plannerReady = $false
  for ($attempt=0; $attempt -lt 20; $attempt++) {
    Start-Sleep -Milliseconds 300
    if ($plannerServer.HasExited) { throw 'Server could not start. Check if port 3000 is already in use.' }
    try { $response = Invoke-RestMethod "$plannerUrl/api/sections" -TimeoutSec 1; if ($response.sections) { $plannerReady=$true; break } } catch { }
  }
  if (-not $plannerReady) { throw 'Server did not become ready.' }
  Start-Process $plannerUrl
  Write-Host "Course Planner: $plannerUrl" -ForegroundColor Green
  Write-Host 'Keep this window open while using the app.'
  Read-Host 'Press Enter to stop the server'
} finally {
  if (-not $plannerServer.HasExited) { Stop-Process -Id $plannerServer.Id }
}
