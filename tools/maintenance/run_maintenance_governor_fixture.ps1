[CmdletBinding()]
param(
    [string]$RepoRoot = "",
    [string]$FixtureValidPath = "",
    [string]$FixtureInvalidPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $scriptPath = $MyInvocation.MyCommand.Path
    if ([string]::IsNullOrWhiteSpace($scriptPath)) {
        throw "RepoRoot is required when script path is unavailable."
    }
    $RepoRoot = (Resolve-Path (Join-Path (Split-Path -Parent $scriptPath) "..\..")).Path
}

function Ensure-Dir {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function New-EventRow {
    param(
        [string]$EventId,
        [string]$RunId,
        [string]$EventUtc,
        [string]$FindingId,
        [string]$FindingKey,
        [string]$EventType,
        [string]$FromStatus,
        [string]$ToStatus,
        [string]$AgentName,
        [string]$OwnerAgent,
        [string]$Severity,
        [string]$Confidence,
        [string]$EvidenceRef,
        [string]$Notes,
        [string]$ApprovalRef
    )

    return [pscustomobject]@{
        event_id         = $EventId
        governor_run_id  = $RunId
        event_utc        = $EventUtc
        finding_id       = $FindingId
        finding_key      = $FindingKey
        event_type       = $EventType
        from_status      = $FromStatus
        to_status        = $ToStatus
        agent_name       = $AgentName
        owner_agent      = $OwnerAgent
        severity         = $Severity
        confidence       = $Confidence
        evidence_ref     = $EvidenceRef
        notes            = $Notes
        approval_ref     = $ApprovalRef
    }
}

if ([string]::IsNullOrWhiteSpace($FixtureValidPath)) {
    $FixtureValidPath = Join-Path $RepoRoot "reports\maintenance\fixtures\fixture_findings_valid.csv"
}
if ([string]::IsNullOrWhiteSpace($FixtureInvalidPath)) {
    $FixtureInvalidPath = Join-Path $RepoRoot "reports\maintenance\fixtures\fixture_findings_invalid.csv"
}

$tablesDir = Join-Path $RepoRoot "tables"
$reportsMaintenanceDir = Join-Path $RepoRoot "reports\maintenance"
$datedOutputsDir = $reportsMaintenanceDir

Ensure-Dir -Path $tablesDir
Ensure-Dir -Path $reportsMaintenanceDir

$runUtc = [DateTime]::UtcNow
$runDateToken = $runUtc.ToString("yyyy_MM_dd")
$runUtcText = $runUtc.ToString("o")
$runId = "governor_fixture_" + $runUtc.ToString("yyyyMMdd_HHmmss")

$requiredColumns = @(
    "provisional_finding_id",
    "finding_key",
    "theme",
    "rule_id",
    "agent_name",
    "title",
    "description",
    "module",
    "module_state",
    "scope",
    "location",
    "severity",
    "confidence",
    "status",
    "evidence_ref",
    "owner_agent",
    "human_approval_required",
    "next_action",
    "dedup_status",
    "observed_at_utc"
)

$allowedSeverities = @("HIGH", "MEDIUM", "LOW")
$allowedConfidence = @("HIGH", "MEDIUM", "LOW")
$allowedModuleState = @("CANONICAL", "NOT_CANONICAL", "UNKNOWN")
$allowedStatus = @("OPEN")
$allowedDedup = @("PRIMARY", "REFERENCE_ONLY", "UNRESOLVED_COLLISION")

$events = New-Object System.Collections.Generic.List[object]
$validRows = New-Object System.Collections.Generic.List[object]
$schemaErrors = 0
$eventSeq = 1

function Add-ValidationErrorEvent {
    param(
        [string]$FindingId,
        [string]$FindingKey,
        [string]$AgentName,
        [string]$EvidenceRef,
        [string]$Notes
    )
    $script:events.Add((New-EventRow `
        -EventId ("EVT-{0:D4}" -f $script:eventSeq) `
        -RunId $runId `
        -EventUtc $runUtcText `
        -FindingId $FindingId `
        -FindingKey $FindingKey `
        -EventType "VALIDATION_ERROR" `
        -FromStatus "" `
        -ToStatus "" `
        -AgentName $AgentName `
        -OwnerAgent "" `
        -Severity "" `
        -Confidence "" `
        -EvidenceRef $EvidenceRef `
        -Notes $Notes `
        -ApprovalRef ""
    ))
    $script:eventSeq++
    $script:schemaErrors++
}

foreach ($fixturePath in @($FixtureValidPath, $FixtureInvalidPath)) {
    if (-not (Test-Path -LiteralPath $fixturePath)) {
        Add-ValidationErrorEvent -FindingId "" -FindingKey "" -AgentName "" -EvidenceRef ("path:" + $fixturePath) -Notes "fixture_not_found"
        continue
    }

    $rows = Import-Csv -LiteralPath $fixturePath
    foreach ($row in $rows) {
        $missing = @()
        foreach ($col in $requiredColumns) {
            if (-not ($row.PSObject.Properties.Name -contains $col) -or [string]::IsNullOrWhiteSpace([string]$row.$col)) {
                $missing += $col
            }
        }

        $findingIdRaw = [string]$row.provisional_finding_id
        $findingKeyRaw = [string]$row.finding_key
        $agentNameRaw = [string]$row.agent_name
        $evidenceRefRaw = [string]$row.evidence_ref

        if ($missing.Count -gt 0) {
            Add-ValidationErrorEvent -FindingId $findingIdRaw -FindingKey $findingKeyRaw -AgentName $agentNameRaw -EvidenceRef $evidenceRefRaw -Notes ("missing_required_columns:" + ($missing -join "|"))
            continue
        }

        if ($allowedSeverities -notcontains [string]$row.severity) {
            Add-ValidationErrorEvent -FindingId $findingIdRaw -FindingKey $findingKeyRaw -AgentName $agentNameRaw -EvidenceRef $evidenceRefRaw -Notes "invalid_severity"
            continue
        }
        if ($allowedConfidence -notcontains [string]$row.confidence) {
            Add-ValidationErrorEvent -FindingId $findingIdRaw -FindingKey $findingKeyRaw -AgentName $agentNameRaw -EvidenceRef $evidenceRefRaw -Notes "invalid_or_missing_confidence"
            continue
        }
        if ($allowedModuleState -notcontains [string]$row.module_state) {
            Add-ValidationErrorEvent -FindingId $findingIdRaw -FindingKey $findingKeyRaw -AgentName $agentNameRaw -EvidenceRef $evidenceRefRaw -Notes "invalid_module_state"
            continue
        }
        if ($allowedStatus -notcontains [string]$row.status) {
            Add-ValidationErrorEvent -FindingId $findingIdRaw -FindingKey $findingKeyRaw -AgentName $agentNameRaw -EvidenceRef $evidenceRefRaw -Notes "invalid_status"
            continue
        }
        if ($allowedDedup -notcontains [string]$row.dedup_status) {
            Add-ValidationErrorEvent -FindingId $findingIdRaw -FindingKey $findingKeyRaw -AgentName $agentNameRaw -EvidenceRef $evidenceRefRaw -Notes "invalid_dedup_status"
            continue
        }
        if ([string]$row.dedup_status -eq "REFERENCE_ONLY" -and [string]::IsNullOrWhiteSpace([string]$row.dup_of)) {
            Add-ValidationErrorEvent -FindingId $findingIdRaw -FindingKey $findingKeyRaw -AgentName $agentNameRaw -EvidenceRef $evidenceRefRaw -Notes "reference_only_missing_dup_of"
            continue
        }
        try {
            [void][DateTime]::Parse([string]$row.observed_at_utc)
        } catch {
            Add-ValidationErrorEvent -FindingId $findingIdRaw -FindingKey $findingKeyRaw -AgentName $agentNameRaw -EvidenceRef $evidenceRefRaw -Notes "invalid_observed_at_utc"
            continue
        }

        $validRows.Add($row)
    }
}

$latestRows = New-Object System.Collections.Generic.List[object]
foreach ($row in $validRows) {
    $findingId = [string]$row.provisional_finding_id
    if ($findingId.StartsWith("PFX-")) {
        $findingId = "MNT-FX-" + $findingId.Substring(4)
    }

    $cleanCycle = 0
    if (-not [string]::IsNullOrWhiteSpace([string]$row.clean_cycle_count)) {
        $parsed = 0
        if ([int]::TryParse([string]$row.clean_cycle_count, [ref]$parsed)) {
            $cleanCycle = $parsed
        }
    }

    $latestRows.Add([pscustomobject]@{
        finding_id            = $findingId
        finding_key           = [string]$row.finding_key
        theme                 = [string]$row.theme
        rule_id               = [string]$row.rule_id
        title                 = [string]$row.title
        description           = [string]$row.description
        module                = [string]$row.module
        module_state          = [string]$row.module_state
        scope                 = [string]$row.scope
        location              = [string]$row.location
        severity              = [string]$row.severity
        confidence            = [string]$row.confidence
        status                = [string]$row.status
        owner_agent           = [string]$row.owner_agent
        secondary_agents      = [string]$row.secondary_agents
        evidence_ref          = [string]$row.evidence_ref
        first_seen_utc        = $runUtcText
        last_seen_utc         = $runUtcText
        seen_count            = 1
        clean_cycle_count     = $cleanCycle
        human_approval_required = [string]$row.human_approval_required
        next_action           = [string]$row.next_action
        dedup_status          = [string]$row.dedup_status
        dup_of                = [string]$row.dup_of
        last_governor_run_id  = $runId
        last_governor_run_utc = $runUtcText
    })

    $events.Add((New-EventRow `
        -EventId ("EVT-{0:D4}" -f $eventSeq) `
        -RunId $runId `
        -EventUtc $runUtcText `
        -FindingId $findingId `
        -FindingKey ([string]$row.finding_key) `
        -EventType "NEW" `
        -FromStatus "" `
        -ToStatus "OPEN" `
        -AgentName ([string]$row.agent_name) `
        -OwnerAgent ([string]$row.owner_agent) `
        -Severity ([string]$row.severity) `
        -Confidence ([string]$row.confidence) `
        -EvidenceRef ([string]$row.evidence_ref) `
        -Notes "fixture_row_accepted" `
        -ApprovalRef ""
    ))
    $eventSeq++
}

$candidateResolvedCount = @($latestRows | Where-Object { $_.clean_cycle_count -ge 1 -and $_.clean_cycle_count -lt 2 }).Count
$humanDecisionRequiredCount = @($latestRows | Where-Object { $_.human_approval_required -eq "YES" }).Count
$duplicateReferenceCount = @($latestRows | Where-Object { $_.dedup_status -eq "REFERENCE_ONLY" }).Count

$summaryRows = @(
    [pscustomobject]@{
        governor_run_id               = $runId
        run_utc                       = $runUtcText
        agents_expected               = 5
        agents_received               = 0
        schema_errors_count           = $schemaErrors
        new_count                     = $latestRows.Count
        resurfaced_count              = 0
        still_open_count              = $latestRows.Count
        candidate_resolved_count      = $candidateResolvedCount
        stale_planned_count           = 0
        duplicate_reference_count     = $duplicateReferenceCount
        human_decision_required_count = $humanDecisionRequiredCount
        blocked_count                 = if ($schemaErrors -gt 0) { 1 } else { 0 }
        overall_health                = if ($schemaErrors -gt 0) { "YELLOW" } else { "GREEN" }
    }
)

$latestPath = Join-Path $tablesDir "maintenance_findings_latest.csv"
$eventsPath = Join-Path $tablesDir "maintenance_findings_events.csv"
$summaryPath = Join-Path $tablesDir "maintenance_governor_summary.csv"

$latestRows | Export-Csv -LiteralPath $latestPath -NoTypeInformation -Encoding UTF8
$events | Export-Csv -LiteralPath $eventsPath -NoTypeInformation -Encoding UTF8
$summaryRows | Export-Csv -LiteralPath $summaryPath -NoTypeInformation -Encoding UTF8

$governorSummaryDated = Join-Path $datedOutputsDir ("governor_summary_{0}.md" -f $runDateToken)
$approvalQueueDated = Join-Path $datedOutputsDir ("approval_queue_{0}.md" -f $runDateToken)
$governorSummaryLatest = Join-Path $datedOutputsDir "governor_summary_latest.md"
$approvalQueueLatest = Join-Path $datedOutputsDir "approval_queue_latest.md"

$summaryMd = @"
# Maintenance Governor Summary (Fixture)

Run ID: `$runId`
Run UTC: `$runUtcText`

## Overview

- New findings: $($latestRows.Count)
- Resurfaced findings: 0
- Still-open findings: $($latestRows.Count)
- Candidate-resolved findings: $candidateResolvedCount
- Duplicate/reference-only findings: $duplicateReferenceCount
- Human-decision-required findings: $humanDecisionRequiredCount
- Validation errors: $schemaErrors

## Categories

### New findings
- Generated from fixture input only (non-authoritative).

### Candidate resolved
- Items with `clean_cycle_count` below closure threshold are listed for monitoring only.

### Human decision required
- Listed in approval queue; no approvals applied.

### Validation behavior
- Malformed rows were rejected and emitted as `VALIDATION_ERROR` events.
- Missing/invalid `confidence` fails validation.

## Policy guardrails

- Advisory-only pre-governor behavior remains in effect.
- No backlog mutation performed.
- No `RESOLVED` or `WONTFIX` decisions applied.
"@

$approvalCandidates = @($latestRows | Where-Object { $_.human_approval_required -eq "YES" -or $_.clean_cycle_count -ge 1 })
$approvalMdLines = New-Object System.Collections.Generic.List[string]
$approvalMdLines.Add("# Maintenance Approval Queue (Fixture)")
$approvalMdLines.Add("")
$approvalMdLines.Add("Run ID: $runId")
$approvalMdLines.Add("Run UTC: $runUtcText")
$approvalMdLines.Add("")
$approvalMdLines.Add("## Candidate items (advisory only)")
$approvalMdLines.Add("")
if ($approvalCandidates.Count -eq 0) {
    $approvalMdLines.Add("- None")
} else {
    foreach ($item in $approvalCandidates) {
        $queueType = if ($item.clean_cycle_count -ge 2) { "CANDIDATE_RESOLVED_ELIGIBLE" } elseif ($item.clean_cycle_count -ge 1) { "CANDIDATE_RESOLVED_NOT_ELIGIBLE" } else { "HUMAN_DECISION_REQUIRED" }
        $approvalMdLines.Add("- Finding: $($item.finding_id) | QueueType: $queueType | Status: $($item.status) | HumanApprovalRequired: $($item.human_approval_required) | NextAction: $($item.next_action)")
    }
}
$approvalMdLines.Add("")
$approvalMdLines.Add("## Rules")
$approvalMdLines.Add("")
$approvalMdLines.Add("- This queue is advisory only.")
$approvalMdLines.Add("- No auto-approval applied.")
$approvalMdLines.Add("- WONTFIX requires explicit user approval.")
$approvalMdLines.Add("- RESOLVED requires threshold + explicit user approval.")

Set-Content -LiteralPath $governorSummaryDated -Value $summaryMd -Encoding UTF8
Set-Content -LiteralPath $approvalQueueDated -Value ($approvalMdLines -join [Environment]::NewLine) -Encoding UTF8
Copy-Item -LiteralPath $governorSummaryDated -Destination $governorSummaryLatest -Force
Copy-Item -LiteralPath $approvalQueueDated -Destination $approvalQueueLatest -Force

Write-Output "FIXTURE_RUN_ID=$runId"
Write-Output "VALID_ROWS_ACCEPTED=$($latestRows.Count)"
Write-Output "VALIDATION_ERRORS=$schemaErrors"
Write-Output "WROTE=$latestPath"
Write-Output "WROTE=$eventsPath"
Write-Output "WROTE=$summaryPath"
Write-Output "WROTE=$governorSummaryDated"
Write-Output "WROTE=$approvalQueueDated"
Write-Output "WROTE=$governorSummaryLatest"
Write-Output "WROTE=$approvalQueueLatest"
