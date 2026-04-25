# Switching Canonical Boundary Guard

Observed at UTC: `2026-04-25T11:52:39Z`
Module: `Switching`
Module state: `CANONICAL`
Producer mode: advisory-only pre-governor

## RUN SUMMARY

- Read the required operational anchors first, then scanned the Switching canonical entrypoint, collapse-hierarchy metadata, repo context layers, query layer, claims, snapshot indexes, and run registry.
- Found 3 boundary findings.
- Highest-risk issues are in the knowledge and query layers, not in the canonical collapse-hierarchy producer itself.
- The current canonical collapse hierarchy explicitly reports `used_width_scaling = NO`, while claims/query/snapshot propagation remains pending.

## BOUNDARY RISKS

| Severity | Rule | Finding key | Title |
| --- | --- | --- | --- |
| HIGH | `SCB_STALE_003` | `9776d6343267b92901d5220db49c8c9a5059744a` | Query entrypoint can override repo context with external bundle |
| HIGH | `SCB_MODEL_006` | `9bb0a74ef1b34866471336a71751f153c8636ab3` | Width-based X claim still presented as canonical current Switching context |
| MEDIUM | `SCB_META_002` | `0161d8437fb83946a0d1cc6f160d935858025146` | Referenced Switching canonical identity anchor is missing |

## CANONICAL LABELING ISSUES

### `SCB_META_002` - Referenced Switching canonical identity anchor is missing

- `docs/project_control_board.md` lists `tables/switching_canonical_identity.csv` as an authoritative anchor.
- The active Switching workstream row also names that same file in its anchor set.
- The file is absent in-tree, while `analysis/knowledge/run_registry.csv` still marks `run_2026_04_03_000147_switching_canonical` as `canonical_identity_anchor`.
- Result: canonical identity is discoverable only indirectly, and the documented canonical anchor path is broken.

### `SCB_MODEL_006` - Width-based X claim still presented as canonical current Switching context

- `claims/X_canonical_coordinate.json` still states `X = I_peak / (w * S_peak)` as a canonical coordinate.
- `docs/context_bundle.json` and `docs/repo_state.json` still expose that claim and `width_I` as current Switching context.
- `snapshot_scientific_v3/70_evidence_index/evidence_edges_claim_to_run.jsonl` still ties that claim to March cross-experiment runs.
- Current canonical collapse-hierarchy output says `used_width_scaling = NO`, so the knowledge layer still exposes a width-linked assumption that is no longer aligned with the current canonical collapse metadata.

## STALE-REFERENCE RISKS

### `SCB_STALE_003` - Query entrypoint can override repo context with external bundle

- `analysis/query/query_system.m` prefers `C:\Dev\matlab-functions_context\context_bundle.json` when it exists.
- The same query entrypoint seeds Switching answers from `X_canonical_coordinate` and other `X_*` claims.
- `docs/project_control_board.md` already warns that `analysis/query/query_system.m` is not yet canonical-aware.
- `tables/project_workstream_status.csv` still reports `claims_alignment=LEGACY_WEIGHTED`, `snapshot_alignment=PARTIAL`, and `query_alignment=NO`.
- Result: a user or agent can get Switching answers grounded in stale or out-of-repo context and misread them as current canonical truth.

## MINIMAL FIX SUGGESTIONS

- Restore or regenerate `tables/switching_canonical_identity.csv`, or remove it from authoritative-anchor lists until a valid tracked replacement exists.
- Gate `analysis/query/query_system.m` so repo-local context wins by default for Switching, and emit a hard warning when `contextSource = EXTERNAL`.
- Mark width-based `X` claims and linked snapshot/query assets as legacy or advisory until canonical propagation is completed, or replace them with the current `used_width_scaling = NO` canonical collapse anchors.

## FINAL VERDICT

- AGENT_RUN_COMPLETED = YES
- NORMALIZED_FINDINGS_EMITTED = YES
- ADVISORY_ONLY_PRE_GOVERNOR = YES
- BACKLOG_MUTATED = NO
