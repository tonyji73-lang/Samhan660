Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class DpiQA {
 [StructLayout(LayoutKind.Sequential)] public struct RECT {public int Left,Top,Right,Bottom;}
 [StructLayout(LayoutKind.Sequential)] public struct POINT {public int X,Y;}
 [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr value);
 [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr hwnd);
 [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr hwnd,out RECT rect);
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd,out RECT rect);
 [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr hwnd,ref POINT point);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hwnd,int command);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hwnd,IntPtr after,int x,int y,int cx,int cy,uint flags);
 [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")] public static extern void mouse_event(uint flags,uint x,uint y,int data,UIntPtr extra);
 [DllImport("user32.dll")] public static extern void keybd_event(byte key,byte scan,uint flags,UIntPtr extra);
}
'@
[DpiQA]::SetThreadDpiAwarenessContext([IntPtr](-4)) | Out-Null
function Get-Game {
 $game=Get-Process Samhan660 -ErrorAction Stop | Where-Object MainWindowHandle -ne 0 | Select-Object -Last 1
 if(!$game){throw 'Game window missing'}
 return $game
}
function Get-GameMetrics {
 $game=Get-Game; $client=New-Object DpiQA+RECT; $window=New-Object DpiQA+RECT; $origin=New-Object DpiQA+POINT
 [DpiQA]::GetClientRect($game.MainWindowHandle,[ref]$client) | Out-Null
 [DpiQA]::GetWindowRect($game.MainWindowHandle,[ref]$window) | Out-Null
 [DpiQA]::ClientToScreen($game.MainWindowHandle,[ref]$origin) | Out-Null
 return [pscustomobject]@{Pid=$game.Id;Dpi=[DpiQA]::GetDpiForWindow($game.MainWindowHandle);ClientWidth=$client.Right;ClientHeight=$client.Bottom;ClientX=$origin.X;ClientY=$origin.Y;OuterWidth=$window.Right-$window.Left;OuterHeight=$window.Bottom-$window.Top}
}
function Save-GameCapture([string]$Path) {
 $game=Get-Game
 [DpiQA]::ShowWindow($game.MainWindowHandle,9)|Out-Null
 [DpiQA]::SetWindowPos($game.MainWindowHandle,[IntPtr](-1),0,0,0,0,3)|Out-Null
 Start-Sleep -Milliseconds 400
 $m=Get-GameMetrics; $image=New-Object Drawing.Bitmap($m.ClientWidth,$m.ClientHeight); $g=[Drawing.Graphics]::FromImage($image)
 try {$g.CopyFromScreen($m.ClientX,$m.ClientY,0,0,$image.Size);$image.Save($Path,[Drawing.Imaging.ImageFormat]::Png)}finally{$g.Dispose();$image.Dispose()}
 $m | ConvertTo-Json | Set-Content ($Path+'.json') -Encoding UTF8
}
function Click-Game([double]$X,[double]$Y) {
 $game=Get-Game;[DpiQA]::SetForegroundWindow($game.MainWindowHandle)|Out-Null
 [DpiQA]::ShowWindow($game.MainWindowHandle,9)|Out-Null
 [DpiQA]::SetWindowPos($game.MainWindowHandle,[IntPtr](-1),0,0,0,0,3)|Out-Null
 $m=Get-GameMetrics;[DpiQA]::SetCursorPos(($m.ClientX+[int]($X*$m.ClientWidth)),($m.ClientY+[int]($Y*$m.ClientHeight)))|Out-Null
 Start-Sleep -Milliseconds 120; [DpiQA]::mouse_event(2,0,0,0,[UIntPtr]::Zero); Start-Sleep -Milliseconds 80; [DpiQA]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
 Start-Sleep -Milliseconds 650
}
function Key-Game([byte]$Code) {
 [DpiQA]::keybd_event($Code,0,0,[UIntPtr]::Zero); Start-Sleep -Milliseconds 80; [DpiQA]::keybd_event($Code,0,2,[UIntPtr]::Zero)
 Start-Sleep -Milliseconds 500
}
function Get-DisplaySettings {
 $cond=New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ClassNameProperty,'ApplicationFrameWindow')
 $windows=[Windows.Automation.AutomationElement]::RootElement.FindAll([Windows.Automation.TreeScope]::Children,$cond)
 $settings=$windows | Where-Object {$_.Current.Name -in @('설정','Settings')} | Select-Object -First 1
 if(!$settings){throw 'Display settings window missing'}
 return $settings
}
function Get-ScaleCombo {
 $cond=New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::AutomationIdProperty,'SystemSettings_Display_Scaling_ItemSizeOverride_ComboBox')
 return (Get-DisplaySettings).FindFirst([Windows.Automation.TreeScope]::Descendants,$cond)
}
function Show-DisplaySettings {
 $s=Get-DisplaySettings; $handle=[IntPtr]$s.Current.NativeWindowHandle
 [DpiQA]::ShowWindow($handle,9)|Out-Null
 [DpiQA]::SetWindowPos($handle,[IntPtr](-1),0,0,0,0,3)|Out-Null
 [DpiQA]::SetForegroundWindow($handle)|Out-Null
 Start-Sleep -Milliseconds 700
}
function Read-WindowsScale {
 $combo=Get-ScaleCombo
 $selection=$combo.GetCurrentPattern([Windows.Automation.SelectionPattern]::Pattern)
 return ($selection.Current.GetSelection() | ForEach-Object {$_.Current.Name})
}
function Set-WindowsScale([int]$Percent) {
 if($Percent -notin @(100,125,150)){throw 'Unexpected scale'}
 Show-DisplaySettings
 $combo=Get-ScaleCombo
 $expand=$combo.GetCurrentPattern([Windows.Automation.ExpandCollapsePattern]::Pattern);$expand.Expand()
 Start-Sleep -Milliseconds 350
 $items=(Get-DisplaySettings).FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.Condition]::TrueCondition)
 $item=$items | Where-Object {$_.Current.ControlType -eq [Windows.Automation.ControlType]::ListItem -and $_.Current.Name -match "^$Percent%"} | Select-Object -Last 1
 if(!$item){throw "Scale option $Percent missing"}
 $select=$item.GetCurrentPattern([Windows.Automation.SelectionItemPattern]::Pattern);$select.Select()
 Start-Sleep -Seconds 2
 $actual=Read-WindowsScale
 if($actual -notmatch "^$Percent%") {throw "Scale not applied: $actual"}
 Write-Output $actual
}
