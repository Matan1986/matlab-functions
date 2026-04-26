# Switching Canonical Boundary Guard Report

Observed at UTC: `2026-04-26T03:33:45Z`
Module: `Switching`
Module state: `CANONICAL`
Producer mode: advisory-only pre-governor

## RUN SUMMARY

- Read the required operational anchors first, then scanned the Switching canonical entrypoint, collapse-hierarchy metadata, repo context layers, snapshot claim maps, and query layer.
- Found 4 boundary findings.
- Highest-risk issues remain in knowledge/query/context layers, not in the canonical collapse-hierarchy producer itself.
- Since the prior run, the claim JSON layer now carries explicit `LEGACY_NON_CANONICAL_ADVISORY` boundary labels for width-based `X` claims, so the earlier claim-layer model-assumption finding has narrowed to stale downstream context/snapshot/query propagation.

## BOUNDARY RISKS

| Severity | Rule | Finding key | Title |
| --- | --- | --- | --- |
| HIGH | `SCB_STALE_003` | `eb80f1df8fa78175e906f179e4f137b3d8bacd97` | Query system consumes stale X claim context without canonical-current gate |
| HIGH | `SCB_STALE_003` | `ca3e618fb817e470eaa8300078a8e7347ca869dc` | Repo context bundle and repo state still present width-based X claims as supported current |
| MEDIUM | `SCB_META_002` | `8a90769b7f1191a5c24b9a3120984bb674929944` | Missing Switching canonical identity anchor |
| MEDIUM | `SCB_STALE_003` | `61c672f13a89bde0aa03df2afa0be7943bfe933c` | Snapshot claim status maps still rate width-based X claims as strong current |

## CANONICAL LABELING ISSUES

### `SCB_META_002` - Missing Switching canonical identity anchor

- `docs/project_control_board.md` and the active Switching workstream row both warn that `tables/switching_canonical_identity.csv` is the intended canonical identity anchor, but the file is absent in-tree.
- Because the file is missing, canonical run identity is only indirectly recoverable from other artifacts instead of from the documented anchor path itself.
- This is a metadata-linkage gap, not evidence that canonical Switching is invalid.

### `SCB_STALE_003` - Repo context bundle and repo state still present width-based X claims as supported current

- `claims/X_canonical_coordinate.json` now carries `boundary_status = LEGACY_NON_CANONICAL_ADVISORY` and explicitly says not to treat width-based `X` as canonical-current without anchor confirmation.
- `docs/context_bundle.json` still lists `X_canonical_coordinate` and related `X_*` claims as `supported` with `high` confidence.
- `docs/repo_state.json` still defines `X` as the Switching-derived bridge observable and points cross-experiment physics to `claims/X_scaling_relation`.
- Result: required read-before-work context files still flatten legacy-advisory width-based claims into current-looking Switching guidance.

## STALE-REFERENCE RISKS

### `SCB_STALE_003` - Query system consumes stale X claim context without canonical-current gate

- `analysis/query/query_system.m` prefers an external context bundle path before the repo-local bundle and uses `X_canonical_coordinate`, `X_scaling_relation`, and related `X_*` claims as query seeds.
- The control board already says `analysis/query/query_system.m` is not yet canonical-aware, and the Switching workstream still reports `claims_alignment=LEGACY_WEIGHTED`, `snapshot_alignment=PARTIAL`, and `query_alignment=NO`.
- Result: Switching answers can be assembled from stale or out-of-repo claim/context assets and be misread as canonical-current.

### `SCB_STALE_003` - Snapshot claim status maps still rate width-based X claims as strong current

- `snapshot_scientific_v3/60_claims_surveys/proven_status_map.json` still rates `X_canonical_coordinate` and `X_scaling_relation` as `strong`.
- `snapshot_scientific_v3/70_evidence_index/evidence_summary.json` still summarizes the same March-era width-based `X` claim stack as active evidence summaries.
- The control board explicitly warns that `snapshot_scientific_v3/` may lag canonical integration unless workstream status shows `snapshot_alignment=YES`, which it does not.

## MINIMAL FIX SUGGESTIONS

- Restore or deliberately replace `tables/switching_canonical_identity.csv`, or remove it from authoritative-anchor references until a tracked replacement exists.
- Add a hard canonical-current gate in `analysis/query/query_system.m`: repo-local Switching anchors should win by default, and any external context source should trigger an explicit advisory warning.
- Regenerate or patch `docs/context_bundle.json`, `docs/repo_state.json`, and the relevant snapshot claim-status artifacts so they preserve the new width-based `X` boundary labels instead of restating those claims as current-supported.

## FINAL VERDICTS

- Advisory-only pre-governor run completed.
- Normalized findings emitted for every advisory finding.
- No backlog tables or scientific code were changed.

AGENT_RUN_COMPLETED = YES
NORMALIZED_FINDINGS_EMITTED = YES
ADVISORY_ONLY_PRE_GOVERNOR = YES
BACKLOG_MUTATED = NO
PUBLICATION_STATUS = PUBLICATION_OK
PUBLICATION_ROUTE = PR_BRANCH
PUBLICATION_URL = https://github.com/Matan1986/matlab-functions/tree/automation/switching-canonical-boundary-guard-2026-04-25/reports/maintenance/agent_outputs/2026_04_26
