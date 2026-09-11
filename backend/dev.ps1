# Attendance backend helper — isolated from global PYTHONPATH (e.g. GSoC Django).
# Your system PYTHONPATH is never changed; only this shell session is adjusted.
#
# Usage:
#   .\dev.ps1 python manage.py migrate
#   .\dev.ps1 python seed.py
#   .\dev.ps1 python test_api.py
#
# First-time setup:
#   .\setup_venv.ps1

$env:PYTHONPATH = $null

$venvPython = Join-Path $PSScriptRoot ".venv\Scripts\python.exe"
if (-not (Test-Path $venvPython)) {
    $venvPython = Join-Path $PSScriptRoot "venv\Scripts\python.exe"
}
if (Test-Path $venvPython) {
    if ($args.Count -gt 0 -and $args[0] -eq "python") {
        $args = @($venvPython) + $args[1..($args.Count - 1)]
    }
}

if ($args.Count -eq 0) {
    Write-Host "Usage: .\dev.ps1 <command...>"
    Write-Host "Example: .\dev.ps1 python manage.py migrate"
    Write-Host "Setup:    .\setup_venv.ps1"
    exit 1
}

& @args
exit $LASTEXITCODE
