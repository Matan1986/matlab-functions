# Phase 4.5 Step 2 — Minimal cross-module enforcement

## Summary

The canonical Switching entrypoint (`Switching/analysis/run_switching_canonical.m`) defines a local `modules_used` cell array and, **only when** `length(modules_used) > 1`, calls `assertModulesCanonical(modules_used)` immediately after registry validation and before legacy backend setup. Switching-only runs keep `modules_used = {'Switching'}`, so the assertion is not invoked and behavior is unchanged.

## Artifacts

| Item | Detail |
|------|--------|
| Enforcement helper | `Switching/utils/assertModulesCanonical.m` |
| Single entrypoint hook | After `loadModuleCanonicalStatus` / Switching CANONICAL check; before `legacyRoot` and analysis |

## Status

| Key | Value |
|-----|-------|
| PHASE45_STEP2_COMPLETE | YES |
| ENFORCEMENT_ACTIVE | YES |
| SWITCHING_ONLY_SAFE | YES |
| NO_OVERREGULATION | YES |

## Scope note

`modules_used` is local to the entrypoint only. Future multi-module entrypoints can set `modules_used` to more than one module name here to activate cross-module canonical enforcement without touching loaders or analysis scripts.
