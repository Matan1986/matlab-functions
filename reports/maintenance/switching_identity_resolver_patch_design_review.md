# Switching Identity Resolver Patch Design Review

## Executive Summary

Design review outcome: a single-file resolver patch is viable and structurally safe **if** it preserves the current function signature and keeps newest-by-mtime as a warninged fallback path. The identity table contract is sufficient to anchor deterministic resolution to the locked canonical run id, and dry-run checks can be defined without changing any scientific code.

Current readiness is **PARTIAL** because high-risk consumers should be smoke-validated after patch application before promoting to hard-failure semantics.

## Current Contract

Target function:

- `Switching/utils/switchingResolveLatestCanonicalTable.m`

Current contract details:

- **Signature:** `p = switchingResolveLatestCanonicalTable(repoRoot, fileName)`
- **Return type/shape:** character path string or empty string (`''`)
- **Current selection behavior:** scans `results/switching/runs/run_*_switching_canonical/tables/<fileName>`, returns newest candidate by `dir(...).datenum`
- **Fallback behavior today:** no layered fallback; pure mtime strategy over candidate files
- **Error behavior today:** soft-fail by returning `''` when no runs root or no matching files; no thrown errors in resolver
- **Warnings today:** none emitted

## Proposed Patch Design

Single-file, helper-free approach inside existing resolver:

1. Keep signature unchanged: `switchingResolveLatestCanonicalTable(repoRoot, fileName)`.
2. Compute identity table path exactly:
   - `fullfile(repoRoot, 'tables', 'switching_canonical_identity.csv')`
3. Attempt identity parse using lightweight CSV read:
   - verify file exists
   - read table with `VariableNamingRule','preserve'` (or equivalent robust parse)
   - verify columns `field` and `value` exist
   - locate row where `field == 'CANONICAL_RUN_ID'`
   - verify extracted value is non-empty
4. Construct anchor path exactly:
   - `fullfile(repoRoot, 'results', 'switching', 'runs', canonicalRunId, 'tables', fileName)`
5. If anchor file exists, return it immediately.
6. If any identity contract check fails, or anchor table missing:
   - emit warning with specific reason (missing identity file, malformed schema, missing row, missing run dir, missing anchor artifact)
   - execute the existing mtime scan logic unchanged.
7. If mtime fallback finds no candidates, preserve current behavior and return `''`.

Validation checks required in resolver logic:

- identity table exists
- `field`/`value` columns exist
- `CANONICAL_RUN_ID` row exists
- run directory exists under `results/switching/runs/<CANONICAL_RUN_ID>`
- requested `tables/<fileName>` exists under anchor run

## Dry-Run Check Plan

Defined checks are recorded in:

- `tables/maintenance_switching_identity_resolver_patch_checks.csv`

Minimum required checks included:

- `identity_table_present`
- `canonical_run_dir_present`
- `S_long_anchor_file_present`
- `phi1_anchor_file_present`
- `resolver_returns_anchor_for_S_long`
- `resolver_returns_anchor_for_phi1`
- `fallback_still_available_when_identity_missing_simulated`

Additional guard checks:

- identity schema/row validation checks
- fallback on missing anchor artifact
- empty-return behavior preserved when no candidates exist

No script execution is performed in this design-review task.

## Consumer Smoke Plan

High-risk smoke candidates (post-patch, non-mutating validation run plan only):

- `Switching/analysis/run_switching_mode_admissibility_audit.m`
- `Switching/analysis/run_switching_backbone_stress_test.m`
- `Switching/analysis/run_switching_observable_mapping_audit.m`

Smoke objectives:

1. Confirm resolver returns anchor-root S_long/phi1 paths when identity contract is valid.
2. Confirm scripts pass initial input existence and schema gates with anchored paths.
3. Confirm no immediate regressions in input-gate table generation/startup path handling.

## Risk Assessment

- **Single-file patch feasibility:** high
- **Signature preservation risk:** low
- **Fallback compatibility risk:** low if mtime fallback is retained with warnings
- **Consumer behavior shift risk:** medium (some flows may have implicitly followed newest-run semantics)
- **Highest concern:** mode-admissibility consumer remains high-risk due to mixed resolver + repo-root mirror dependencies.

Readiness interpretation:

- Patch mechanics are ready.
- Operational confidence requires post-patch smoke checks on high-risk consumers.
- Hard-failure mode is not recommended in first patch; warninged fallback is the safe transition.

## Final Verdicts

DESIGN_REVIEW_COMPLETED = YES  
PATCH_READY = PARTIAL  
SINGLE_FILE_PATCH_CONFIRMED = YES  
SIGNATURE_PRESERVED = YES  
FALLBACK_PRESERVED = YES  
DRY_RUN_CHECKS_DEFINED = YES  
CODE_MODIFIED = NO  
BACKLOG_MUTATED = NO  
SAFE_SCOPE_RESPECTED = YES  
READY_FOR_PATCH = NO
