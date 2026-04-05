# Phase 4.5 Step 1 — Registry activation

## Summary

The canonical Switching entrypoint (`Switching/analysis/run_switching_canonical.m`) now loads `tables/module_canonical_status.csv` via the single helper `tools/loadModuleCanonicalStatus.m` and fails early unless **Switching** is present with **STATUS=CANONICAL**.

## Artifacts

| Item | Detail |
|------|--------|
| Registry | `tables/module_canonical_status.csv` |
| Loader | `tools/loadModuleCanonicalStatus.m` (no cache, no globals, one path: `repoRoot/tables/module_canonical_status.csv`) |
| Entrypoint check | After path setup, before legacy backend paths |

## Status

| Key | Value |
|-----|-------|
| PHASE45_STEP1_COMPLETE | YES |
| REGISTRY_CONNECTED_TO_ENTRYPOINT | YES |
| REGISTRY_RUNTIME_READ | YES |
| ENTRYPOINT_VALIDATED_AGAINST_REGISTRY | YES |

## Scope note

Cross-module enforcement (`assertModulesCanonical` on multiple modules) is **not** part of this step; only registry read + Switching row validation on the canonical path.
