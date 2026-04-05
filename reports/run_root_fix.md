# Run root contract fix (Phase 4.1)

## Summary

Switching run allocation is centralized on `Switching/utils/switchingCanonicalRunRoot.m` for path construction, `Switching/utils/createSwitchingRunContext.m` for run creation, and a minimal `cfg.beforeManifestWrite` hook in `Aging/utils/createRunContext.m` so `assertSwitchingRunDirCanonical` runs **before** `run_manifest.json` is written.

## Contract

Canonical absolute root (this clone): `C:\Dev\matlab-functions\results\switching\runs` via `repoRoot` + `switchingCanonicalRunRoot(repoRoot)`.

## Status flags

| Flag | Value |
| --- | --- |
| SINGLE_SOURCE_OF_TRUTH | YES |
| BYPASS_POSSIBLE | NO |
| ASSERTION_BEFORE_WRITE | YES |
| SHADOW_ROOTS_FOUND | NO |
| CREATE_RUN_CONTEXT_UNIFIED | YES |
| FAILURE_PATH_CANONICAL | YES |
| RUN_ROOT_FIXED | YES |

Execution detail: `tables/run_root_fix_execution.csv`.
