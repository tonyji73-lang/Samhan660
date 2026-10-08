param([Parameter(Mandatory=$true)][string]$Evidence)
$ErrorActionPreference='Stop'
$utf8=New-Object System.Text.UTF8Encoding($false)
$html=[Text.StringBuilder]::new()
[void]$html.Append('<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>V1.5 Windows 실행본 검수</title><style>body{margin:24px;background:#201e1a;color:#f4e7c9;font:16px sans-serif}a{color:#d5b46f}section{margin:32px auto;max-width:1600px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:12px}figure{margin:0}img{width:100%;height:auto}figcaption{padding:8px}</style><h1>V1.5 Windows 실행본</h1><p>편집기 종료 후 복사한 EXE/PCK에서 캡처. 왼쪽 1280×720, 오른쪽 1920×1080. 같은 표시 크기이며 이미지를 누르면 원본을 엽니다.</p><p><a href="WINDOWS_EXPORT_V1_5.md">검증 보고서</a></p>')
foreach($view in @('domestic','officers','governor','production','build','research')){
    [void]$html.Append("<section><h2>$view</h2><div class='pair'>")
    foreach($height in @(720,1080)){
        $name="$view-$height.png"
        if(!(Test-Path -LiteralPath (Join-Path $Evidence $name))){throw "Missing capture $name"}
        [void]$html.Append("<figure><a href='$name'><img src='$name' alt='$view $height'></a><figcaption>${height}p</figcaption></figure>")
    }
    [void]$html.Append('</div></section>')
}
[void]$html.Append('</html>')
[IO.File]::WriteAllText((Join-Path $Evidence 'index.html'),$html.ToString(),$utf8)
