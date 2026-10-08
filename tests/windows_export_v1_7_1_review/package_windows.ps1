param([Parameter(Mandatory=$true)][string]$Build,[Parameter(Mandatory=$true)][string]$ZipPath)
$ErrorActionPreference='Stop'
if(Test-Path -LiteralPath $ZipPath){throw 'Preserve existing ZIP; choose an unused path.'}
$play=Join-Path $Build 'play-copy'
$readme=@(Get-ChildItem -LiteralPath $PSScriptRoot -Filter 'README_*.txt' -File)
if($readme.Count -ne 1){throw 'Expected one execution README.'}
Copy-Item -LiteralPath $readme[0].FullName -Destination $play
Copy-Item -LiteralPath "$PSScriptRoot/OTHER_PC_CHECKLIST.md" -Destination $play
Copy-Item "$PSScriptRoot/source-final.json" "$play/SOURCE_SHA256.json"
$qa=@(); foreach($file in @('runtime_qa.gd','base_qa.gd')){$qa+=@{File=$file;SHA256=(Get-FileHash -LiteralPath (Join-Path $PSScriptRoot $file)).Hash}}
$info=[ordered]@{Version='V1.7.1';Date='2026-09-30';Engine='4.7.2.stable.official.ed1daf0bf';Template='4.7.2.stable';Architecture='x86_64';Preset='Windows Desktop';Branch='main';Head='1dbe7e6546dfb05af9a21a54cf0a3cc3ae8956b5';UsesUncommittedSource=$true;GameChangesThisTask='court_overlay.gd: localize industry duty using existing job kind; no rule/save changes';SourceManifest='SOURCE_SHA256.json';SourceManifestSHA256=(Get-FileHash "$play/SOURCE_SHA256.json").Hash;BuildOnlyChanges='Opt-in QA autoload res://qa/windows_export_v1_7_1.gd; no original project.godot edit';QA=$qa;ExeSHA256=(Get-FileHash "$play/Samhan660.exe").Hash;PackSHA256=(Get-FileHash "$play/Samhan660.pck").Hash}
$info|ConvertTo-Json -Depth 6|Set-Content "$play/BUILD_INFO.json" -Encoding UTF8
$hashes=@(Get-ChildItem -LiteralPath $play -File -Recurse | Where-Object Name -ne 'SHA256SUMS.txt' | ForEach-Object {[pscustomobject]@{Path=$_.FullName.Substring($play.Length+1).Replace('\','/');SHA256=(Get-FileHash -LiteralPath $_.FullName).Hash}})
($hashes | ForEach-Object {$_.SHA256+'  '+$_.Path})|Set-Content "$play/SHA256SUMS.txt" -Encoding ASCII
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$stream=[IO.File]::Open($ZipPath,[IO.FileMode]::CreateNew)
$zip=New-Object IO.Compression.ZipArchive ($stream,[IO.Compression.ZipArchiveMode]::Create)
foreach($file in Get-ChildItem -LiteralPath $play -File -Recurse){$name=$file.FullName.Substring($play.Length+1).Replace('\','/');[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$file.FullName,$name,[IO.Compression.CompressionLevel]::Optimal)|Out-Null}
$zip.Dispose();$stream.Dispose()
$zip=[IO.Compression.ZipFile]::OpenRead($ZipPath);$checked=0
try {foreach($h in $hashes){$entry=$zip.GetEntry($h.Path);if(!$entry){throw ('Missing '+$h.Path)};$s=$entry.Open();$sha=[Security.Cryptography.SHA256]::Create();try{$actual=([BitConverter]::ToString($sha.ComputeHash($s))).Replace('-','')}finally{$s.Dispose();$sha.Dispose()};if($actual -ne $h.SHA256){throw ('Hash mismatch '+$h.Path)};$checked++}}finally{$zip.Dispose()}
[pscustomobject]@{Path=$ZipPath;Bytes=(Get-Item -LiteralPath $ZipPath).Length;SHA256=(Get-FileHash -LiteralPath $ZipPath).Hash;VerifiedPayloads=$checked;Build=$info}|ConvertTo-Json -Depth 8|Set-Content "$PSScriptRoot/package-result.json" -Encoding UTF8
