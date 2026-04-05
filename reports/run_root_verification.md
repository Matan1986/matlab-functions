# Run root contract verification (Switching only)

Read-only audit. No repository files were modified for this report.

## Verdict

Not all checks pass. **`RUN_ROOT_VERIFIED=NO`**, **`PHASE_4.1_CLOSED=NO`**.

## Check results

| Check | Result |
| --- | --- |
| SINGLE_SOURCE_OF_TRUTH | NO |
| HARD_CODED_PATHS_FOUND | NON_EMPTY (Switching/analysis; see CSV) |
| ENFORCEMENT_PRESENT | YES |
| ENFORCEMENT_STRICT | YES |
| BYPASS_POSSIBLE | YES |
| ASSERTION_BEFORE_WRITE | NO |
| SHADOW_ROOTS_FOUND | YES |
| CREATE_RUN_CONTEXT_UNIFIED | NO |
| FAILURE_PATH_CANONICAL | YES |
| MANIFEST_CANONICAL | NO |

## Notes

- **Single source / hardcoded paths:** `switchingCanonicalRunRoot.m` is not the only place the canonical path appears; many scripts build `fullfile(repoRoot,'results','switching','runs')` directly, and numerous analysis scripts embed absolute `C:/Dev/matlab-functions/...` paths.
- **Assertion timing:** `createRunContext` writes the manifest and other run files before control returns; the assertion runs afterward, so it cannot block manifest creation.
- **Bypass:** Assertion is only wired into two scripts; other Switching analysis entry points can allocate runs without it.
- **Non-unified createRunContext:** `run_prediction_falsification_test.m` uses experiment tag `cross_experiment`, producing manifests and run dirs outside `results/switching/runs`.

Machine-readable detail: `tables/run_root_verification.csv`.
