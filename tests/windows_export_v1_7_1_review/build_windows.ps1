param(
    [Parameter(Mandatory=$true)][string]$Editor,
    [Parameter(Mandatory=$true)][string]$TemplateArchive,
    [Parameter(Mandatory=$true)][string]$TemplateSHA512,
    [Parameter(Mandatory=$true)][string]$Destination
)
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$target=[IO.Path]::GetFullPath($Destination)
if($target.StartsWith($project,[StringComparison]::OrdinalIgnoreCase)){throw 'Destination must be outside the project.'}
if(Test-Path -LiteralPath $target){throw 'Choose a NEW destination to preserve existing builds.'}
if((Get-FileHash -LiteralPath $TemplateArchive -Algorithm SHA512).Hash -ine $TemplateSHA512){throw 'Template SHA512 mismatch.'}
New-Item -ItemType Directory -Path "$target/source","$target/tools","$target/build","$target/play-copy" -Force | Out-Null
robocopy $project "$target/source" /E /XD .git .godot tests dev .codex .agents /XF *.zip *.log /R:0 /W:0 /NFL /NDL /NJH /NJS /NP
if($LASTEXITCODE -gt 7){throw 'Source copy failed.'}
Copy-Item -LiteralPath $Editor -Destination "$target/tools/Godot.exe"
New-Item -ItemType File -Path "$target/tools/_sc_" | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
$templates="$target/tools/editor_data/export_templates/4.7.2.stable"
New-Item -ItemType Directory -Path $templates -Force | Out-Null
$zip=[IO.Compression.ZipFile]::OpenRead($TemplateArchive)
try {
    foreach($entry in $zip.Entries){
        if($entry.Name -match '^windows_.*x86_64' -or $entry.Name -eq 'version.txt'){
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,(Join-Path $templates $entry.Name),$false)
        }
    }
} finally {$zip.Dispose()}
if((Get-Content "$templates/version.txt" -Raw).Trim() -ne '4.7.2.stable'){throw 'Wrong template version.'}
$engineVersion=(& "$target/tools/Godot.exe" --version | Out-String).Trim()
if($engineVersion -ne '4.7.2.stable.official.ed1daf0bf'){throw "Wrong editor version: $engineVersion"}
New-Item -ItemType Directory "$target/source/qa" | Out-Null
Copy-Item "$PSScriptRoot/runtime_qa.gd" "$target/source/qa/windows_export_v1_7_1.gd"
Copy-Item "$PSScriptRoot/base_qa.gd" "$target/source/qa/base_qa.gd"
$configPath="$target/source/project.godot"
$config=[IO.File]::ReadAllText($configPath).Replace('[autoload]',"[autoload]`nWindowsExportQA=`"*res://qa/windows_export_v1_7_1.gd`"")
[IO.File]::WriteAllText($configPath,$config,(New-Object System.Text.UTF8Encoding($false)))
& "$target/tools/Godot.exe" --headless --editor --path "$target/source" --import --log-file "$target/import.log" | Out-Host
if($LASTEXITCODE -ne 0){throw 'Import failed.'}
& "$target/tools/Godot.exe" --headless --path "$target/source" --export-release 'Windows Desktop' "$target/build/Samhan660.exe" --log-file "$target/export.log" | Out-Host
if($LASTEXITCODE -ne 0){throw 'Export failed.'}
Copy-Item "$target/build/*" "$target/play-copy/"
Copy-Item "$project/licenses" "$target/play-copy/licenses" -Recurse
Write-Output "Build complete: $target/play-copy/Samhan660.exe"

