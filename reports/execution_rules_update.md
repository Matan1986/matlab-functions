# Execution Rules Update

## Exact text added to repo_execution_rules.md

### Execution Signaling Contract
A MATLAB run is considered valid if and only if all of the following are true:
1. `execution_probe_top.txt` exists and proves script entry.
2. `execution_status.csv` exists and records the mandatory execution status artifact.
3. `run_dir` is created and referenced, establishing run identity.

The following are not valid indicators of execution:
- MATLAB exit code
- Console output or `disp()`
- Wrapper completion

Rule: `NO SIGNAL -> NO RUN -> NO PHYSICS`

All runnable scripts must emit the entry signal at the top and write the required outputs before completion.

## Exact comment block added to matlab_run_template.m

```matlab
% Execution signaling contract:
% - execution_probe_top.txt is proof of script entry.
% - execution_probe_bottom.txt is proof of completion and is optional but recommended.
% - execution_status.csv is a mandatory artifact.
% Scripts that do not emit execution signals are considered non-executed,
% even if MATLAB exits successfully.
```

## Why this removes ambiguity
Execution truth is now defined by artifacts, not by exit code or console output. That makes the contract checkable and unambiguous for both automation and human review.
