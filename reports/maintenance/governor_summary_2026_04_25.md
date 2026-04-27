# Maintenance Governor Summary (Fixture)

Run ID: $runId
Run UTC: $runUtcText

## Overview

- New findings: 4
- Resurfaced findings: 0
- Still-open findings: 4
- Candidate-resolved findings: 1
- Duplicate/reference-only findings: 1
- Human-decision-required findings: 2
- Validation errors: 2

## Categories

### New findings
- Generated from fixture input only (non-authoritative).

### Candidate resolved
- Items with clean_cycle_count below closure threshold are listed for monitoring only.

### Human decision required
- Listed in approval queue; no approvals applied.

### Validation behavior
- Malformed rows were rejected and emitted as VALIDATION_ERROR events.
- Missing/invalid confidence fails validation.

## Policy guardrails

- Advisory-only pre-governor behavior remains in effect.
- No backlog mutation performed.
- No RESOLVED or WONTFIX decisions applied.
