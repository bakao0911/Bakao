# ChatGPT PC Remote Bootstrap v2
# Owner-authorized recovery helper. Does not bypass authentication, MFA, QR/device verification, or expose unauthenticated ports.
$ErrorActionPreference='Continue'
$root=Join-Path $env:LOCALAPPDATA 'ChatGPT-Remote-Bootstrap'
New-Item -ItemType Directory -Force -Path $root|Out-Null
$log=Join-Path $root 'bootstrap.log'
function Log($m){Add-Content -Path $log -Value "[$((Get-Date).ToString('s'))] $m" -Encoding UTF8}
function Has($n){$null -ne (Get-Command $n -ErrorAction SilentlyContinue)}
function State{
  [ordered]@{time=(Get-Date).ToString('o');computer=$env:COMPUTERNAME;user=$env:USERNAME;
    node=if(Has 'node'){(& node --version 2>$null)-join ''}else{$null};
    codex=if(Has 'codex'){(Get-Command codex).Source}else{$null};
    code=if(Has 'code'){(Get-Command code).Source}else{$null};steam=[bool](Get-Process steam -ErrorAction SilentlyContinue);
    chatgpt=[bool](Get-Process ChatGPT -ErrorAction SilentlyContinue);
    cached_rdc_device=Test-Path (Join-Path $HOME '.desktop-commander-device\device.json')
  }|ConvertTo-Json|Set-Content (Join-Path $root 'state.json') -Encoding UTF8
}
Log 'Bootstrap v2 start';State
$needNode=$true
if(Has 'node'){try{$v=(& node --version).Trim().TrimStart('v');if([version]$v -ge [version]'18.0.0'){$needNode=$false}}catch{}}
if($needNode -and (Has 'winget')){Log 'Installing Node.js LTS';winget install --id OpenJS.NodeJS.LTS -e --accept-package-agreements --accept-source-agreements --silent;$env:Path="$env:ProgramFiles\nodejs;$env:LOCALAPPDATA\Programs\nodejs;$env:Path"}
if(-not (Has 'codex') -and (Has 'npm')){Log 'Installing current Codex CLI';npm install -g @openai/codex@latest *>> (Join-Path $root 'codex-install.log')}
if(Has 'npx'){
  $rdc=Join-Path $root 'desktop-commander.log';$already=Get-CimInstance Win32_Process -ErrorAction SilentlyContinue|Where-Object{$_.CommandLine -match 'desktop-commander.+remote'}
  if(-not $already){Start-Process powershell.exe -WindowStyle Minimized -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-Command',"npx -y @wonderwhy-er/desktop-commander@latest remote *>> `"$rdc`"";Log 'Remote Desktop Commander launched'}else{Log 'Remote Desktop Commander already running'}
}
if(Has 'codex'){
  try{codex update *>> (Join-Path $root 'codex-update.log')}catch{}
  try{codex doctor *>> (Join-Path $root 'codex-doctor.log')}catch{}
  try{codex remote-control start --json *>> (Join-Path $root 'remote-control-start.json');Log 'Codex Remote Control start requested'}catch{Log "remote-control start failed: $($_.Exception.Message)"}
  try{$pair=(codex remote-control pair --json 2>&1|Out-String);$pair|Set-Content (Join-Path $root 'pairing.json') -Encoding UTF8;Log 'Pairing code generated'}catch{Log "pair generation failed: $($_.Exception.Message)"}
  try{codex app *>> (Join-Path $root 'codex-app.log')}catch{}
}
try{Start-Process 'codex://settings/connections/computer'}catch{Log 'Codex deep link unavailable'}
# If Dropbox desktop is installed, copy the short-lived pairing result to the user's private synced Dropbox for recovery/diagnostics.
foreach($info in @((Join-Path $env:APPDATA 'Dropbox\info.json'),(Join-Path $env:LOCALAPPDATA 'Dropbox\info.json'))){
  if(Test-Path $info){try{$j=Get-Content $info -Raw|ConvertFrom-Json;$db=$j.personal.path;if($db){$d=Join-Path $db 'ChatGPT-Remote';New-Item -ItemType Directory -Force -Path $d|Out-Null;Copy-Item (Join-Path $root 'pairing.json') (Join-Path $d 'pairing.json') -Force -ErrorAction SilentlyContinue;Copy-Item (Join-Path $root 'state.json') (Join-Path $d 'state.json') -Force -ErrorAction SilentlyContinue;Log "Recovery state copied to Dropbox"}}catch{}}
}
foreach($svc in 'Tailscale','AnyDesk','TeamViewer','TeamViewer_Service','chromoting','RustDesk'){try{$s=Get-Service $svc -ErrorAction SilentlyContinue;if($s -and $s.Status -ne 'Running'){Start-Service $svc -ErrorAction SilentlyContinue;Log "Started existing service $svc"}}catch{}}
try{$self=$MyInvocation.MyCommand.Path;if($self){$a=New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$self`"";$t=New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME;$p=New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited;Register-ScheduledTask -TaskName 'ChatGPT Remote Bootstrap' -Action $a -Trigger $t -Principal $p -Force|Out-Null;Log 'Registered logon retry task'}}catch{Log "Scheduled task failed: $($_.Exception.Message)"}
State;Log 'Bootstrap v2 finished'
