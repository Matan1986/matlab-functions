# Execution Entry Fix Audit

## Scope
- Target script: C:\Dev\matlab-functions\Switching\analysis\run_switching_canonical.m
- Wrapper: tools/run_matlab_safe.bat
- Phase constraint honored: Switching-only execution-entry debugging; no scientific logic or pipeline definitions changed.

## File Changed
- tools/run_matlab_safe.bat

## Entry Method Change
- Old entry method: `cd('<scriptDir>'); run('<scriptName>'); exit;`
- New entry method: `eval(fileread('<absolute_script_path>')); exit;`

## Minimal Rationale
The prior entry used a leaf-name `run(...)` call after `cd(...)`, which is vulnerable to invocation ambiguity at MATLAB batch-entry boundaries; replacing only this command with an absolute-path `eval(fileread(...))` is the narrowest auditable change that targets execution entry directly while leaving validator behavior, fingerprint flow, and all scientific/pipeline logic untouched.

## Post-Fix Focused Validation (Single Run)
- Command run once via wrapper:
  - tools/run_matlab_safe.bat "C:\Dev\matlab-functions\Switching\analysis\run_switching_canonical.m"
- Observed evidence:
  - Wrapper precheck refreshed for target script at `2026-04-02 11:47:24` in `tables/wrapper_soft_gate_status.csv`.
  - Wrapper output reached MATLAB launch line for the target script.
  - No `C:\Dev\matlab-functions\execution_probe_top.txt`.
  - No `C:\Dev\matlab-functions\run_dir_pointer.txt`.
  - No `results/switching/runs/**/execution_status.csv`.

## Final Verdict
- Script body entry after this minimal entry-method fix: **NOT ACHIEVED**.
- Next exact blocker localization: MATLAB was reached, but script invocation still failed before earliest in-script probe artifacts were written (pre-entry eval/invocation layer remains the blocker).
