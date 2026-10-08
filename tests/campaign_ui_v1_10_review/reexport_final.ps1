param([Parameter(Mandatory=$true)][string]$Build)
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
Copy-Item (Join-Path $project 'settlement_overlay.gd') (Join-Path $Build 'source/settlement_overlay.gd')
Copy-Item (Join-Path $PSScriptRoot 'runtime_qa.gd') (Join-Path $Build 'source/qa/windows_export_v1_10.gd')
Copy-Item (Join-Path $PSScriptRoot 'base_qa.gd') (Join-Path $Build 'source/qa/base_qa.gd')
& "$Build/tools/Godot.exe" --headless --path "$Build/source" --export-release 'Windows Desktop' "$Build/build/Samhan660.exe" --log-file "$Build/export-final.log" | Out-Host
if($LASTEXITCODE -ne 0){throw 'Final export failed'}
Copy-Item "$Build/build/*" "$Build/play-copy/"
Write-Output 'Final play-copy updated.'
