$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root=Join-Path (Get-Location) 'tests/living_city_v1_6_review'
$bundle=Join-Path $root 'bundle'
$pictures=Join-Path $bundle 'living_city_v1_6_review'
New-Item -ItemType Directory -Force -Path "$pictures/flow" | Out-Null
$font=New-Object Drawing.Font('Arial',18)
foreach($height in @(720,1080)) {
 foreach($view in @('supply','formation','training')) {
  $width=if($height -eq 720){640}else{960}
  $tileHeight=[int]($width*9/16)
  $image=New-Object Drawing.Bitmap(($width*2),($tileHeight+48))
  $g=[Drawing.Graphics]::FromImage($image)
  try {
   $g.Clear([Drawing.Color]::FromArgb(245,240,229))
   $g.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
   $column=0
   foreach($phase in @('before','after')) {
    $name="${phase}_${height}_${view}.png"
    $source=Join-Path $root $name
    $tile=[Drawing.Image]::FromFile($source)
    try {
     $expectedWidth=[int]($height*16/9)
     if($tile.Width -ne $expectedWidth -or $tile.Height -ne $height){throw "Unexpected capture size: $name"}
     $g.DrawImage($tile,($column*$width),48,$width,$tileHeight)
     $g.DrawString("$phase / $view / ${expectedWidth}x$height",$font,[Drawing.Brushes]::Black,($column*$width+12),10)
    } finally {$tile.Dispose()}
    Copy-Item -LiteralPath $source -Destination $pictures
    $column++
   }
   $comparison=Join-Path $root "compare_${height}_${view}.jpg"
   $image.Save($comparison,[Drawing.Imaging.ImageFormat]::Jpeg)
   Copy-Item -LiteralPath $comparison -Destination $pictures
  } finally {$g.Dispose();$image.Dispose()}
 }
}
$font.Dispose()
foreach($name in @('720_supply_incoming','720_equipment_preview','1080_equipment_preview','720_training_quote','1080_training_quote','720_training_complete','1080_training_complete')) {
 Copy-Item -LiteralPath (Join-Path $root "flow/$name.png") -Destination "$pictures/flow/"
}
$report=Join-Path (Get-Location) 'tests/LIVING_CITY_UI_V1_6.md'
Copy-Item -LiteralPath $report -Destination $bundle
$zip=Join-Path (Get-Location) 'tests/Samhan660_Living_City_UI_V1_6_Review_20260930.zip'
if(Test-Path -LiteralPath $zip){throw 'Preserve existing review ZIP; choose a new name.'}
[IO.Compression.ZipFile]::CreateFromDirectory($bundle,$zip,[IO.Compression.CompressionLevel]::Optimal,$false)
$archive=[IO.Compression.ZipFile]::OpenRead($zip)
try {
 $entries=@($archive.Entries|ForEach-Object {$_.FullName.Replace('\','/')})
 $links=[regex]::Matches([IO.File]::ReadAllText($report),'\]\((living_city_v1_6_review/[^)]+)\)')|ForEach-Object {$_.Groups[1].Value}
 $missing=@($links|Where-Object {$_ -notin $entries})
 if($missing.Count){throw ('Missing report image links: '+($missing -join ', '))}
 $other=@($entries|Where-Object {$_ -notmatch '\.(md|png|jpg)$'})
 if($other.Count){throw 'Unexpected non-report/capture payload'}
 [pscustomobject]@{Zip=$zip;Bytes=(Get-Item $zip).Length;MiB=[Math]::Round((Get-Item $zip).Length/1MB,2);Entries=$entries.Count;MissingLinks=$missing.Count;OnlyReportAndCaptures=($other.Count -eq 0)}|ConvertTo-Json|Set-Content (Join-Path $root 'package-result.json') -Encoding UTF8
 Get-Content (Join-Path $root 'package-result.json') -Encoding UTF8
} finally {$archive.Dispose()}
