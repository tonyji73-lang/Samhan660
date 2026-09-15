param([Parameter(Mandatory = $true)][string]$Godot)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$godotPath = (Resolve-Path -LiteralPath $Godot).Path
foreach ($arguments in @(
    '--headless --editor --path . --quit --log-file .godot/gut-import.log',
    '--headless --path . --script addons/gut/gut_cmdln.gd -gdir=res://addons/lowpolyterrain/tests -gexit --log-file .godot/lowpoly-gut.log'
)) {
    $run = Start-Process -FilePath $godotPath -WorkingDirectory $projectRoot -ArgumentList $arguments -WindowStyle Hidden -PassThru -Wait
    if ($run.ExitCode -ne 0) { throw "Godot exited with code $($run.ExitCode). See .godot/gut-import.log and .godot/lowpoly-gut.log." }
}
Get-Content -LiteralPath (Join-Path $projectRoot '.godot/lowpoly-gut.log') -Encoding UTF8 -Tail 18
