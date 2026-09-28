# ChatGPT PC Remote Bootstrap
# Owner-authorized setup helper. Does not bypass authentication, MFA, QR pairing, or expose unauthenticated ports.
$ErrorActionPreference='Continue'
$root=Join-Path $env:LOCALAPPDATA 'ChatGPT-Remote-Bootstrap'
New-Item -ItemType Directory -Force -Path $root|Out-Null
$log=Join-Path $root 'bootstrap.log'
function Log($m){Add-Content -Path $log -Value "[$((Get-Date).ToString('s'))] $m" -Encoding UTF8}
function Has($n){$null -ne (Get-Command $n -ErrorAction SilentlyContinue)}
function State{
  [ordered]@{
    time=(Get-Date).ToString('o'); computer=$env:COMPUTERNAME; user=$env:USERNAME;
    node=if(Has 'node'){(& node --version 2>$null)-join ''}else{$null};
    codex=if(Has 'codex'){(Get-Command codex).Source}else{$null};
    code=if(Has 'code'){(Get-Command code).Source}else{$null};
    steam=[bool](Get-Process steam -ErrorAction SilentlyContinue);
    chatgpt=[bool](Get-Process ChatGPT -ErrorAction SilentlyContinue);
    cached_rdc_device=Test-Path (Join-Path $HOME '.desktop-commander-device\device.json')
  }|ConvertTo-Json|Set-Content (Join-Path $root 'state.json') -Encoding UTF8
}
Log 'Bootstrap start'; State
$needNode=$true
if(Has 'node'){try{$v=(& node --version).Trim().TrimStart('v');if([version]$v -ge [version]'18.0.0'){$needNode=$false}}catch{}}
if($needNode -and (Has 'winget')){
  Log 'Installing Node.js LTS with winget'
  winget install --id OpenJS.NodeJS.LTS -e --accept-package-agreements --accept-source-agreements --silent
  $env:Path="$env:ProgramFiles\nodejs;$env:LOCALAPPDATA\Programs\nodejs;$env:Path"
}
if(Has 'npx'){
  $rdc=Join-Path $root 'desktop-commander.log'
  $already=Get-CimInstance Win32_Process -ErrorAction SilentlyContinue|Where-Object{$_.CommandLine -match 'desktop-commander.+remote'}
  if(-not $already){
    Start-Process powershell.exe -WindowStyle Minimized -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-Command',"npx -y @wonderwhy-er/desktop-commander@latest remote *>> `"$rdc`""
    Log 'Remote Desktop Commander launched'
  } else { Log 'Remote Desktop Commander already running' }
}
if(Has 'codex'){try{codex doctor *>> (Join-Path $root 'codex-doctor.log')}catch{}}
try{Start-Process 'codex://settings/connections/computer'}catch{Log 'Codex deep link unavailable'}
foreach($svc in 'Tailscale','AnyDesk','TeamViewer','TeamViewer_Service','chromoting','RustDesk'){
  try{$s=Get-Service $svc -ErrorAction SilentlyContinue;if($s -and $s.Status -ne 'Running'){Start-Service $svc -ErrorAction SilentlyContinue;Log "Started existing service $svc"}}catch{}
}
try{
  $self=$MyInvocation.MyCommand.Path
  if($self){
    $a=New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$self`""
    $t=New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    $p=New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
    Register-ScheduledTask -TaskName 'ChatGPT Remote Bootstrap' -Action $a -Trigger $t -Principal $p -Force|Out-Null
    Log 'Registered logon retry task'
  }
}catch{Log "Scheduled task failed: $($_.Exception.Message)"}
State; Log 'Bootstrap finished'
