$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root=Join-Path (Get-Location) 'tests/windows_dpi_v1_5_1_review'
$bundle=Join-Path $root 'review'
$images=Join-Path $bundle 'images'
New-Item -ItemType Directory -Force -Path $images | Out-Null
$names=@()
foreach($scale in @(100,125,150)) {
 foreach($screen in @('domestic','officers','governor','production','build','research')) {
  $name="$screen-$scale"
  if($name -eq 'build-100'){$name='build-disabled-100'}
  $names+=$name
 }
}
$names+=@('production-scroll-100','army-overview-100','army-formation-100','army-training-100','officer-changed-100','development-confirmed-100','development-cancelled-100','governor-confirmed-100','build-confirmed-100','build-cancelled-100','build-confirmed-125','build-cancelled-125','build-confirmed-150','build-cancelled-150','research-confirmed-100','research-cancelled-100','focus-150','escape-150')
$encoder=[Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object MimeType -eq 'image/jpeg'
$parameters=New-Object Drawing.Imaging.EncoderParameters(1)
$parameters.Param[0]=New-Object Drawing.Imaging.EncoderParameter([Drawing.Imaging.Encoder]::Quality,[long]90)
$cards=@()
$metrics=@()
foreach($name in $names) {
 $source=Join-Path $root "$name.png"
 $im=[Drawing.Image]::FromFile($source)
 try{$im.Save((Join-Path $images "$name.jpg"),$encoder,$parameters)}finally{$im.Dispose()}
 $m=Get-Content ($source+'.json') -Raw -Encoding UTF8 | ConvertFrom-Json
 $metrics+=[pscustomobject]@{Image="$name.jpg";Metrics=$m}
 $cards+="<figure><a href='images/$name.jpg'><img loading='lazy' src='images/$name.jpg' alt='$name'></a><figcaption>$name — $($m.ClientWidth) × $($m.ClientHeight) physical pixels</figcaption></figure>"
}
$parameters.Dispose()
$metrics|ConvertTo-Json -Depth 8|Set-Content (Join-Path $bundle 'capture-metrics.json') -Encoding UTF8
Copy-Item -LiteralPath (Join-Path (Get-Location) 'tests/WINDOWS_DPI_V1_5_1.md') -Destination $bundle
foreach($file in @('original-display.json','environment-125.json','environment-150-initial.json','restored-display.json','window-awareness.json','final-preservation.json','contact-final.jpg')) {
 Copy-Item -LiteralPath (Join-Path $root $file) -Destination $bundle
}
$html=@"
<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Samhan660 V1.5.1 DPI review</title>
<style>body{max-width:1400px;margin:32px auto;padding:0 20px;font:16px/1.6 system-ui;background:#f6f2e9;color:#27231c}h1{font-size:28px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(380px,1fr));gap:20px}figure{margin:0;padding:10px;background:white;border:1px solid #b9a36a}img{width:100%;height:auto}figcaption{overflow-wrap:anywhere}a{color:#805008}aside{padding:16px;background:#fff2d0}</style>
<h1>V1.5.1 실제 Windows DPI 검토</h1><aside>같은 PC에서 Windows 100%·125%·150%를 적용한 실제 실행본 화면입니다. 다른 PC 및 그 PC의 저장 복원은 미검증입니다. 원래 100%로 복원했습니다. 과거 168개 검사를 새로 실행한 결과가 아닙니다.</aside>
<p><a href="WINDOWS_DPI_V1_5_1.md">전체 보고서 · 미검증 범위 · 다음 VS Code 지시문</a> / <a href="contact-final.jpg">18개 화면 조합 한눈에 보기</a> / <a href="capture-metrics.json">각 캡처의 물리 크기</a></p>
<p>이미지를 누르면 원래 표시 크기의 JPEG가 열립니다. 동일 픽셀 크기로 강제 비교한 결과가 아닙니다. 앞의 18장은 세 배율의 여섯 대표 화면, 이후는 군사 준비와 조작 상태 증거입니다. 게임 수정 전후가 아닙니다. 원본 PNG는 프로젝트 검수 폴더에 보존했습니다.</p>
<main>$($cards -join "`n")</main></html>
"@
[IO.File]::WriteAllText((Join-Path $bundle 'index.html'),$html,[Text.UTF8Encoding]::new($false))
$zip=Join-Path (Get-Location) 'tests/Samhan660_Windows_DPI_V1_5_1_Review_20260930.zip'
if(Test-Path -LiteralPath $zip){throw 'Review ZIP already exists; preserve it and choose a new name.'}
[IO.Compression.ZipFile]::CreateFromDirectory($bundle,$zip,[IO.Compression.CompressionLevel]::Optimal,$false)
$archive=[IO.Compression.ZipFile]::OpenRead($zip)
try {
 $entries=@($archive.Entries | ForEach-Object {$_.FullName.Replace('\','/')})
 $links=[regex]::Matches($html,'(?:href|src)="([^"]+)"|(?:href|src)=''([^'']+)''') | ForEach-Object {if($_.Groups[1].Success){$_.Groups[1].Value}else{$_.Groups[2].Value}}
 $missing=@($links|Where-Object {$_ -notin $entries})
 if($missing.Count){throw ('Missing ZIP links: '+($missing -join ', '))}
 [pscustomobject]@{Zip=$zip;Bytes=(Get-Item $zip).Length;MiB=[Math]::Round((Get-Item $zip).Length/1MB,2);Entries=$entries.Count;Images=$names.Count;MissingLinks=$missing.Count}|ConvertTo-Json|Set-Content (Join-Path $root 'package-result.json') -Encoding UTF8
 Get-Content (Join-Path $root 'package-result.json') -Encoding UTF8
} finally {$archive.Dispose()}
