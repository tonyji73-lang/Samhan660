param([Parameter(Mandatory=$true)][string]$Output)
$ErrorActionPreference='Stop'
. ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path (Get-Location) 'tests/windows_dpi_v1_5_1_review/desktop.ps1'))))
Add-Type -AssemblyName System.Windows.Forms
Start-Process 'ms-settings:display'
Start-Sleep -Milliseconds 1500
Show-DisplaySettings
$original=Read-WindowsScale
$results=@()
try {
 foreach($scale in @(125,150)){
  Set-WindowsScale $scale
  $s=Get-DisplaySettings
  [DpiQA]::SetWindowPos([IntPtr]$s.Current.NativeWindowHandle,[IntPtr](-2),0,0,0,0,3)|Out-Null
  $game=Get-Game
  [DpiQA]::ShowWindow($game.MainWindowHandle,9)|Out-Null
  [DpiQA]::SetWindowPos($game.MainWindowHandle,[IntPtr](-1),24,24,1625,960,0)|Out-Null
  Start-Sleep -Milliseconds 900
  $live=Get-Content (Join-Path $Output 'dpi-live.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  if(!$live.report){Click-Game 0.7656 0.9426}
  Save-GameCapture (Join-Path $Output ('dpi'+$scale+'-report.png'))
  $m=Get-GameMetrics
  [DpiQA]::SetCursorPos(($m.ClientX+[int](0.55*$m.ClientWidth)),($m.ClientY+[int](0.7*$m.ClientHeight)))|Out-Null
  [DpiQA]::mouse_event(0x0800,0,0,-1200,[UIntPtr]::Zero)
  Start-Sleep -Milliseconds 700
  $scrolled=Get-Content (Join-Path $Output 'dpi-live.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  Save-GameCapture (Join-Path $Output ('dpi'+$scale+'-scroll.png'))
  $live=Get-Content (Join-Path $Output 'dpi-live.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  # Coordinates read from the native report screenshot, not Godot canvas coordinates.
  Click-Game 0.395 0.214
  $clicked=Get-Content (Join-Path $Output 'dpi-live.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  Save-GameCapture (Join-Path $Output ('dpi'+$scale+'-production.png'))
  # Native keys are sent only after verifying that the game owns foreground focus.
  if([DpiQA]::GetForegroundWindow() -ne $game.MainWindowHandle){throw 'Game foreground required for native keyboard input.'}
  Key-Game 9
  if([DpiQA]::GetForegroundWindow() -ne $game.MainWindowHandle){throw 'Game lost foreground before Esc.'}
  Key-Game 27
  $closed=Get-Content (Join-Path $Output 'dpi-live.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  $results+=[pscustomobject]@{Requested=$scale;ActualScale=(Read-WindowsScale);Monitor=[Windows.Forms.Screen]::PrimaryScreen.Bounds.ToString();Metrics=$m;ReportWasVisible=$live.report;NativeScroll=($scrolled.scroll -gt 0);NativeProductionClick=$clicked.production;EscRestoresInput=(!$closed.report -and !$closed.production -and !$closed.busy);FocusAfterTab=$closed.focus}
  $results|ConvertTo-Json -Depth 8|Set-Content (Join-Path $Output 'dpi-native-result.json') -Encoding UTF8
 }
} finally {
 Set-WindowsScale ([int]($original -replace '[^0-9]',''))
 [pscustomobject]@{Original=$original;Restored=(Read-WindowsScale)}|ConvertTo-Json|Set-Content (Join-Path $Output 'restored-display.json') -Encoding UTF8
 $settings=Get-DisplaySettings
 [DpiQA]::SetWindowPos([IntPtr]$settings.Current.NativeWindowHandle,[IntPtr](-2),0,0,0,0,3)|Out-Null
 $game=Get-Game
 [DpiQA]::SetWindowPos($game.MainWindowHandle,[IntPtr](-2),80,80,1296,759,0)|Out-Null
}
