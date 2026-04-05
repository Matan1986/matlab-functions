# MATLAB Batch Execution Probe

## Scope
- Single-file execution-layer probe only in `tools/run_matlab_safe.bat`.
- No changes to scientific code, Switching logic, validators, templates, or pipeline definitions.

## Batch Command String
- BEFORE change:
  - `eval(fileread('<absolute_script_path>')); exit;`
- AFTER change:
  - `disp('BATCH_ENTRY_OK'); eval(fileread('<absolute_script_path>')); exit;`

## Diagnostic Observation
- Diagnostic output token `BATCH_ENTRY_OK` was **not** observed in:
  - wrapper console output captured in the run command response,
  - run log file `results/switching/runs/run_2026_04_02_114946_switching_canonical/log.txt`,
  - workspace text search.

## Post-Run Evidence
- Script body execution evidence was observed in:
  - `results/switching/runs/run_2026_04_02_114946_switching_canonical/execution_probe_status.csv`
  - `results/switching/runs/run_2026_04_02_114946_switching_canonical/execution_status.csv` (`SUCCESS`)
  - `results/switching/runs/run_2026_04_02_114946_switching_canonical/execution_probe.csv`

## Conclusion
MATLAB **does execute** the `-batch` command string (proven by script-produced artifacts), but diagnostic `disp()` output is not visible through the current wrapper-observed output channels.

## Next Step
Debug only the MATLAB stdout/stderr capture boundary in wrapper process launch/capture path.
