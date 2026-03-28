# SAFE SNAPSHOT MODE
# - Read-only from repo
# - No writes into repo
# - Manual execution only

$env:MATLAB_FUNCTIONS_SNAPSHOT_MANUAL = "1"

# Run the internal snapshot implementation (guarded by the env var above).
& (Join-Path $PSScriptRoot 'run_snapshot.ps1') @args

