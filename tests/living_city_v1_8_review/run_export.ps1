param([string]$Build,[string]$Output)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Path $Output -Force|Out-Null
$records=@()
foreach($phase in @('prepare','reload','cancel-reload')) {
  $start=Get-Date
  $p=Start-Process (Join-Path $Build 'play-copy/Samhan660.exe') -WorkingDirectory (Join-Path $Build 'play-copy') -ArgumentList @('--log-file',('"'+$Output+'/'+$phase+'.log"'),'--','--qa-v1-8',('--phase='+$phase),('"--out='+$Output+'"')) -PassThru
  $p.WaitForExit()
  $records += [pscustomobject]@{Phase=$phase;PID=$p.Id;Start=$start;End=(Get-Date);ExitCode=$p.ExitCode}
  $records|ConvertTo-Json|Set-Content (Join-Path $Output 'processes.json') -Encoding UTF8
  $result=Get-Content -LiteralPath (Join-Path $Output ($phase+'-result.json')) -Raw|ConvertFrom-Json
  if($p.ExitCode -ne 0 -or $result.failures -ne 0){throw ('Failed '+$phase)}
}
