param([Parameter(Mandatory=$true)][string]$Play,[Parameter(Mandatory=$true)][string]$Out)
$ErrorActionPreference='Stop'
$runs=@()
foreach($phase in @('respond-compensate','reload-compensate','respond-wait','reload-wait','respond-force','reload-force')) {
 $start=Get-Date -Format o
 $p=Start-Process -FilePath (Join-Path $Play 'Samhan660.exe') -WorkingDirectory $Play -ArgumentList @('--log-file',('"'+$Out+'/'+$phase+'.log"'),'--','--qa-v1-7-1',('--phase='+$phase),('"--out='+$Out+'"')) -PassThru
 if(!$p.WaitForExit(300000)){throw "Timeout in $phase; inspect process $($p.Id)"}
 $result=Get-Content -LiteralPath (Join-Path $Out ($phase+'-result.json')) -Raw -Encoding UTF8|ConvertFrom-Json
 $runs+=@{Phase=$phase;PID=$p.Id;Started=$start;Ended=(Get-Date -Format o);ExitCode=$p.ExitCode;Checks=$result.checks;Failures=$result.failures}
 $runs|ConvertTo-Json -Depth 4|Set-Content (Join-Path $Out 'restart-processes.json') -Encoding UTF8
 if($p.ExitCode -ne 0 -or $result.failures -ne 0){throw "Failed $phase"}
 if(Select-String -LiteralPath (Join-Path $Out ($phase+'.log')) -Pattern 'SCRIPT ERROR|ERROR:|FAIL:'){throw "Runtime error in $phase"}
}
