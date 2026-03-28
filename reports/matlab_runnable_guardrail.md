# MATLAB Runnable Guardrail Report

## Rule Added

Added a strict **MATLAB Runnable Script Contract** to `docs/AGENT_RULES.md`:

- Runnable scripts executed through `tools/run_matlab_safe.bat` must be pure scripts.
- Forbidden in runnable scripts: any `function` definitions (including local/nested forms).
- Helper logic must be moved to separate helper `.m` files.
- Runnable scripts must write outputs and explicit status/error artifacts.
- Preflight validation is mandatory before MATLAB launch.

## Invalid Script Detection

Detection is implemented in `tools/validate_matlab_runnable.ps1`:

- Input: path to runnable `.m` file.
- Fails (nonzero exit) if any line matches `^\s*function\b`.
- Validates that target exists and has `.m` extension.
- Optionally checks for top-level `try` and `catch`; if missing, emits warning (does not fail).
- Produces clear validator messages for success/failure.

## Execution Blocking Mechanism

`tools/run_matlab_safe.bat` now enforces validator preflight before launching MATLAB:

- Runs `tools/validate_matlab_runnable.ps1` on the requested runnable script.
- If validation fails, wrapper refuses execution (returns nonzero and exits before MATLAB invocation).
- Writes a clear precheck failure message into `matlab_error.log`.

## Canonical Templates Added

- `templates/canonical_runnable_script.m`: pure script template with output and status/error artifact pattern.
- `templates/canonical_helper_function.m`: helper-function template for logic that must not be inside runnable scripts.

## Exact Files Changed

- `docs/AGENT_RULES.md`
- `tools/validate_matlab_runnable.ps1`
- `tools/run_matlab_safe.bat`
- `templates/canonical_runnable_script.m`
- `templates/canonical_helper_function.m`
- `reports/matlab_runnable_guardrail.md`
