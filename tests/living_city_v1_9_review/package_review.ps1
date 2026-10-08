$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$review=Join-Path $PSScriptRoot 'review'
New-Item -ItemType Directory -Path $review -Force|Out-Null
foreach($screen in @('sortie','result')){foreach($height in @(720,1080)){
 $before=[Drawing.Image]::FromFile((Join-Path $PSScriptRoot ('before-'+$screen+'-'+$height+'.png')))
 $after=[Drawing.Image]::FromFile((Join-Path $PSScriptRoot ('release-export/victory-'+$screen+'-'+$height+'.png')))
 $bitmap=New-Object Drawing.Bitmap ($before.Width*2),($height+36)
 $g=[Drawing.Graphics]::FromImage($bitmap);$g.Clear([Drawing.Color]::Black)
 $font=New-Object Drawing.Font 'Arial',16
 $g.DrawString('BEFORE / 642-08 Silla',[Drawing.Font]$font,[Drawing.Brushes]::White,10,4)
 $g.DrawString('V1.9 / 642-08 Silla',[Drawing.Font]$font,[Drawing.Brushes]::White,($before.Width+10),4)
 $g.DrawImageUnscaled($before,0,36);$g.DrawImageUnscaled($after,$before.Width,36)
 $bitmap.Save((Join-Path $review ('comparison-'+$screen+'-'+$height+'.png')),[Drawing.Imaging.ImageFormat]::Png)
 $g.Dispose();$font.Dispose();$bitmap.Dispose();$before.Dispose();$after.Dispose()
}}
foreach($name in @('victory-sortie-720','victory-sortie-1080','victory-result-720','victory-result-1080','defeat-result-720','defeat-result-1080','victory-final-720','victory-detail-scroll','restored-victory-1080','restored-defeat-1080')){
 Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('release-export/'+$name+'.png')) -Destination $review
}
$report=Join-Path $PSScriptRoot '../LIVING_CITY_UI_V1_9.md'
$path=Join-Path $PSScriptRoot '../Samhan660_Living_City_UI_V1_9_Review_20261001.zip'
$stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew)
$zip=New-Object IO.Compression.ZipArchive ($stream,[IO.Compression.ZipArchiveMode]::Create)
try{
 [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$report,'LIVING_CITY_UI_V1_9.md',[IO.Compression.CompressionLevel]::Optimal)|Out-Null
 foreach($f in Get-ChildItem $review -File){[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$f.FullName,('living_city_v1_9_review/review/'+$f.Name),[IO.Compression.CompressionLevel]::Optimal)|Out-Null}
}finally{$zip.Dispose();$stream.Dispose()}
Get-Item -LiteralPath $path|Select-Object FullName,Length
