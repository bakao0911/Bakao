# ChatGPT PC Remote Bootstrap
# Owner-authorized setup helper. Does not bypass authentication or expose unauthenticated ports.
$ErrorActionPreference='Continue'
$root=Join-Path $env:LOCALAPPDATA 'ChatGPT-Remote-Bootstrap'
New-Item -ItemType Directory -Force -Path $root|Out-Null
function Log($m){Add-Content -Path (Join-Path $root 'bootstrap.log') -Value "[$((Get-Date).ToString('s'))] $m" -Encoding UTF8}
Log 'Bootstrap start'
if(-not (Get-Command node -ErrorAction SilentlyContinue) -and (Get-Command winget -ErrorAction SilentlyContinue)){
  winget install --id OpenJS.NodeJS.LTS -e --accept-package-agreements --accept-source-agreements --silent
  $env:Path="$env:ProgramFiles\nodejs;$env:Path"
}
if(Get-Command npx -ErrorAction SilentlyContinue){
  $rdc=Join-Path $root 'desktop-commander.log'
  Start-Process powershell.exe -WindowStyle Minimized -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-Command',"npx -y @wonderwhy-er/desktop-commander@latest remote *>> `"$rdc`""
  Log 'Remote Desktop Commander launched'
}
if(Get-Command codex -ErrorAction SilentlyContinue){
  try{codex doctor *>> (Join-Path $root 'codex-doctor.log')}catch{}
}
try{Start-Process 'codex://settings/connections/computer'}catch{}
Log 'Bootstrap finished'
