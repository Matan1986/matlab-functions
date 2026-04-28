# reports/maintenance README

## Purpose
`reports/maintenance/` stores durable repository-governance and artifact-organization reports.
This folder is for policy, contract, audit synthesis, and governance decisions that must remain reviewable over time.

## Allowed Report Types
- governance audits about repository structure and artifact placement
- policy synthesis reports and contract interpretation reports
- maintenance index-layer completion reports
- migration planning reports that do not execute file movement

## Forbidden Report Types
- transient execution logs
- one-off probe output dumps
- raw tool stdout/stderr captures
- module scientific result narratives that belong in `reports/<module>/`
- unscoped personal scratch notes

## Durable vs Transient
Durable governance reports are long-lived references used for policy decisions, cleanup blocking decisions, and migration planning.
Transient logs are run-time evidence and local diagnostics that may expire or be replaced; they are not durable by default.

## Force-Add Policy for Durable Governance Reports
Force-add may be used only when all conditions hold:
- destination is `reports/maintenance/`
- content is governance-durable (not transient log spillover)
- report has clear maintenance ownership and policy purpose
- retention intent is explicit in the report or linked contract

Force-add is forbidden for transient logs, probes, and local tooling state.

## Retention Policy
- durable governance reports in this folder are retained as repository decision history
- obsolete reports may be superseded but should remain traceable
- deletion or archive actions require explicit governance review
- retention decisions for transient maintenance outputs are separate from this README

## Current Durable Governance Reports
- `repo_artifact_organization_atlas.md`
- `repo_structure_governance_audit.md`
- `root_folder_declutter_audit.md`
- `unified_artifact_policy_synthesis.md`

## Explicit Non-Automatic Durability Zones
`reports/maintenance/logs/` and `reports/maintenance/agent_outputs/` are not automatically durable.
Each artifact in those zones requires a separate retention decision before being treated as durable governance history.
