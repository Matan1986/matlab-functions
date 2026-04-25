<#
.SYNOPSIS
  Detection-only: verify expected maintenance artifacts exist and CSV schemas match contracts.

.DESCRIPTION
  Scans reports/maintenance/agent_outputs/<Date>/, local/Governor outputs, and daily log.
  Writes tables/maintenance_publication_health_latest.csv and
  reports/maintenance/maintenance_health_latest.md. Exits 0 (advisory); does not mutate inputs.
#>
[CmdletBinding()]
param(
    [string]$Date = (Get-Date -Format "yyyy_MM_dd")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$agentOutDir = Join-Path $repoRoot ("reports\maintenance\agent_outputs\{0}" -f $Date)
$dailyLogPath = Join-Path $repoRoot ("reports\maintenance\logs\daily_maintenance_{0}.log" -f $Date)
$tableOut = Join-Path $repoRoot "tables\maintenance_publication_health_latest.csv"
$reportOut = Join-Path $repoRoot "reports\maintenance\maintenance_health_latest.md"

$expectedAgents = @(
    "repository_drift_guard",
    "run_output_audit",
    "switching_canonical_boundary_guard",
    "helper_duplication_guard",
    "canonicalization_progress_guard"
)

$normalizedFindingsHeaders = @(
    "finding_key", "theme", "rule_id", "producer_agent", "module", "module_state", "scope",
    "severity", "confidence", "title", "description", "evidence_ref", "status_proposal",
    "human_approval_required", "observed_at_utc"
)

$simplifiedRunAuditHeaders = @("finding_id", "module", "severity", "description")
$governorLatestMinHeaders = @("finding_id", "module", "severity", "description", "source_file")
$snapshotCoverageExactHeaders = @(
    "run_id", "module", "snapshot_has_entry", "snapshot_linkage_present", "coverage_status", "notes"
)

function Get-CsvHeaderFieldsOrdered {
    param([string]$LiteralPath)
    if (-not (Test-Path -LiteralPath $LiteralPath)) { return @() }
    $first = [System.IO.File]::ReadAllLines($LiteralPath, [System.Text.Encoding]::UTF8)[0]
    if ([string]::IsNullOrWhiteSpace($first)) { return @() }
    $m = [regex]::Matches($first, '"((?:[^"]|"")*)"')
    if ($m.Count -gt 0) {
        return @($m | ForEach-Object { $_.Groups[1].Value -replace '""', '"' })
    }
    return @($first.Split(','))
}

function Test-HeadersContainAll {
    param([string[]]$Actual, [string[]]$Required)
    foreach ($h in $Required) {
        if ($Actual -notcontains $h) { return $false }
    }
    return $true
}

function Test-HeadersExactOrder {
    param([string[]]$Actual, [string[]]$Required)
    if ($Actual.Count -ne $Required.Count) { return $false }
    for ($i = 0; $i -lt $Required.Count; $i++) {
        if ($Actual[$i] -ne $Required[$i]) { return $false }
    }
    return $true
}

function Get-CsvSchemaStatus {
    param(
        [string]$LiteralPath,
        [ValidateSet("NormalizedFindings", "SimplifiedRunAudit", "GovernorLatest", "SnapshotCoverage")]
        [string]$Kind
    )
    if (-not (Test-Path -LiteralPath $LiteralPath)) {
        return "MISSING"
    }
    $hdrs = @(Get-CsvHeaderFieldsOrdered -LiteralPath $LiteralPath)
    if ($hdrs.Count -eq 0) {
        return "BAD_SCHEMA"
    }
    switch ($Kind) {
        "NormalizedFindings" {
            if (Test-HeadersContainAll -Actual $hdrs -Required $normalizedFindingsHeaders) { return "PRESENT" }
            return "BAD_SCHEMA"
        }
        "SimplifiedRunAudit" {
            if (Test-HeadersExactOrder -Actual $hdrs -Required $simplifiedRunAuditHeaders) { return "PRESENT" }
            return "BAD_SCHEMA"
        }
        "GovernorLatest" {
            if (Test-HeadersContainAll -Actual $hdrs -Required $governorLatestMinHeaders) { return "PRESENT" }
            return "BAD_SCHEMA"
        }
        "SnapshotCoverage" {
            if (Test-HeadersExactOrder -Actual $hdrs -Required $snapshotCoverageExactHeaders) { return "PRESENT" }
            return "BAD_SCHEMA"
        }
    }
    return "UNKNOWN"
}

function New-HealthRow {
    param(
        [string]$Producer,
        [string]$ArtifactType,
        [string]$Path,
        [string]$Status,
        [string]$AlertLevel,
        [string]$Notes
    )
    return [pscustomobject][ordered]@{
        date = $Date
        producer = $Producer
        artifact_type = $ArtifactType
        path = $Path
        status = $Status
        alert_level = $AlertLevel
        notes = $Notes
    }
}

$rows = New-Object System.Collections.Generic.List[object]

foreach ($agent in $expectedAgents) {
    $findingsPath = Join-Path $agentOutDir ("{0}_findings.csv" -f $agent)
    $reportPath = Join-Path $agentOutDir ("{0}_report.md" -f $agent)

    $findingsExists = Test-Path -LiteralPath $findingsPath
    $reportExists = Test-Path -LiteralPath $reportPath

    # run_output_audit_findings.csv is the simplified Governor CSV only; validated below (not normalized).
    if ($agent -ne "run_output_audit") {
        if (-not $findingsExists) {
            $findAlert = if (-not $reportExists) { "ACTION" } else { "WATCH" }
            $findNotes = if (-not $reportExists) {
                "Expected agent findings CSV not found (report also missing)."
            } else {
                "Findings CSV missing; report present (partial publication)."
            }
            [void]$rows.Add((New-HealthRow -Producer $agent -ArtifactType "normalized_findings_csv" -Path $findingsPath `
                -Status "MISSING" -AlertLevel $findAlert -Notes $findNotes))
        } else {
            $schema = Get-CsvSchemaStatus -LiteralPath $findingsPath -Kind "NormalizedFindings"
            $al = if ($schema -eq "PRESENT") { "OK" } elseif ($schema -eq "BAD_SCHEMA") { "ACTION" } else { "ACTION" }
            [void]$rows.Add((New-HealthRow -Producer $agent -ArtifactType "normalized_findings_csv" -Path $findingsPath `
                -Status $schema -AlertLevel $al -Notes "Normalized findings schema (finding_key and required columns)."))
        }
    }

    if (-not $reportExists) {
        $repAlert = if (-not $findingsExists) { "ACTION" } else { "WATCH" }
        $repNotes = if (-not $findingsExists) {
            "Expected agent report markdown not found (findings also missing)."
        } else {
            "Report missing; findings file present (partial publication)."
        }
        [void]$rows.Add((New-HealthRow -Producer $agent -ArtifactType "agent_report_md" -Path $reportPath `
            -Status "MISSING" -AlertLevel $repAlert -Notes $repNotes))
    } else {
        [void]$rows.Add((New-HealthRow -Producer $agent -ArtifactType "agent_report_md" -Path $reportPath `
            -Status "PRESENT" -AlertLevel "OK" -Notes "Report file exists."))
    }
}

$runAuditSimplifiedPath = Join-Path $agentOutDir "run_output_audit_findings.csv"
$simplifiedExists = Test-Path -LiteralPath $runAuditSimplifiedPath
if (-not $simplifiedExists) {
    [void]$rows.Add((New-HealthRow -Producer "run_output_audit" -ArtifactType "simplified_findings_csv" `
        -Path $runAuditSimplifiedPath -Status "MISSING" -AlertLevel "ACTION" `
        -Notes "Governor-compatible simplified Run Output Audit CSV missing."))
} else {
    $simpSchema = Get-CsvSchemaStatus -LiteralPath $runAuditSimplifiedPath -Kind "SimplifiedRunAudit"
    $simpAlert = if ($simpSchema -eq "PRESENT") { "OK" } else { "ACTION" }
    [void]$rows.Add((New-HealthRow -Producer "run_output_audit" -ArtifactType "simplified_findings_csv" `
        -Path $runAuditSimplifiedPath -Status $simpSchema -AlertLevel $simpAlert `
        -Notes "Requires exact columns: finding_id,module,severity,description."))
}

$localArtifacts = @(
    @{ Key = "daily_log"; Producer = "local_daily_maintenance"; Type = "daily_log"; Path = $dailyLogPath; CsvKind = $null }
    @{ Key = "gov_csv"; Producer = "governor_minimal"; Type = "governor_latest_csv"; Path = (Join-Path $repoRoot "tables\maintenance_findings_latest.csv"); CsvKind = "GovernorLatest" }
    @{ Key = "gov_md"; Producer = "governor_minimal"; Type = "governor_summary_md"; Path = (Join-Path $repoRoot "reports\maintenance\governor_summary_latest.md"); CsvKind = $null }
    @{ Key = "snap_csv"; Producer = "guard_run_snapshot_coverage"; Type = "snapshot_coverage_csv"; Path = (Join-Path $repoRoot "tables\run_snapshot_coverage_latest.csv"); CsvKind = "SnapshotCoverage" }
    @{ Key = "snap_md"; Producer = "guard_run_snapshot_coverage"; Type = "snapshot_coverage_md"; Path = (Join-Path $repoRoot "reports\maintenance\run_snapshot_coverage_latest.md"); CsvKind = $null }
)

$otherLocalPresent = $false
foreach ($la in $localArtifacts) {
    if ($la.Key -ne "daily_log" -and (Test-Path -LiteralPath $la.Path)) {
        $otherLocalPresent = $true
    }
}

foreach ($la in $localArtifacts) {
    $p = $la.Path
    $exists = Test-Path -LiteralPath $p
    if ($la.Key -eq "daily_log") {
        if (-not $exists) {
            $al = if ($otherLocalPresent) { "WATCH" } else { "ACTION" }
            [void]$rows.Add((New-HealthRow -Producer $la.Producer -ArtifactType $la.Type -Path $p -Status "MISSING" `
                -AlertLevel $al -Notes "Daily maintenance log not found."))
            continue
        }
        $raw = Get-Content -LiteralPath $p -Raw -ErrorAction SilentlyContinue
        if ([string]::IsNullOrWhiteSpace($raw)) {
            [void]$rows.Add((New-HealthRow -Producer $la.Producer -ArtifactType $la.Type -Path $p -Status "MISSING" `
                -AlertLevel "ACTION" -Notes "Daily log empty or unreadable."))
            continue
        }
        $hasFinal = $raw -match "FINAL_VERDICT=OK"
        $hasThree = ($raw -match "run_run_output_audit_local OK") -and ($raw -match "run_governor_minimal OK") -and ($raw -match "guard_run_snapshot_coverage OK")
        $hasFour = $hasThree -and ($raw -match "guard_maintenance_publication_health OK")
        if ($hasFinal) {
            [void]$rows.Add((New-HealthRow -Producer $la.Producer -ArtifactType $la.Type -Path $p -Status "PRESENT" `
                -AlertLevel "OK" -Notes "Log contains FINAL_VERDICT=OK."))
        } elseif ($hasFour) {
            [void]$rows.Add((New-HealthRow -Producer $la.Producer -ArtifactType $la.Type -Path $p -Status "PRESENT" `
                -AlertLevel "OK" -Notes "Log shows all four pipeline steps OK including publication health."))
        } elseif ($hasThree) {
            [void]$rows.Add((New-HealthRow -Producer $la.Producer -ArtifactType $la.Type -Path $p -Status "PRESENT" `
                -AlertLevel "WATCH" -Notes "FINAL_VERDICT=OK not found yet; producer steps through snapshot guard succeeded (typical mid-run)."))
        } else {
            [void]$rows.Add((New-HealthRow -Producer $la.Producer -ArtifactType $la.Type -Path $p -Status "PRESENT" `
                -AlertLevel "ACTION" -Notes "Log exists but lacks FINAL_VERDICT=OK and expected step OK markers."))
        }
        continue
    }

    if (-not $exists) {
        [void]$rows.Add((New-HealthRow -Producer $la.Producer -ArtifactType $la.Type -Path $p -Status "MISSING" `
            -AlertLevel "ACTION" -Notes "Required local maintenance artifact missing."))
        continue
    }

    if ($null -ne $la.CsvKind) {
        $st = Get-CsvSchemaStatus -LiteralPath $p -Kind $la.CsvKind
        $al = if ($st -eq "PRESENT") { "OK" } elseif ($st -eq "BAD_SCHEMA") { "ACTION" } else { "ACTION" }
        [void]$rows.Add((New-HealthRow -Producer $la.Producer -ArtifactType $la.Type -Path $p -Status $st -AlertLevel $al `
            -Notes "CSV schema validation for this artifact type."))
    } else {
        [void]$rows.Add((New-HealthRow -Producer $la.Producer -ArtifactType $la.Type -Path $p -Status "PRESENT" -AlertLevel "OK" `
            -Notes "Markdown artifact exists."))
    }
}

$maxAlertRank = @{ OK = 0; WATCH = 1; ACTION = 2 }
$overallRank = 0
foreach ($r in $rows) {
    $rk = $maxAlertRank[$r.alert_level]
    if ($null -eq $rk) { $rk = 2 }
    if ($rk -gt $overallRank) { $overallRank = $rk }
}
$alertLevelOverall = "OK"
if ($overallRank -eq 2) { $alertLevelOverall = "ACTION" }
elseif ($overallRank -eq 1) { $alertLevelOverall = "WATCH" }

$missingList = @($rows | Where-Object { $_.status -eq "MISSING" } | ForEach-Object { "- ``$($_.path)`` ($($_.producer))" })
$schemaList = @($rows | Where-Object { $_.status -eq "BAD_SCHEMA" } | ForEach-Object { "- ``$($_.path)`` ($($_.artifact_type))" })

$agentFindingsRows = @($rows | Where-Object { $_.artifact_type -eq "normalized_findings_csv" })
$agentReportRows = @($rows | Where-Object { $_.artifact_type -eq "agent_report_md" })

# ALL_EXPECTED_AGENTS_PUBLISHED: normalized findings + report per agent; run_output_audit uses simplified CSV + report
$allAgentsPublished = $true
$simplifiedRow = $rows | Where-Object { $_.artifact_type -eq "simplified_findings_csv" } | Select-Object -First 1
foreach ($agent in $expectedAgents) {
    $rr = $agentReportRows | Where-Object { $_.producer -eq $agent } | Select-Object -First 1
    if ($agent -eq "run_output_audit") {
        $fr = $simplifiedRow
    } else {
        $fr = $agentFindingsRows | Where-Object { $_.producer -eq $agent } | Select-Object -First 1
    }
    if ((-not $fr) -or $fr.status -eq "MISSING" -or $fr.status -eq "BAD_SCHEMA") {
        $allAgentsPublished = $false
    }
    if ((-not $rr) -or $rr.status -eq "MISSING") {
        $allAgentsPublished = $false
    }
}

$localRows = @($rows | Where-Object { $_.producer -in @("local_daily_maintenance", "governor_minimal", "guard_run_snapshot_coverage") })
$localDailyOutputsOk = $true
foreach ($lr in $localRows) {
    if ($lr.status -eq "MISSING" -or $lr.status -eq "BAD_SCHEMA") {
        $localDailyOutputsOk = $false
    }
    if ($lr.artifact_type -eq "daily_log" -and $lr.alert_level -eq "ACTION") {
        $localDailyOutputsOk = $false
    }
}

$schemaOk = -not @($rows | Where-Object { $_.status -eq "BAD_SCHEMA" }).Count

$fence3 = [string]::new([char]96, 3)
$verdictBlock = @(
    ($fence3 + "text"),
    "MAINTENANCE_HEALTH_GUARD_COMPLETED = YES",
    ("LOCAL_DAILY_OUTPUTS_OK = {0}" -f ($(if ($localDailyOutputsOk) { "YES" } else { "NO" }))),
    ("ALL_EXPECTED_AGENTS_PUBLISHED = {0}" -f ($(if ($allAgentsPublished) { "YES" } else { "NO" }))),
    ("SCHEMA_CHECKS_OK = {0}" -f ($(if ($schemaOk) { "YES" } else { "NO" }))),
    ("ALERT_LEVEL = {0}" -f $alertLevelOverall),
    $fence3
) -join [Environment]::NewLine

$missingBlock = if ($missingList.Count -eq 0) { "(none)" } else { $missingList -join [Environment]::NewLine }
$schemaBlock = if ($schemaList.Count -eq 0) { "(none)" } else { $schemaList -join [Environment]::NewLine }

$md = @"
# Maintenance Publication Health

## Summary

- Date token: **$Date**
- Agent output directory: ``$agentOutDir``
- Overall **ALERT_LEVEL**: **$alertLevelOverall**
- Rows evaluated: **$($rows.Count)**

## Missing Artifacts

$missingBlock

## Schema Problems

$schemaBlock

## Local Daily Task Status

- Daily log: ``$dailyLogPath``
- Governor latest CSV / summary and snapshot coverage outputs checked under ``tables`` / ``reports/maintenance``.

## Agent Publication Status

Expected producers (per maintenance plan): ``$($expectedAgents -join ', ')``.

## Final Verdicts

$verdictBlock

"@

$tableDir = Split-Path -Parent $tableOut
if (-not (Test-Path -LiteralPath $tableDir)) {
    New-Item -ItemType Directory -Path $tableDir -Force | Out-Null
}
$reportDir = Split-Path -Parent $reportOut
if (-not (Test-Path -LiteralPath $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}

$rows | Select-Object date, producer, artifact_type, path, status, alert_level, notes |
    Export-Csv -LiteralPath $tableOut -NoTypeInformation -Encoding UTF8

Set-Content -LiteralPath $reportOut -Value $md.TrimEnd() -Encoding UTF8

Write-Output ("Agent output dir: {0}" -f $agentOutDir)
Write-Output ("Rows evaluated: {0}" -f $rows.Count)
Write-Output ("ALERT_LEVEL: {0}" -f $alertLevelOverall)
Write-Output ("Table: {0}" -f $tableOut)
Write-Output ("Report: {0}" -f $reportOut)
exit 0
