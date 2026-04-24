# Project Control Board

## Scope

This file is a minimal coordination layer only.

It tracks active workstreams and integration status at a high level.

It is not a source of scientific evidence and does not replace:
- claims
- snapshot graph
- context bundles
- run registries
- surveys
- system plans or infrastructure laws

## Authoritative Anchors

- `docs/system_master_plan.md`
- `docs/infrastructure_laws.md`
- `docs/AGENT_RULES.md`
- `docs/system_registry.json`
- `tables/module_canonical_status.csv`
- `tables/switching_canonical_identity.csv`
- `analysis/knowledge/run_registry.csv`
- `snapshot_scientific_v3/`
- `docs/context_bundle.json`

## Global Status Notes

- Phase and gate status is defined by `docs/system_master_plan.md`.
- Cross-module science is not unlocked by this board.
- Avoid DONE/CLOSED/SAFE language unless explicitly anchored to authoritative files.
- Operational precedence gate: if generated context, claims, query, or scientific snapshot disagree with this board or `tables/project_workstream_status.csv`, treat this board plus the workstream table as the operational-state gate until producers are explicitly regenerated and verified.

## Active Workstreams

See `tables/project_workstream_status.csv` (one row per active workstream).

## Critical Warnings

- Canonical Switching code, canonical run identity, and canonical run registry discoverability now exist.
- Switching canonical collapse inputs are gated on per-table `.csv.meta.json` sidecar metadata from producers; missing metadata blocks canonical collapse hierarchy runs (expected); commit `c703f8b` adds validation, not completed collapse metrics.
- Switching context source metadata is now aligned in `docs/repo_state.json` to canonical entrypoint/run anchors.
- Context bundles were regenerated from aligned sources, including the extended model source for Switching metadata.
- Switching knowledge-system integration remains WEAK because claims, snapshot, context, and query layers are still legacy-weighted, mixed, or non-canonical for Switching.
- Snapshot, claims, and query propagation remain pending and are not closed by context regeneration.
- `snapshot_scientific_v3/` is a historical/evidence index and may lag canonical integration; do not treat it as current canonical state unless workstream status shows `snapshot_alignment=YES`.
- `claims/` may remain legacy-weighted; do not treat claims as canonical-current unless workstream status shows `claims_alignment=YES`.
- `analysis/query/query_system.m` is not yet canonical-aware and query outputs may mix canonical and legacy evidence.
- `analysis/knowledge/run_registry.csv` is a query/discovery registry and is not a complete filesystem inventory of every run directory.
- Do not build a new Switching context bundle before micro-integration is planned and executed.

## Update Protocol

- Update only at end-of-chat or end-of-agent-task when status changes.
- Every non-UNKNOWN status must include anchor paths.
- Use UNKNOWN when not proven.
- Do not copy evidence payloads, full claim text, snapshot edges, or run dumps into this layer.
- Keep one row per active workstream.
- Timestamp and updater are required for each row update.

## Status and Confidence Rubric

- Status: STRONG, PARTIAL, WEAK, BROKEN, UNKNOWN
- Confidence: HIGH, MEDIUM, LOW
