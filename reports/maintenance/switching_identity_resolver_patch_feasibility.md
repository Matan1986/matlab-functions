# Switching Identity Resolver Patch Feasibility

## Executive Summary

Feasibility is **positive but cautious**: a bounded single-file patch in `Switching/utils/switchingResolveLatestCanonicalTable.m` is technically straightforward and aligns with current Switching governance anchors, provided that current newest-by-mtime behavior is preserved as a fallback path. Consumer impact is expected to be mostly low-to-medium, with a few high-risk canonical-adjacent consumers that should be dry-run checked.

## Current Resolver Behavior

Current function signature:

- `switchingResolveLatestCanonicalTable(repoRoot, fileName)`

Current behavior:

1. Builds `runsRoot` via `switchingCanonicalRunRoot(repoRoot)` -> `results/switching/runs`.
2. Enumerates directories matching `run_*_switching_canonical`.
3. For each run directory, probes `tables/<fileName>`.
4. Keeps only existing files.
5. Selects the file with max `dir(x).datenum` (newest mtime).
6. Returns that full file path.

Important notes:

- No explicit identity-table read.
- No explicit run-id input support.
- No canonical lock semantics in resolver logic.
- If runs root missing or no matches found, returns empty string.

## Identity Table Contract

`tables/switching_canonical_identity.csv` content shape:

- Header row: `field,value`
- Key row: `CANONICAL_RUN_ID,run_2026_04_03_000147_switching_canonical`
- Additional metadata rows: `STATUS,LOCKED`, `DUPLICATE_COUNT`, `INVALID_COUNT`, `LAST_VERIFIED`.

Contract usability:

- **Usable for resolver anchoring:** YES
- Enough info exists to resolve run root: YES (run id + known `results/switching/runs/<runId>/tables/<fileName>` path shape)
- Table filename inference: safe, because resolver already receives `fileName` argument
- Validation needed:
  - file exists and parseable
  - `CANONICAL_RUN_ID` present and non-empty
  - run directory exists
  - requested `tables/<fileName>` exists under anchor run

## Consumer Map

Direct consumers are mapped in:

- `tables/maintenance_switching_identity_resolver_consumers.csv`

Coverage summary:

- Distinct consumer scripts found: 11
- Total resolver call sites mapped: 18
- Typical requested artifacts:
  - `switching_canonical_S_long.csv`
  - `switching_canonical_phi1.csv`

Consumer assumptions:

- Most call sites implicitly assume "latest canonical-like file" semantics today.
- Governance docs and boundary policy now expect locked canonical identity precedence.

## Proposed Single-File Patch Design

Patch target (single file only):

- `Switching/utils/switchingResolveLatestCanonicalTable.m`

Design (no implementation in this task):

1. Keep current function signature unchanged.
2. Attempt identity-table path:
   - read `tables/switching_canonical_identity.csv`
   - parse `CANONICAL_RUN_ID`
3. Build anchor candidate path:
   - `results/switching/runs/<CANONICAL_RUN_ID>/tables/<fileName>`
4. If anchor file exists, return it immediately.
5. If identity table is missing/invalid or anchor artifact absent:
   - emit explicit warning (e.g., identity missing/invalid or artifact missing under anchor)
   - execute existing mtime-based logic unchanged.
6. If fallback also finds nothing, return empty string (existing behavior).

Failure behavior proposal:

- **Primary behavior:** identity-anchored deterministic selection.
- **Fallback behavior:** warning-only mtime fallback for backward compatibility.
- **Hard failure:** not recommended yet, because multiple current consumers may still rely on permissive behavior and mixed route availability.

## Risks and Backward Compatibility

Why this is likely safe:

- Signature and return contract remain unchanged.
- Existing fallback path is retained.
- Identity-first behavior aligns with current control-board and layer-boundary language.

Residual risks:

- Consumers that implicitly depended on "newest run wins" may observe different source artifacts.
- High-risk consumers identified in prior owner audit (`run_switching_mode_admissibility_audit.m`, mixed mirror+resolver routes) should be dry-run checked first.
- Resolver patch does not by itself solve repo-root mirror production/consumption ambiguity.

Compatibility recommendation:

- Keep fallback enabled initially (warning-only).
- Add short-run dry-run checks on high-risk consumers before any hard-failure policy.

## Final Verdicts

FEASIBILITY_AUDIT_COMPLETED = YES  
IDENTITY_TABLE_USABLE = YES  
CONSUMERS_MAPPED = YES  
PATCH_SAFE_NOW = PARTIAL  
SINGLE_FILE_PATCH_POSSIBLE = YES  
CODE_MODIFIED = NO  
BACKLOG_MUTATED = NO  
SAFE_SCOPE_RESPECTED = YES  
READY_FOR_PATCH_DECISION = YES
