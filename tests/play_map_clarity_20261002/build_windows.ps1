$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$stamp='20261002_'+(Get-Date -Format 'HHmmss')
$work=Join-Path $env:TEMP ('Samhan660_PlayMap_'+$stamp)
$source=Join-Path $work 'source'
$delivery=Join-Path $env:USERPROFILE ('Downloads/Samhan660_PlayMap_'+$stamp)
$editor=Join-Path $env:LOCALAPPDATA 'Temp/Samhan660_V1_10_Export_Final_20261001/tools/Godot.exe'
if(Test-Path -LiteralPath $delivery){throw 'New destination required'}
New-Item -ItemType Directory -Path $source,$delivery -Force | Out-Null
robocopy $project $source /E /XD .git .godot tests dev .codex .agents /XF *.zip *.log /R:0 /W:0 /NFL /NDL /NJH /NJS /NP | Out-Null
if($LASTEXITCODE -gt 7){throw 'Source copy failed'}
$p=Join-Path $source 'project.godot'
$s=[IO.File]::ReadAllText($p)
$s=[regex]::Replace($s,'(?m)^_mcp_game_helper=.*\r?\n','')
[IO.File]::WriteAllText($p,$s,[Text.UTF8Encoding]::new($false))
$imp=Start-Process -FilePath $editor -ArgumentList @('--headless','--editor','--path',('"'+$source+'"'),'--import','--log-file',('"'+$work+'/import.log"')) -WindowStyle Hidden -PassThru -Wait
if($imp.ExitCode -ne 0){throw 'Import failed'}
$exe=Join-Path $delivery 'Samhan660.exe'
$exp=Start-Process -FilePath $editor -ArgumentList @('--headless','--path',('"'+$source+'"'),'--export-release','"Windows Desktop"',('"'+$exe+'"'),'--log-file',('"'+$work+'/export.log"')) -WindowStyle Hidden -PassThru -Wait
if($exp.ExitCode -ne 0){throw 'Export failed'}
Copy-Item -LiteralPath (Join-Path $project 'licenses') -Destination (Join-Path $delivery 'licenses') -Recurse
$info=@{project=$project;source=$source;delivery=$delivery;exe=$exe;engine='4.7.2.stable.official.ed1daf0bf';import_log="$work/import.log";export_log="$work/export.log";pck_sha256=(Get-FileHash -LiteralPath "$delivery/Samhan660.pck").Hash;changed_sources=@()}
foreach($name in @('ui/korea_layout_v1/terrain_refresh_20261001/detail.gdshader','ui/korea_layout_v1/terrain_refresh_20261001/detail_layer.gd','ui/korea_layout_v1/play_detail_20261002/manifest.json')){$info.changed_sources+=@{path=$name;sha256=(Get-FileHash -LiteralPath (Join-Path $source $name)).Hash}}
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'windows_build.json'),($info|ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $delivery 'BUILD_INFO.json'),($info|ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $delivery '실행안내.txt'),"Samhan660.exe를 실행하세요. EXE와 PCK는 같은 폴더에 두세요.`r`n2026-10-02 플레이 지도 확대 묘사 개선본입니다. 이전 실행본은 보존했습니다.`r`n기존 저장 경로를 사용하며 기존 저장을 삭제하지 않습니다.",[Text.UTF8Encoding]::new($false))
Write-Output $exe