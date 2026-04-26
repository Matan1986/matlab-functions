# Knowledge / Query / Index Usage Audit

Date: 2026-04-26

## Flags
- `USAGE_AUDIT_COMPLETED = YES`
- `QUERY_INDEX_LAYER_EXISTS = YES`
- `QUERY_INDEX_LAYER_ACTIVE = PARTIAL`
- `SNAPSHOT_SCIENTIFIC_V3_ACTIVE = PARTIAL`
- `ACTIVE_CONSUMERS_FOUND = YES`
- `HUMAN_READABLE_CONTEXT_SUFFICIENT_NOW = YES`
- `QUERY_INDEX_UPDATE_NEEDED_NOW = NO`
- `SAFE_TO_SKIP_QUERY_INDEX_UPDATE = YES`
- `IF_UPDATE_NEEDED_PLAN_FIRST = YES`

## Executive Decision
The repository does have a real knowledge/query/index layer, and it is not purely archival. However, that layer is only partially active for current canonical Switching work.

The strongest current evidence path is:
1. `docs/context_bundle.json` / `docs/context_bundle_full.json` for semantic handoff
2. `analysis/knowledge/run_registry.csv` for run-to-evidence resolution
3. human-readable canonical context and snapshot reports for current Switching interpretation

`snapshot_scientific_v3` should be treated as a live but stale control-plane index. It is consumed by code and maintenance tooling, but it does not reflect the current canonical Switching state well enough to require an immediate update for the present documentation task.

## Systems Present
The following knowledge/query/index systems are present in the repo:

1. Context bundles
   - `docs/context_bundle.json`
   - `docs/context_bundle_full.json`
   - producer: `scripts/update_context.ps1`
2. Evidence run registry
   - `analysis/knowledge/run_registry.csv`
   - resolver: `analysis/knowledge/load_run_evidence.m`
3. Query utilities
   - `analysis/query/query_system.m`
   - `analysis/query/list_all_runs.m`
   - `analysis/query/start_query.m`
4. Snapshot control-plane graph
   - `snapshot_scientific_v3/...`
   - indices: `run_index.json`, `report_index.json`, `claim_index.json`, evidence edge JSONL files
5. Snapshot packaging layer
   - `scripts/run_snapshot.ps1`
   - `scripts/build_snapshot_simple.ps1`
6. Maintenance guard for snapshot coverage
   - `tools/maintenance/guard_run_snapshot_coverage.ps1`
7. Documentation navigation layer
   - `docs/knowledge_system_inventory.md`
   - `docs/knowledge_system_architecture.md`
   - `docs/scientific_system_map.md`
   - `docs/project_control_board.md`

## snapshot_scientific_v3 Status
Best classification: `PARTIAL_ACTIVE_STALE`

Why it is not archival:
- `analysis/query/query_system.m` directly reads:
  - `snapshot_scientific_v3/70_evidence_index/evidence_edges_claim_to_run.jsonl`
  - `snapshot_scientific_v3/40_analysis_catalog/analysis_registry.json`
  - `snapshot_scientific_v3/60_claims_surveys/claim_index.json`
- `tools/maintenance/guard_run_snapshot_coverage.ps1` directly checks:
  - `snapshot_scientific_v3/30_runs_evidence/run_index.json`
  - `snapshot_scientific_v3/00_entrypoints/consistency_check.json`
- architecture and system-map docs still describe it as the deterministic evidence navigation control plane.

Why it is not authoritative-current for canonical Switching:
- `snapshot_scientific_v3/30_runs_evidence/run_index.json` has `generated_at = 2026-03-23T10:59:22...`
- `snapshot_scientific_v3/00_entrypoints/consistency_check.json` was last checked on `2026-03-23`
- `analysis/knowledge/run_registry.csv` is newer (`2026-04-24`)
- `docs/context_bundle.json` and `docs/context_bundle_full.json` are newer (`2026-04-24`)
- the snapshot run index contains only `10` runs
- the current canonical Switching run `run_2026_04_03_000147_switching_canonical` is present in `analysis/knowledge/run_registry.csv` but absent from `snapshot_scientific_v3`
- referenced `runpack` payloads under `snapshot_scientific_v3/30_runs_evidence/runpacks/` are not present in this workspace

## Active Consumers Found
### Scripts / tools
- `analysis/query/query_system.m`
- `analysis/query/list_all_runs.m`
- `analysis/knowledge/load_run_evidence.m`
- `scripts/update_context.ps1`
- `scripts/build_snapshot_simple.ps1`
- `scripts/run_snapshot.ps1`
- `tools/maintenance/guard_run_snapshot_coverage.ps1`

### Documentation / operator guidance
- `docs/AGENT_ENTRYPOINT.md`
- `docs/AGENT_RULES.md`
- `docs/knowledge_system_inventory.md`
- `docs/knowledge_system_architecture.md`
- `docs/scientific_system_map.md`
- `docs/project_control_board.md`

## Canonical Switching Relevance
For the current Switching work, the repo itself already warns against over-trusting the query/index layer:

- `docs/project_control_board.md` says `snapshot_scientific_v3/` may lag canonical integration and should not be treated as current canonical state unless explicit alignment is shown.
- The same file says `analysis/query/query_system.m` is not yet canonical-aware and may mix canonical and legacy evidence.

That matches the file-level evidence:
- canonical Switching context and human-readable snapshot were updated in April 2026
- the snapshot graph remains March 2026 and does not include the canonical Switching anchor run

## Is Query / Index Update Needed Now?
Current answer: `NO`

Reasoning:
- The current task is documentation-layer claim boundary handling, not machine query rollout.
- Human-readable canonical context and human-readable canonical snapshot have already been updated append-only.
- The currently active machine-query path is not canonical-safe enough to use as an authoritative consumer for the new Switching state.
- Updating `snapshot_scientific_v3` or related query/index artifacts now would be a separate integration task, not a required continuation of the present claim-readiness work.

## Are Human-Readable Context and Snapshot Updates Sufficient Now?
Current answer: `YES`

For the current stage, the human-readable updates are sufficient because they:
- carry the current canonical Switching interpretation
- preserve noncanonical history
- attach the full-closure caveat
- explicitly keep rank-3 as an open weak structured residual

That is enough for present context/snapshot communication. It is not enough for future machine-query consumers that need canonical-safe retrieval, but that is a later integration step.

## When Would Query / Index Updates Become Necessary?
They become necessary when any of the following is intended:

1. canonical-current Switching retrieval through `analysis/query/query_system.m`
2. canonical claim routing through `snapshot_scientific_v3` entrypoints
3. snapshot-driven machine consumers that must distinguish canonical from historical Switching results without manual caveats
4. shipping a refreshed snapshot package meant to expose the new canonical Switching state programmatically

If that work is started, a plan should come first because the update touches multiple coupled layers:
- snapshot graph membership
- claim and report indices
- run registry linkage expectations
- canonical/noncanonical separation rules for Switching

## Files Inspected
- `analysis/query/query_system.m`
- `analysis/query/list_all_runs.m`
- `analysis/query/start_query.m`
- `analysis/knowledge/load_run_evidence.m`
- `analysis/knowledge/run_registry.csv`
- `scripts/update_context.ps1`
- `scripts/build_snapshot_simple.ps1`
- `scripts/run_snapshot.ps1`
- `tools/maintenance/guard_run_snapshot_coverage.ps1`
- `docs/knowledge_system_inventory.md`
- `docs/knowledge_system_architecture.md`
- `docs/scientific_system_map.md`
- `docs/project_control_board.md`
- `docs/snapshot_system_design.md`
- `docs/snapshot_system_map.md`
- `snapshot_scientific_v3/00_entrypoints/consistency_check.json`
- `snapshot_scientific_v3/30_runs_evidence/run_index.json`

## Bottom Line
The knowledge/query/index layer exists and is used, but it is only partially active for current canonical Switching work. `snapshot_scientific_v3` is best understood as a stale-but-live control plane, not an archival dead layer and not the current canonical truth source.

For the present Switching claim-boundary stage, it is safe to skip query/index updates. If the repo later needs canonical-safe machine retrieval, the right next step is a separate planned integration pass rather than an opportunistic edit.
