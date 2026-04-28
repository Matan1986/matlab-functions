# tables maintenance README

## Purpose
`tables/maintenance_*.csv` stores durable maintenance and governance tables for repository artifact policy, tracking, and decision support.
These tables are structured governance assets, not generic scratch output.

## Naming Rule
All durable maintenance governance tables must follow:
- `tables/maintenance_<topic>.csv`

## Allowed Maintenance Table Types
- policy decision registries
- migration backlog trackers
- cleanup blocker registers
- required index coverage trackers
- policy input coverage trackers

## Required Columns Where Applicable
Required columns depend on table type; the minimum governance fields are:
- `table_id` or equivalent stable row identifier
- `topic` or `artifact_scope`
- `owner` or `owning_layer`
- `status` and `last_reviewed` (or equivalent lifecycle fields)
- `notes` or `rationale`

For required-index tracking tables, include explicit target-path and blocking metadata (for example: `target_path`, `priority`, `blocks_cleanup`).
For policy-decision tables, include decision text, decision owner, and decision status.
For backlog/blocker tables, include action item, blocker reason, and unblock condition.

## Force-Add Policy Under tables Ignore Constraints
Force-add is allowed despite broad `tables/**` ignore constraints only when all conditions hold:
- file matches `tables/maintenance_<topic>.csv`
- table is governance-durable and policy-scoped
- table is not a giant local raw audit evidence dump
- table is linked to maintenance contract/policy usage

Force-add is not allowed for transient local raw extraction outputs, intermediate scans, or unreviewed huge evidence dumps.

## Durable Governance Tables vs Huge Local Raw Audit Evidence
Durable governance tables are curated, policy-facing, and retained for decisions.
Huge local raw audit evidence is operational input material and is not durable by default, even if CSV formatted.

## Current Tracked Policy Tables
- `maintenance_artifact_policy_decisions.csv`
- `maintenance_artifact_migration_backlog.csv`
- `maintenance_artifact_cleanup_blockers.csv`
- `maintenance_artifact_required_indexes.csv`
- `maintenance_artifact_policy_input_coverage.csv`
