$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$r=Join-Path (Get-Location) 'tests/windows_export_v1_6_1_review'
$report=Join-Path (Get-Location) 'tests/WINDOWS_EXPORT_V1_6_1.md'
$bundle=Join-Path $r 'review-bundle'
$pictures=Join-Path $bundle 'windows_export_v1_6_1_review'
$zip=Join-Path (Get-Location) 'tests/Samhan660_Windows_V1_6_1_Review_20260930.zip'
if(Test-Path -LiteralPath $zip){throw 'Preserve existing review ZIP'}
New-Item -ItemType Directory -Path $pictures -Force|Out-Null
Copy-Item -LiteralPath $report -Destination $bundle
$links=@([regex]::Matches([IO.File]::ReadAllText($report),'\]\((windows_export_v1_6_1_review/[^)]+)\)')|ForEach-Object {$_.Groups[1].Value}|Select-Object -Unique)
foreach($link in $links){Copy-Item -LiteralPath (Join-Path (Get-Location) "tests/$link") -Destination $pictures}
foreach($height in @(720,1080)){
 foreach($screen in @('supply','formation','training')){Copy-Item -LiteralPath "$r/$screen-$height.png" -Destination $pictures}
}
[IO.Compression.ZipFile]::CreateFromDirectory($bundle,$zip,[IO.Compression.CompressionLevel]::Optimal,$false)
$archive=[IO.Compression.ZipFile]::OpenRead($zip)
try {
 $entries=@($archive.Entries|ForEach-Object {$_.FullName.Replace('\','/')})
 $missing=@($links|Where-Object {$_ -notin $entries})
 $other=@($entries|Where-Object {$_ -notmatch '\.(md|png|jpg)$'})
 if($missing.Count -or $other.Count){throw 'Review payload or link mismatch'}
 [pscustomobject]@{Zip=$zip;Bytes=(Get-Item $zip).Length;MiB=[Math]::Round((Get-Item $zip).Length/1MB,2);Entries=$entries.Count;MissingLinks=$missing.Count;OnlyReportsAndCaptures=($other.Count -eq 0)}|ConvertTo-Json|Set-Content "$r/review-package.json" -Encoding UTF8
 Get-Content "$r/review-package.json" -Encoding UTF8
}finally{$archive.Dispose()}
