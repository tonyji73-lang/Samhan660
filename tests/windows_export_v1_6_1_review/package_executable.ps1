$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$run=(Join-Path $env:LOCALAPPDATA 'Temp/Samhan660_V1_6_1_20260930/play-copy')
$r=Join-Path (Get-Location) 'tests/windows_export_v1_6_1_review'
$zip=Join-Path $env:USERPROFILE 'Downloads/Samhan660_Windows_V1_6_1_20260930.zip'
if(Test-Path -LiteralPath $zip){throw 'Preserve existing ZIP; choose new output name'}
$records=@(Get-ChildItem -LiteralPath $run -File -Recurse | Where-Object Name -ne 'SHA256SUMS.txt' | ForEach-Object {
 [pscustomobject]@{Path=$_.FullName.Substring($run.Length+1).Replace('\','/');SHA256=(Get-FileHash -LiteralPath $_.FullName).Hash}
})
$lines=$records|ForEach-Object {$_.SHA256+'  '+$_.Path}
[IO.File]::WriteAllLines("$run/SHA256SUMS.txt",[string[]]$lines,[Text.UTF8Encoding]::new($false))
[IO.Compression.ZipFile]::CreateFromDirectory($run,$zip,[IO.Compression.CompressionLevel]::Optimal,$false)
$archive=[IO.Compression.ZipFile]::OpenRead($zip)
$verified=0
try {
 foreach($record in $records){
  $entry=$archive.Entries|Where-Object {$_.FullName.Replace('\','/') -eq $record.Path}
  if(!$entry){throw "Missing ZIP entry $($record.Path)"}
  $stream=$entry.Open();$sha=[Security.Cryptography.SHA256]::Create()
  try{$actual=[BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','')}finally{$sha.Dispose();$stream.Dispose()}
  if($actual -ne $record.SHA256){throw "ZIP hash mismatch $($record.Path)"}
  $verified++
 }
 $count=$archive.Entries.Count
}finally{$archive.Dispose()}
[pscustomobject]@{Zip=$zip;Bytes=(Get-Item $zip).Length;MiB=[Math]::Round((Get-Item $zip).Length/1MB,2);SHA256=(Get-FileHash $zip).Hash;Entries=$count;VerifiedPayloadFiles=$verified;Executable='Samhan660.exe'}|ConvertTo-Json|Set-Content "$r/executable-package.json" -Encoding UTF8
Get-Content "$r/executable-package.json" -Encoding UTF8
