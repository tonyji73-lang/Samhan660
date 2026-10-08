$ErrorActionPreference='Stop'
. ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path (Get-Location) 'tests/windows_dpi_v1_5_1_review/desktop.ps1'))))
$r=Join-Path (Get-Location) 'tests/windows_export_v1_6_1_review'
Start-Process 'ms-settings:display'
Start-Sleep -Milliseconds 1500
Show-DisplaySettings
$original=Read-WindowsScale
try {
 Set-WindowsScale 150
 $s=Get-DisplaySettings
 [DpiQA]::SetWindowPos([IntPtr]$s.Current.NativeWindowHandle,[IntPtr](-2),0,0,0,0,3)|Out-Null
 $game=Get-Game
 [DpiQA]::SetWindowPos($game.MainWindowHandle,[IntPtr](-1),24,24,1625,960,0)|Out-Null
 Start-Sleep -Milliseconds 900
 Save-GameCapture "$r/dpi150-formation.png"
 Click-Game 0.725 0.125
 Save-GameCapture "$r/dpi150-training.png"
 $afterClick=Get-Content -Raw -Encoding UTF8 "$r/dpi-live.json" | ConvertFrom-Json
 Key-Game 9
 Save-GameCapture "$r/dpi150-tab.png"
 Key-Game 27
 Save-GameCapture "$r/dpi150-escape.png"
 $afterEsc=Get-Content -Raw -Encoding UTF8 "$r/dpi-live.json" | ConvertFrom-Json
 [pscustomobject]@{Original=$original;ActualScale='150%';Monitor='1920x1080';Metrics=(Get-GameMetrics);TrainingNativeClick=($afterClick.mode -eq 'training');EscClosedArmy=(!$afterEsc.army_visible);AfterClick=$afterClick;AfterEsc=$afterEsc}|ConvertTo-Json -Depth 6|Set-Content "$r/dpi-native-result.json" -Encoding UTF8
} finally {
 Set-WindowsScale ([int]($original -replace '[^0-9]',''))
 [pscustomobject]@{Original=$original;Restored=(Read-WindowsScale)}|ConvertTo-Json|Set-Content "$r/restored-display.json" -Encoding UTF8
 $settings=Get-DisplaySettings
 [DpiQA]::SetWindowPos([IntPtr]$settings.Current.NativeWindowHandle,[IntPtr](-2),0,0,0,0,3)|Out-Null
 $game=Get-Game
 [DpiQA]::SetWindowPos($game.MainWindowHandle,[IntPtr](-2),80,80,1296,759,0)|Out-Null
}
Get-Content "$r/dpi-native-result.json" -Encoding UTF8
