# run_switching_canonical fix report

- Target script: `Switching/analysis/run_switching_canonical.m`
- Scope honored: only this script was modified.
- Validation command executed exactly once:
  - `tools/run_matlab_safe.bat "C:\Dev\matlab-functions\Switching\analysis\run_switching_canonical.m"`

## Exact lines added/modified
- `1: clear; clc;`
- `2: fid = fopen('execution_probe_top.txt','w'); fclose(fid);`
- `49: ctx = createRunContext('Switching', cfg);`
- `50: run = ctx;`
- Removed the `save(... switching_canonical_artifacts.mat ...)` block to satisfy the strict output-type drift constraint.

## Scientific logic change check
- No physics, Phi1/kappa1 derivation, reconstruction equations, or upstream data-flow math was modified.
- Only execution signaling/contract surface was adjusted.

## Run directory
- Generated run_dir in the single required run: `NA` (wrapper validator blocked MATLAB execution before run context creation).

## Final verdict
- Script is now canonical: `NO` (blocked by wrapper validation result from the single allowed run).
