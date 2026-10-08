Add-Type -AssemblyName System.Drawing
$workspacePath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$referencePath = Join-Path $workspacePath 'dev/living_city_ui_v1_1_source/samhan660_living_city_ui_v1_1/reference'
foreach ($width in @(1280,1920)) {
    $height = [int]($width * 9 / 16)
    foreach ($screen in @('domestic','officer','personnel')) {
        $after = [Drawing.Image]::FromFile((Join-Path $PSScriptRoot "$screen-$width.png"))
        foreach ($mode in @('before-after','reference')) {
            $leftPath = Join-Path $PSScriptRoot "before-$screen-$width.png"
            if ($mode -eq 'reference') {
                $referenceName = if ($screen -eq 'personnel') {'approved_personnel.png'} else {'domestic_default.png'}
                $leftPath = Join-Path $referencePath $referenceName
            }
            $left = [Drawing.Image]::FromFile($leftPath)
            $canvas = [Drawing.Bitmap]::new(($width * 2),$height)
            $graphics = [Drawing.Graphics]::FromImage($canvas)
            $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.DrawImage($left,0,0,$width,$height)
            $graphics.DrawImage($after,$width,0,$width,$height)
            $canvas.Save((Join-Path $PSScriptRoot "$mode-$screen-$width.png"),[Drawing.Imaging.ImageFormat]::Png)
            $graphics.Dispose(); $canvas.Dispose(); $left.Dispose()
        }
        $after.Dispose()
    }
}
