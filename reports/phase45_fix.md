# Phase 4.5 fix — preserve `modules_used_input` through entrypoint

## Change

In `Switching/analysis/run_switching_canonical.m`, the script header was updated from `clear; clc;` to:

- `clearvars -except modules_used_input`
- `clc`

So `modules_used_input` set before `run(...)` is not cleared at script start, allowing cross-module override/enforcement to see the variable.

## Status

| Key | Value |
|-----|-------|
| PHASE45_FIX_APPLIED | YES |
| OVERRIDE_REACHABLE | YES |
| NO_BEHAVIOR_CHANGE_SWITCHING_ONLY | YES |

See `tables/phase45_fix_status.csv`.
