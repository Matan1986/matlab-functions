# MATLAB Execution Reliability Debug

## Failure Classification
PARTIAL_SUCCESS

## 1. What failed
- The approved wrapper `tools/run_matlab_safe.bat` launched MATLAB without `-wait`, so Windows returned control to the caller before MATLAB finished startup/execution.
- In that state, agent-side execution appeared successful (`exit code 0`) but scripts were not reliably completed and output artifacts were not consistently observable.

## 2. What worked
- Direct blocking launch with `matlab -wait -nosplash -nodesktop -r "...; exit;"` executed reliably.
- Required probes succeeded:
  - `probe_success.txt` created with `OK`
  - `probe_pwd.txt` created with current MATLAB `pwd` (`C:\Dev\matlab-functions`)
  - `probe_path_check.txt` created with `2` from `exist('C:/Dev/matlab-functions/test_probe.m','file')`
  - `test_save.mat` created successfully via `save(...)`

## 3. Final working execution method
- Enforced **Option C (temporary wrapper script)** by fixing the approved wrapper to use blocking launch:
  - Updated `tools/run_matlab_safe.bat` to run MATLAB with `-wait`.
- Canonical method for all agents:
  - Invoke the approved wrapper and execute scripts via `eval(fileread(...))`.

## 4. Exact command string to use
`.\tools\run_matlab_safe.bat "eval(fileread('C:/Dev/matlab-functions/<script_name>.m'))"`

