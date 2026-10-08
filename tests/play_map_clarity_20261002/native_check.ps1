param([string]$Action='capture',[string]$Label='release',[int]$X=0,[int]$Y=0,[int]$Count=1)
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public class PlayMapWindow {
 [StructLayout(LayoutKind.Sequential)]public struct R{public int L,T,X,Y;}
 [DllImport("user32.dll")]public static extern bool GetWindowRect(IntPtr h,out R r);
 [DllImport("user32.dll")]public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")]public static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")]public static extern void mouse_event(uint flags,uint dx,uint dy,uint data,UIntPtr extra);
 [DllImport("user32.dll")]public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")]public static extern bool PrintWindow(IntPtr h,IntPtr dc,uint f);
 [DllImport("user32.dll")]public static extern bool PostMessage(IntPtr h,uint m,IntPtr w,IntPtr l);
}
"@
$procId=[int](Get-Content (Join-Path $PSScriptRoot 'release_pid.txt'))
$proc=Get-Process -Id $procId
$info=Get-Content (Join-Path $PSScriptRoot 'windows_build.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if($proc.Path -ne $info.exe){throw 'Unexpected process'}
$h=$proc.MainWindowHandle
[PlayMapWindow]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Seconds 2
if($Action -eq 'click'){
 for($i=0;$i -lt $Count;$i++){
  $xy=[IntPtr](($Y -shl 16) -bor $X)
  [PlayMapWindow]::PostMessage($h,0x200,[IntPtr]0,$xy) | Out-Null
  [PlayMapWindow]::PostMessage($h,0x201,[IntPtr]1,$xy) | Out-Null
  [PlayMapWindow]::PostMessage($h,0x202,[IntPtr]0,$xy) | Out-Null
  Start-Sleep -Milliseconds 300
 }
 Start-Sleep -Seconds 2
}
if($Action -eq 'drag'){
 $xy=[IntPtr](($Y -shl 16) -bor $X)
 [PlayMapWindow]::PostMessage($h,0x200,[IntPtr]0,$xy) | Out-Null
 [PlayMapWindow]::PostMessage($h,0x201,[IntPtr]1,$xy) | Out-Null
 for($i=1;$i -le 10;$i++){
  $xx=$X+28*$i; $yy=$Y+19*$i
  $xy=[IntPtr](($yy -shl 16) -bor $xx)
  [PlayMapWindow]::PostMessage($h,0x200,[IntPtr]1,$xy) | Out-Null
  Start-Sleep -Milliseconds 50
 }
 [PlayMapWindow]::PostMessage($h,0x202,[IntPtr]0,$xy) | Out-Null
 Start-Sleep -Seconds 2
}
if($Action -eq 'native_drag'){
 if([PlayMapWindow]::GetForegroundWindow() -ne $h){throw 'Game not foreground'}
 $wr=New-Object PlayMapWindow+R
 [PlayMapWindow]::GetWindowRect($h,[ref]$wr) | Out-Null
 $sx=$wr.L+8+$X; $sy=$wr.T+31+$Y
 [PlayMapWindow]::SetCursorPos($sx,$sy) | Out-Null
 Start-Sleep -Milliseconds 200
 [PlayMapWindow]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
 try {
  for($i=1;$i -le 20;$i++){
   [PlayMapWindow]::SetCursorPos(($sx+14*$i),($sy+[int](9.5*$i))) | Out-Null
   Start-Sleep -Milliseconds 50
  }
 }finally{[PlayMapWindow]::mouse_event(4,0,0,0,[UIntPtr]::Zero)}
 Start-Sleep -Seconds 2
}
$r=New-Object PlayMapWindow+R
[PlayMapWindow]::GetWindowRect($h,[ref]$r) | Out-Null
$b=New-Object Drawing.Bitmap(($r.X-$r.L),($r.Y-$r.T))
$g=[Drawing.Graphics]::FromImage($b)
$dc=$g.GetHdc()
$ok=[PlayMapWindow]::PrintWindow($h,$dc,2)
$g.ReleaseHdc($dc)
$b.Save((Join-Path $PSScriptRoot ($Label+'.png')),[Drawing.Imaging.ImageFormat]::Png)
$g.Dispose();$b.Dispose()
[pscustomobject]@{pid=$procId;title=$proc.MainWindowTitle;responding=$proc.Responding;capture=$ok;size=($r.X-$r.L).ToString()+'x'+($r.Y-$r.T)}