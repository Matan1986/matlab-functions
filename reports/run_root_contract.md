# Run root contract (Switching)

## Canonical run root

Absolute path:

`C:\Dev\matlab-functions\results\switching\runs`

Repository-relative:

`results/switching/runs`

## Rules

- All new Switching `run_dir` allocations go through `createRunContext('switching', cfg)` so `run_manifest.json` records a `run_dir` under this root.
- Do not allocate run folders from the current working directory or ad hoc alternate `results/...` subfolders for Switching runs.
- `Switching/utils/switchingCanonicalRunRoot.m` is the single helper for the canonical root path; `Switching/utils/assertSwitchingRunDirCanonical.m` validates `run.run_dir` for canonical scripts that require it.

## Status

`RUN_ROOT_FORMALIZED=YES`
