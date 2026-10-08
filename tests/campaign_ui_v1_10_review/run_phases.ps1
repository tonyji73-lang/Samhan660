param([string]$Engine,[string]$Project,[string]$Output,[string[]]$Phases=@('silla','baekje','goguryeo','reload'))
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Path $Output -Force|Out-Null
$records=@()
foreach($phase in $Phases){
 $arguments=@('--log-file',('"'+$Output+'/'+$phase+'.log"'))
 if($Project){$arguments+=@('--path',('"'+$Project+'"'))}
 $arguments+=@('--','--qa-v1-10',('--phase='+$phase),('"--out='+$Output+'"'))
 $p=Start-Process $Engine -WindowStyle Normal -WorkingDirectory (Split-Path $Engine -Parent) -ArgumentList $arguments -PassThru
 $p.WaitForExit()
 $records += [pscustomobject]@{Phase=$phase;PID=$p.Id;Exit=$p.ExitCode;Finished=(Get-Date).ToString('o')}
 $records|ConvertTo-Json|Set-Content (Join-Path $Output 'processes.json') -Encoding UTF8
 $result=Get-Content -Raw -Encoding UTF8 (Join-Path $Output ($phase+'-result.json'))|ConvertFrom-Json
 if(Select-String -LiteralPath (Join-Path $Output ($phase+'.log')) -Pattern 'SCRIPT ERROR|Parse Error' -Quiet){throw ('Script error '+$phase)}
 if($p.ExitCode -ne 0 -or $result.failures -ne 0){throw ('Failed '+$phase)}
}
