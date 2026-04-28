$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function GitLines {
    param([string[]]$GitArgs)
    $out = & git @GitArgs 2>&1
    if ($LASTEXITCODE -ne 0) { return @("GIT_FAILED git $($GitArgs -join ' ')") + @($out) }
    return @($out | ForEach-Object { [string]$_ })
}

function WorkstreamOf {
    param([string]$Path)
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

function ZipOpenLight {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return 'MISSING' }
    $z = $null
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        $z = [System.IO.Compression.ZipFile]::OpenRead($Path)
        return 'YES'
    } catch {
        return ('NO_' + $_.Exception.GetType().Name)
    } finally {
        if ($null -ne $z) { $z.Dispose() }
    }
}

$repoRoot = (& git rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($repoRoot)) { throw 'Not inside a Git repository.' }
$repoRoot = ([string]$repoRoot).Trim()
Set-Location -LiteralPath $repoRoot

$reportsDir = Join-Path $repoRoot 'reports/maintenance'
$tablesDir = Join-Path $repoRoot 'tables'
New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
New-Item -ItemType Directory -Path $tablesDir -Force | Out-Null

$rows = @()
foreach ($line in (GitLines @('status','--short'))) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $code = $line.Substring(0, [Math]::Min(2, $line.Length)).Trim()
    $path = if ($line.Length -gt 3) { $line.Substring(3).Trim().Trim('"') } else { '' }
    $state = 'OTHER'
    if ($code -eq '??') { $state = 'UNTRACKED' }
    elseif ($code -match 'M') { $state = 'MODIFIED' }
    elseif ($code -match 'A') { $state = 'ADDED' }
    elseif ($code -match 'D') { $state = 'DELETED' }
    $rows += [pscustomobject]@{ git_code=$code; path=$path; workstream=(WorkstreamOf $path); state_class=$state }
}

$csvPath = Join-Path $tablesDir 'maintenance_status_pack.csv'
$rows | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8

$branch = (GitLines @('branch','--show-current') | Select-Object -First 1)
$head = (GitLines @('log','--oneline','-1') | Select-Object -First 1)
$recent = GitLines @('log','--oneline','-5')

$summaryLines = @()
foreach ($g in ($rows | Group-Object workstream, state_class | Sort-Object Name)) {
    $parts = $g.Name -split ', '
    $summaryLines += "| $($parts[0]) | $($parts[1]) | $($g.Count) |"
}
if ($summaryLines.Count -eq 0) { $summaryLines = @('| clean | clean | 0 |') }

$changedLines = @()
foreach ($r in ($rows | Sort-Object workstream, path)) { $changedLines += "| $($r.git_code) | $($r.workstream) | $($r.path) |" }
if ($changedLines.Count -eq 0) { $changedLines = @('| clean | clean | clean |') }

$snapshotRoot = 'L:\My Drive\For agents\snapshot'
$snapshotSimple = Join-Path $snapshotRoot 'auto/snapshot_simple'
$snapshotProducts = @(
    'auto/snapshot_repo.zip',
    'auto/snapshot_simple/snapshot_control.zip',
    'auto/snapshot_simple/snapshot_core.zip',
    'auto/snapshot_simple/snapshot_cross.zip',
    'auto/snapshot_simple/snapshot_code.zip',
    'auto/snapshot_simple/snapshot_aging.zip',
    'auto/snapshot_simple/snapshot_switching.zip',
    'auto/snapshot_simple/snapshot_relaxation.zip',
    'auto/snapshot_simple/snapshot_mt.zip',
    'auto/snapshot_simple/snapshot_relaxation_canonical.zip',
    'auto/snapshot_simple/snapshot_relaxation_post_field_off_canonical.zip',
    'auto/snapshot_simple/snapshot_relaxation_post_field_off_RF3R_canonical.zip'
)
$snapshotLines = @()
foreach ($rel in $snapshotProducts) {
    $full = Join-Path $snapshotRoot ($rel -replace '^auto/','auto/')
    $exists = if (Test-Path -LiteralPath $full) { 'YES' } else { 'NO' }
    $snapshotLines += "| $rel | $exists | $(ZipOpenLight $full) |"
}

$mdPath = Join-Path $reportsDir 'status_pack_latest.md'
$md = @()
$md += '# Maintenance Status Pack'
$md += ''
$md += ('Generated: ' + (Get-Date).ToString('o'))
$md += ('Repo: ' + $repoRoot)
$md += ('Branch: ' + $branch)
$md += ('HEAD: ' + $head)
$md += ''
$md += '## Recent commits'
$md += '```text'
$md += $recent
$md += '```'
$md += ''
$md += '## Workstream summary'
$md += '| workstream | state_class | count |'
$md += '|---|---:|---:|'
$md += $summaryLines
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
$md += '## How to use'
$md += 'Paste this file into chat for repo-maintenance triage.'
$md | Set-Content -LiteralPath $mdPath -Encoding UTF8

Write-Output ('Wrote: ' + $mdPath)
Write-Output ('Wrote: ' + $csvPath)
