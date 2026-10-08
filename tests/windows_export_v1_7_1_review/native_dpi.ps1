$ErrorActionPreference='Stop'
. ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path (Get-Location) 'tests/windows_dpi_v1_5_1_review/desktop.ps1'))))
Add-Type -AssemblyName System.Windows.Forms
$r=Join-Path (Get-Location) 'tests/windows_export_v1_7_1_review'
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
 Save-GameCapture "$r/dpi150-court.png"
 $live=Get-Content "$r/dpi-live.json" -Raw -Encoding UTF8 | ConvertFrom-Json
 $selected=@($live.controls.PSObject.Properties | Where-Object {$_.Name -ne $live.selected})[0]
 Click-Game $selected.Value.x $selected.Value.y
 $afterClick=Get-Content "$r/dpi-live.json" -Raw -Encoding UTF8 | ConvertFrom-Json
 Save-GameCapture "$r/dpi150-group.png"
 $m=Get-GameMetrics
 [DpiQA]::SetCursorPos(($m.ClientX+[int](0.47*$m.ClientWidth)),($m.ClientY+[int](0.6*$m.ClientHeight)))|Out-Null
 [DpiQA]::mouse_event(0x0800,0,0,-1200,[UIntPtr]::Zero)
 Start-Sleep -Milliseconds 900
 $afterScroll=Get-Content "$r/dpi-live.json" -Raw -Encoding UTF8 | ConvertFrom-Json
 Save-GameCapture "$r/dpi150-scroll.png"
 Key-Game 9
 Save-GameCapture "$r/dpi150-tab.png"
 Key-Game 27
 $afterEsc=Get-Content "$r/dpi-live.json" -Raw -Encoding UTF8 | ConvertFrom-Json
 [pscustomobject]@{Original=$original;ActualScale=(Read-WindowsScale);Monitor=[Windows.Forms.Screen]::PrimaryScreen.Bounds.ToString();Metrics=(Get-GameMetrics);NativeGroupClick=($afterClick.selected -eq $selected.Name);NativeScroll=($afterScroll.scroll -gt 0);EscRestoresInput=(!$afterEsc.court_visible -and !$afterEsc.busy);AfterClick=$afterClick;AfterScroll=$afterScroll;AfterEsc=$afterEsc}|ConvertTo-Json -Depth 8|Set-Content "$r/dpi-native-result.json" -Encoding UTF8
} finally {
 Set-WindowsScale ([int]($original -replace '[^0-9]',''))
 [pscustomobject]@{Original=$original;Restored=(Read-WindowsScale)}|ConvertTo-Json|Set-Content "$r/restored-display.json" -Encoding UTF8
 $settings=Get-DisplaySettings
 [DpiQA]::SetWindowPos([IntPtr]$settings.Current.NativeWindowHandle,[IntPtr](-2),0,0,0,0,3)|Out-Null
 $game=Get-Game
 [DpiQA]::SetWindowPos($game.MainWindowHandle,[IntPtr](-2),80,80,1296,759,0)|Out-Null
}
Get-Content "$r/dpi-native-result.json" -Encoding UTF8
