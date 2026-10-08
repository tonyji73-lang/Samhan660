$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$review = $PSScriptRoot
$utf8 = New-Object System.Text.UTF8Encoding($false)
$views = @('production', 'requirements', 'build_selected', 'research_selected', 'production_selected')
$html = [Text.StringBuilder]::new()
[void]$html.Append('<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Living City V1.4 비교</title><style>body{background:#201e1a;color:#f4e7c9;font:16px sans-serif;margin:24px}img{width:100%;height:auto}section{max-width:1400px;margin:36px auto}a{color:#d5b46f}.pair{display:grid;grid-template-columns:1fr 1fr;gap:12px}figure{margin:0}figcaption{padding:8px}</style><h1>Living City V1.4</h1><p>632년 신라·금성. 왼쪽 수정 전, 오른쪽 수정 후. 같은 표시 크기이며 원본 이미지를 누르면 실제 해상도로 열립니다.</p><p><a href="LIVING_CITY_UI_V1_4.md">적용 보고서</a></p>')
foreach ($height in @(720,1080)) {
    foreach ($view in $views) {
        $beforeName = "before_${height}_${view}.png"
        $afterName = "after_${height}_${view}.png"
        [void]$html.Append("<section><h2>${view} — ${height}p</h2><div class='pair'><figure><a href='$beforeName'><img src='$beforeName' alt='수정 전'></a><figcaption>수정 전</figcaption></figure><figure><a href='$afterName'><img src='$afterName' alt='수정 후'></a><figcaption>수정 후</figcaption></figure></div></section>")
        $canvas = New-Object Drawing.Bitmap(1280,360)
        $graphics = [Drawing.Graphics]::FromImage($canvas)
        $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $before = [Drawing.Image]::FromFile((Join-Path $review $beforeName))
        $after = [Drawing.Image]::FromFile((Join-Path $review $afterName))
        $graphics.DrawImage($before,0,0,640,360)
        $graphics.DrawImage($after,640,0,640,360)
        $canvas.Save((Join-Path $review "compare_${height}_${view}.jpg"),[Drawing.Imaging.ImageFormat]::Jpeg)
        $before.Dispose(); $after.Dispose(); $graphics.Dispose(); $canvas.Dispose()
    }
}
[void]$html.Append('</html>')
[IO.File]::WriteAllText((Join-Path $review 'index.html'),$html.ToString(),$utf8)
