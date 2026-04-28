$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

<#
.SYNOPSIS
  Build a compact local maintenance status pack for ChatGPT / agent handoff.

.DESCRIPTION
  Read-only with respect to repo state. It does not git add, commit, push, delete,
  rebuild snapshots, or run MATLAB. It only reads local Git/filesystem state and
  writes two small repo-local artifacts:
    - reports/maintenance/status_pack_latest.md
    - tables/maintenance_status_pack.csv

  Intended usage from repo root:
    powershell -ExecutionPolicy Bypass -File scripts/maintenance_status_pack.ps1

  Then paste reports/maintenance/status_pack_latest.md into chat.
#>

function Invoke-GitLines {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Args
    )

    $output = & git @Args 2>&1
    if ($LASTEXITCODE -ne 0) {
        return @("GIT_COMMAND_FAILED: git $($Args -join ' ')", ($output | ForEach-Object { [string]$_ }))
    }
    return @($output | ForEach-Object { [string]$_ })
}

function Get-RepoRoot {
    $root = (& git rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($root)) {
        throw 'Not inside a Git repository.'
    }
    return ([string]$root).Trim()
}

function Get-WorkstreamFromPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $p = $Path -replace '\\','/'
    if ($p -match '^Aging/') { return 'aging' }
    if ($p -match '^Relaxation ver3/') { return 'relaxation' }
    if ($p -match '^Switching/') { return 'switching' }
    if ($p -match '^scripts/run_switching_|^scripts/materialize_switching_') { return 'switching' }
    if ($p -match '^scripts/build_rf3r2_|^tools/assemble_F6|^run_aging_F6') { return 'aging_relaxation_bridge' }
    if ($p -match '^reports/maintenance/|^tables/maintenance') { return 'maintenance' }
    if ($p -match '^docs/|^reports/') { return 'docs_reports' }
    if ($p -match '^scripts/') { return 'scripts_other' }
    return 'other'
}

function Get-StatusRows {
    $lines = Invoke-GitLines -Args @('status','--short')
    $rows = New-Object System.Collections.Generic.List[object]

    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line.StartsWith('GIT_COMMAND_FAILED:')) {
            $rows.Add([pscustomobject]@{
                git_code = '!!'
                path = $line
                workstream = 'git_error'
                state_class = 'ERROR'
            })
            continue
        }

        $code = $line.Substring(0, [Math]::Min(2, $line.Length)).Trim()
        $path = if ($line.Length -gt 3) { $line.Substring(3).Trim() } else { '' }
        $path = $path.Trim('"')
        $stateClass = switch -Regex ($code) {
            '^\?\?' { 'UNTRACKED' }
            '^M|M$' { 'MODIFIED' }
            '^A|A$' { 'ADDED' }
            '^D|D$' { 'DELETED' }
            default { 'OTHER' }
        }

        $rows.Add([pscustomobject]@{
            git_code = $code
            path = $path
            workstream = Get-WorkstreamFromPath -Path $path
            state_class = $stateClass
        })
    }

    return @($rows)
}

function Test-ZipOpenLightweight {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return 'MISSING' }
    $zipObj = $null
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        $zipObj = [System.IO.Compression.ZipFile]::OpenRead($Path)
        return 'YES'
    }
    catch {
        return 'NO: ' + $_.Exception.GetType().Name
    }
    finally {
        if ($null -ne $zipObj) { $zipObj.Dispose() }
    }
}

$repoRoot = Get-RepoRoot
Set-Location -LiteralPath $repoRoot

$reportsDir = Join-Path $repoRoot 'reports/maintenance'
$tablesDir = Join-Path $repoRoot 'tables'
New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
New-Item -ItemType Directory -Path $tablesDir -Force | Out-Null

$timestamp = (Get-Date).ToString('o')
$branch = (Invoke-GitLines -Args @('branch','--show-current') | Select-Object -First 1)
$head = (Invoke-GitLines -Args @('log','--oneline','-1') | Select-Object -First 1)
$recentLog = Invoke-GitLines -Args @('log','--oneline','-5')
$rows = Get-StatusRows

$statusCsvPath = Join-Path $tablesDir 'maintenance_status_pack.csv'
$rows | Export-Csv -LiteralPath $statusCsvPath -NoTypeInformation -Encoding UTF8

$summary = $rows | Group-Object workstream, state_class | Sort-Object Name
$workstreamSummaryLines = @()
foreach ($g in $summary) {
    $parts = $g.Name -split ', '
    $workstream = if ($parts.Count -ge 1) { $parts[0] } else { $g.Name }
    $state = if ($parts.Count -ge 2) { $parts[1] } else { '' }
    $workstreamSummaryLines += "| $workstream | $state | $($g.Count) |"
}
if ($workstreamSummaryLines.Count -eq 0) {
    $workstreamSummaryLines = @('| clean | clean | 0 |')
}

$changedLines = @()
foreach ($r in ($rows | Sort-Object workstream, path)) {
    $changedLines += "| $($r.git_code) | $($r.workstream) | $($r.path) |"
}
if ($changedLines.Count -eq 0) {
    $changedLines = @('| clean | clean | clean |')
}

$snapshotRoot = 'L:\My Drive\For agents\snapshot'
$snapshotSimple = Join-Path $snapshotRoot 'auto/snapshot_simple'
$snapshotRepo = Join-Path $snapshotRoot 'auto/snapshot_repo.zip'
$expectedSnapshotProducts = @(
    'snapshot_control.zip',
    'snapshot_core.zip',
    'snapshot_cross.zip',
    'snapshot_code.zip',
    'snapshot_aging.zip',
    'snapshot_switching.zip',
    'snapshot_relaxation.zip',
    'snapshot_mt.zip',
    'snapshot_relaxation_canonical.zip',
    'snapshot_relaxation_post_field_off_canonical.zip',
    'snapshot_relaxation_post_field_off_RF3R_canonical.zip'
)

$snapshotLines = @()
$snapshotLines += "| auto/snapshot_repo.zip | $(if (Test-Path -LiteralPath $snapshotRepo) { 'YES' } else { 'NO' }) | $(Test-ZipOpenLightweight -Path $snapshotRepo) |"
foreach ($product in $expectedSnapshotProducts) {
    $full = Join-Path $snapshotSimple $product
    $exists = if (Test-Path -LiteralPath $full) { 'YES' } else { 'NO' }
    $open = Test-ZipOpenLightweight -Path $full
    $snapshotLines += "| auto/snapshot_simple/$product | $exists | $open |"
}

$maintenancePointers = @(
    'reports/maintenance/governor_summary_latest.md',
    'reports/maintenance/status_pack_latest.md',
    'tables/maintenance_status_pack.csv'
)
$pointerLines = foreach ($p in $maintenancePointers) {
    $full = Join-Path $repoRoot $p
    $exists = if (Test-Path -LiteralPath $full) { 'YES' } else { 'NO' }
    "| $p | $exists |"
}

$mdPath = Join-Path $reportsDir 'status_pack_latest.md'
$md = @()
$md += '# Maintenance Status Pack'
$md += ''
$md += "Generated: $timestamp"
$md += "Repo: $repoRoot"
$md += "Branch: $branch"
$md += "HEAD: $head"
$md += ''
$md += '## Recent commits'
$md += '```text'
$md += $recentLog
$md += '```'
$md += ''
$md += '## Workstream summary'
$md += '| workstream | state_class | count |'
$md += '|---|---:|---:|'
$md += $workstreamSummaryLines
$md += ''
$md += '## Changed / untracked files'
$md += '| git | workstream | path |'
$md += '|---|---|---|'
$md += $changedLines
$md += ''
$md += '## Snapshot quick check'
$md += '| product | exists | lightweight_zip_open |'
$md += '|---|---:|---:|'
$md += $snapshotLines
$md += ''
$md += '## Maintenance pointers'
$md += '| path | exists |'
$md += '|---|---:|'
$md += $pointerLines
$md += ''
$md += '## How to use'
$md += 'Paste this whole file into chat when asking for repo-maintenance triage. It is designed to replace repeated manual `git status`, `git log`, and snapshot sanity snippets.'

$md | Set-Content -LiteralPath $mdPath -Encoding UTF8

Write-Output "Wrote: $mdPath"
Write-Output "Wrote: $statusCsvPath"
Write-Output 'Paste reports/maintenance/status_pack_latest.md into chat for triage.'
