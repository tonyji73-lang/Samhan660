$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$review=Join-Path $PSScriptRoot 'review'
New-Item -ItemType Directory -Path $review -Force|Out-Null
$pairs=@(
 @('production','baseline/silla-05-production.png','release-final/after-05-production.png','632-01 Silla / gold 900'),
 @('sortie-route','blocker-before/recovery-target-720.png','release-final/recovery-target-720.png','642-07 recovery / gold 850'),
 @('month-report','baseline/silla-month-632-2.png','release-final/report-720.png','632-02 Silla / gold 1998')
)
foreach($pair in $pairs){
 $a=[Drawing.Image]::FromFile((Join-Path $PSScriptRoot $pair[1])); $b=[Drawing.Image]::FromFile((Join-Path $PSScriptRoot $pair[2]))
 if($a.Width -ne $b.Width -or $a.Height -ne $b.Height){throw 'Comparison dimensions differ'}
 $bitmap=New-Object Drawing.Bitmap ($a.Width*2),($a.Height+40)
 $g=[Drawing.Graphics]::FromImage($bitmap); $g.Clear([Drawing.Color]::Black); $font=New-Object Drawing.Font 'Arial',16
 $g.DrawString(('BEFORE / '+$pair[3]),$font,[Drawing.Brushes]::White,10,5)
 $g.DrawString(('V1.10 / '+$pair[3]),$font,[Drawing.Brushes]::White,($a.Width+10),5)
 $g.DrawImageUnscaled($a,0,40); $g.DrawImageUnscaled($b,$a.Width,40)
 $bitmap.Save((Join-Path $review ('comparison-'+$pair[0]+'-720.png')),[Drawing.Imaging.ImageFormat]::Png)
 $g.Dispose();$font.Dispose();$bitmap.Dispose();$a.Dispose();$b.Dispose()
}
foreach($name in @('guide-start-720','report-1080','report-scroll-1080','recovery-target-1080','recovery-sortie-720','recovery-army-1080')){
 Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('release-final/'+$name+'.png')) -Destination $review
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'source-completion/recovery-training-completed-720.png') -Destination $review
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'dpi/dpi125-report.png') -Destination $review
$prefix='campaign_ui_v1_10_review/review/'
$html='<!doctype html><meta charset="utf-8"><title>Samhan660 V1.10 Review</title><style>body{margin:24px;background:#f1ead7;color:#2d281e;font:18px system-ui}img{max-width:100%;height:auto;border:1px solid #947a44}article{margin:28px 0}a{color:#593b10}h1{font-size:28px}</style><h1>Samhan660 V1.10</h1><p><a href="CAMPAIGN_UI_FLOW_AUDIT_V1_10.md">Report</a> / <a href="PLAY_CHECKLIST.md">Play checklist</a></p><p>Windows DPI 125% input / 150% GUI / another PC: NOT VERIFIED. See report. Original scale restored to 100%.</p>'
foreach($file in Get-ChildItem -LiteralPath $review -Filter '*.png' -File | Sort-Object Name){$html+='<article><h2>'+[System.Net.WebUtility]::HtmlEncode($file.BaseName)+'</h2><a href="'+$prefix+$file.Name+'"><img src="'+$prefix+$file.Name+'"></a></article>'}
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'index.html'),$html,(New-Object Text.UTF8Encoding($false)))
$target=Join-Path (Split-Path $PSScriptRoot -Parent) 'Samhan660_Campaign_UI_Flow_V1_10_Review_20261001.zip'
if(Test-Path -LiteralPath $target){throw 'Review ZIP already exists; preserve it.'}
$stream=[IO.File]::Open($target,[IO.FileMode]::CreateNew); $zip=New-Object IO.Compression.ZipArchive ($stream,[IO.Compression.ZipArchiveMode]::Create)
try {
 [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,(Join-Path (Split-Path $PSScriptRoot -Parent) 'CAMPAIGN_UI_FLOW_AUDIT_V1_10.md'),'CAMPAIGN_UI_FLOW_AUDIT_V1_10.md')|Out-Null
 foreach($name in @('PLAY_CHECKLIST.md','index.html')){[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,(Join-Path $PSScriptRoot $name),$name)|Out-Null}
 # Retain the report's relative checklist link as well as the convenient root copy.
 [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,(Join-Path $PSScriptRoot 'PLAY_CHECKLIST.md'),'campaign_ui_v1_10_review/PLAY_CHECKLIST.md')|Out-Null
 foreach($file in Get-ChildItem -LiteralPath $review -Filter '*.png' -File){[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$file.FullName,($prefix+$file.Name))|Out-Null}
}finally{$zip.Dispose();$stream.Dispose()}
$zip=[IO.Compression.ZipFile]::OpenRead($target)
try{
 $names=@($zip.Entries|ForEach-Object FullName); $links=[regex]::Matches($html,'(?:href|src)="([^"]+)"')
 foreach($link in $links){if($link.Groups[1].Value -notin $names){throw ('Missing relative HTML link '+$link.Groups[1].Value)}}
 [pscustomobject]@{Path=$target;Bytes=(Get-Item -LiteralPath $target).Length;SHA256=(Get-FileHash -LiteralPath $target).Hash;Entries=$zip.Entries.Count;RelativeLinksChecked=$links.Count}|ConvertTo-Json|Set-Content (Join-Path $PSScriptRoot 'review-package-result.json') -Encoding UTF8
}finally{$zip.Dispose()}
