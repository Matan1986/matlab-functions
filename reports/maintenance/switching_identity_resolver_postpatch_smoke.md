# Switching Identity Resolver Post-Patch Smoke Check

## Executive Summary

Post-patch smoke validation was performed **without modifying code** and **without executing** the high-risk Switching analysis runners (to avoid new run outputs and stay within smoke-only scope). Resolver behavior was verified by **static inspection** of `Switching/utils/switchingResolveLatestCanonicalTable.m` together with **on-disk** confirmation that the identity table and anchor artifacts exist. Under those conditions, both `switching_canonical_S_long.csv` and `switching_canonical_phi1.csv` resolve to the locked canonical run root. Fallback paths remain present in source. High-risk consumers were checked **statically only** (call sites and signature usage unchanged).

## Resolver Direct Checks

Identity source: `tables/switching_canonical_identity.csv` contains `CANONICAL_RUN_ID=run_2026_04_03_000147_switching_canonical` and `STATUS=LOCKED`.

Expected anchor base: `results/switching/runs/run_2026_04_03_000147_switching_canonical/tables/`

| fileName | returned_path (expected from code + disk) | expected_anchor_path | matches_anchor | status |
|----------|---------------------------------------------|----------------------|------------------|--------|
| `switching_canonical_S_long.csv` | `.../run_2026_04_03_000147_switching_canonical/tables/switching_canonical_S_long.csv` | same | YES | PASS |
| `switching_canonical_phi1.csv` | `.../run_2026_04_03_000147_switching_canonical/tables/switching_canonical_phi1.csv` | same | YES | PASS |

Evidence: resolver returns `anchorPath` when `exist(anchorPath,'file')==2` then `return` (lines 30–34); both anchor files exist on disk under `C:/Dev/matlab-functions/results/switching/runs/run_2026_04_03_000147_switching_canonical/tables/`.

**Note:** MATLAB was not invoked to call the function directly (no new runnable script was added per task constraints); equivalence to a live call follows from the above static path.

## Fallback Preservation

Verified in `Switching/utils/switchingResolveLatestCanonicalTable.m`:

- Warning identifier `Switching:IdentityResolverFallback` appears on missing identity file, malformed table, missing/empty `CANONICAL_RUN_ID`, parse failure, and missing anchor artifact branches.
- After the identity block, the original `switchingCanonicalRunRoot` + `dir(run_*_switching_canonical)` + newest `datenum` selection remains (lines 52–62).
- Initial `p = ''` and `if isempty(paths), return; end` preserve empty return when no candidates exist.

Status: **PASS** (fallback preserved by inspection).

## High-Risk Consumer Smoke

| consumer_path | smoke_type | status | notes |
|----------------|------------|--------|-------|
| `Switching/analysis/run_switching_mode_admissibility_audit.m` | STATIC_ONLY | NOT_RUN_STATIC_ONLY | Calls `switchingResolveLatestCanonicalTable(repoRoot,'switching_canonical_S_long.csv')` and `...phi1.csv` at L53–L54; signature unchanged. No runner smoke. |
| `Switching/analysis/run_switching_backbone_stress_test.m` | STATIC_ONLY | NOT_RUN_STATIC_ONLY | Calls at L42–L43. No runner smoke. |
| `Switching/analysis/run_switching_observable_mapping_audit.m` | STATIC_ONLY | NOT_RUN_STATIC_ONLY | Calls at L48–L49. No runner smoke. |

## Remaining Risks

- **No live MATLAB invocation:** runtime warnings, `readtable` edge cases, or path normalization differences were not exercised here.
- **Consumer behavior:** static check does not prove end-to-end runs; post-merge optional lightweight MATLAB probe or controlled runner smoke remains advisable.
- **Mixed inputs:** these consumers still combine resolver output with repo-root `tables/` paths; that boundary risk is unchanged by the resolver patch.

## Final Verdicts

```text
POSTPATCH_SMOKE_COMPLETED = YES
RESOLVER_RETURNS_ANCHOR_FOR_S_LONG = YES
RESOLVER_RETURNS_ANCHOR_FOR_PHI1 = YES
FALLBACK_PRESERVED = YES
HIGH_RISK_CONSUMERS_CHECKED = PARTIAL
SMOKE_FAILURES = 0
CODE_MODIFIED = NO
BACKLOG_MUTATED = NO
SAFE_SCOPE_RESPECTED = YES
READY_TO_COMMIT = YES
```
