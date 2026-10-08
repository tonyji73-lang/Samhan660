$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$review=Join-Path $PSScriptRoot 'review'
New-Item -ItemType Directory -Path $review -Force|Out-Null
foreach($height in @(720,1080)){
  $before=[Drawing.Image]::FromFile((Join-Path $PSScriptRoot ('before-diplomacy-'+$height+'.png')))
  $after=[Drawing.Image]::FromFile((Join-Path $PSScriptRoot ('final-export/diplomacy-'+$height+'.png')))
  $bitmap=New-Object Drawing.Bitmap ($before.Width*2),($height+36)
  $g=[Drawing.Graphics]::FromImage($bitmap)
  $g.Clear([Drawing.Color]::Black)
  $font=New-Object Drawing.Font 'Arial',16
  $g.DrawString('BEFORE / 632-01 Silla',[Drawing.Font]$font,[Drawing.Brushes]::White,10,4)
  $g.DrawString('V1.8 / 632-01 Silla',[Drawing.Font]$font,[Drawing.Brushes]::White,($before.Width+10),4)
  $g.DrawImageUnscaled($before,0,36); $g.DrawImageUnscaled($after,$before.Width,36)
  $bitmap.Save((Join-Path $review ('comparison-'+$height+'.png')),[Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose();$font.Dispose();$bitmap.Dispose();$before.Dispose();$after.Dispose()
}
foreach($name in @('diplomacy-720','diplomacy-1080','envoy-scroll-720','confirm-gift-720','confirm-trade_pact-1080','cancel-quote-720','confirm-cancel_trade_pact-720','cancel-restored-1080','long-name-confirm','insufficient-gold','empty-envoys')){
 Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('final-export/'+$name+'.png')) -Destination $review
}
$report=Join-Path $PSScriptRoot '../LIVING_CITY_UI_V1_8.md'
$path=Join-Path $PSScriptRoot '../Samhan660_Living_City_UI_V1_8_Review_20260930.zip'
$stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew)
$zip=New-Object IO.Compression.ZipArchive ($stream,[IO.Compression.ZipArchiveMode]::Create)
try{
 [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$report,'LIVING_CITY_UI_V1_8.md',[IO.Compression.CompressionLevel]::Optimal)|Out-Null
 foreach($f in Get-ChildItem $review -File){[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$f.FullName,('living_city_v1_8_review/review/'+$f.Name),[IO.Compression.CompressionLevel]::Optimal)|Out-Null}
}finally{$zip.Dispose();$stream.Dispose()}
Get-Item -LiteralPath $path|Select-Object FullName,Length
