param(
    [Parameter(Mandatory = $true)][string]$Godot,
    [switch]$WithGraphics
)
$ErrorActionPreference = 'Continue'
$projectRoot = Split-Path $PSScriptRoot -Parent
$results = Join-Path $projectRoot '.godot/foundation-results/reproduction'
New-Item -ItemType Directory -Path $results -Force -ErrorAction Stop | Out-Null
$failed = @()
$cases = @('production', 'geumgwan_ownership', 'diplomacy', 'cutscene', 'bountiful_harvest', 'crop_failure')
foreach ($case in $cases) {
    $logPath = Join-Path $results "$case.log"
    & $Godot --headless --path $projectRoot --script "res://tests/${case}_test.gd" --log-file $logPath
    if ($LASTEXITCODE -ne 0) { $failed += $case }
}
# iron_supply_test and iron_pilot_test are RefCounted helpers invoked by
# production_test. They cannot be launched as standalone SceneTree scripts.
if ($WithGraphics) {
    & $Godot --path $projectRoot --script res://tests/project_foundation_test.gd --log-file (Join-Path $results 'foundation-gui.log')
    if ($LASTEXITCODE -ne 0) { $failed += 'foundation-gui' }
}
if ($failed.Count -gt 0) { throw "Failed suites: $($failed -join ', ')" }
Write-Output "Completed requested suites. Logs: $results"
