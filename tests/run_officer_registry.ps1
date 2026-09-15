param(
    [Parameter(Mandatory = $true)][string]$Godot,
    [switch]$WithGraphics
)
$ErrorActionPreference = 'Continue'
$projectRoot = Split-Path $PSScriptRoot -Parent
$results = Join-Path $projectRoot '.godot/officer-results/reproduction'
New-Item -ItemType Directory -Path $results -Force -ErrorAction Stop | Out-Null
$failed = @()
$cases = @('production', 'geumgwan_ownership', 'diplomacy', 'cutscene', 'bountiful_harvest', 'crop_failure', 'officer_registry')
foreach ($case in $cases) {
    $log = Join-Path $results "$case.log"
    & $Godot --headless --path $projectRoot --script "res://tests/${case}_test.gd" --log-file $log
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR|FAIL:|TIMEOUT' -Quiet)) { $failed += $case }
}
if ($WithGraphics) {
    foreach ($case in @('project_foundation', 'officer_registry_gui')) {
        $log = Join-Path $results "$case.log"
        & $Godot --path $projectRoot --script "res://tests/${case}_test.gd" --log-file $log
        if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR|FAIL:|TIMEOUT' -Quiet)) { $failed += $case }
    }
}
if ($failed.Count -gt 0) { throw "Failed suites: $($failed -join ', ')" }
Write-Output "Completed requested officer suites. Logs: $results"
