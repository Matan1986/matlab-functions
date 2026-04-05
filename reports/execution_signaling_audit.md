# Execution Signaling Audit

## Exact template changes
- Top signal added in docs/templates/matlab_run_template.m as first executable block:
  - `fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');`
  - `if fidTopProbe >= 0; fclose(fidTopProbe); end`
- Bottom signal added at script end in docs/templates/matlab_run_template.m:
  - `fidBottomProbe = fopen(fullfile(pwd, 'execution_probe_bottom.txt'), 'w');`
  - `if fidBottomProbe >= 0; fclose(fidBottomProbe); end`

## Exact wrapper condition added
- In tools/run_matlab_safe.bat after MATLAB execution:
  - fail if `C:\Dev\matlab-functions\execution_probe_top.txt` is missing
  - fail if `execution_status.csv` is missing in resolved `RUN_DIR`
  - emit `ARTIFACT_VERIFICATION=PASS` only when both artifacts are present

## One-run validation result
- Command executed once:
  - `tools/run_matlab_safe.bat "C:\Dev\matlab-functions\Switching\analysis\run_switching_canonical.m"`
- Evidence from `tables/execution_signaling_wrapper_run.log`:
  - `MATLAB_EXIT_CODE=0`
  - `ENTRY_SIGNAL_FOUND=NO`
  - `STATUS_ARTIFACT_FOUND=YES`
  - `WRAPPER_EXIT_CODE=9`

## Why this enforces execution truth
The wrapper now treats file artifacts as the source of truth for execution, not MATLAB exit code. If no entry signal exists, the run is rejected even when MATLAB returns 0. This enforces the invariant: no signal means no verified run and therefore no accepted physics output.
