# Repository execution rules (MATLAB)

This document is the canonical reference for **strict MATLAB execution behavior** for all agents and automation in this repository. It does not replace other policy documents; when documents overlap, follow the precedence order in `docs/AGENT_RULES.md` (Documentation Precedence).

## Infrastructure laws (normative)

- Canonical run roots, manifest (`run_manifest.json`), execution fingerprints, output ownership, drift taxonomy, and consolidation gates are defined in `docs/infrastructure_laws.md`.
- Infrastructure agents must not create parallel execution stacks, manifest systems, or fingerprint conventions; see PART 1-2 of that document.
- Automated MATLAB runs use **one** wrapper entrypoint: `tools/run_matlab_safe.bat` (PART 1, execution entrypoint).

## MATLAB Execution Rules (STRICT)

- MATLAB execution must use `tools/run_matlab_safe.bat` to avoid startup hangs caused by MathWorks Service Host.

1. All MATLAB execution MUST go through the approved repository wrapper.
   - Direct invocation of `matlab` is not allowed for automated/agent runs.
   - This includes direct `matlab -batch`, direct `matlab -r`, and inline command-string execution styles.

2. Canonical invocation format is script-path only.
   - Use `tools/run_matlab_safe.bat "<ABSOLUTE_PATH_TO_SCRIPT.m>"`.
   - The wrapper validates the runnable script contract and executes it via `eval(fileread(...))`.

3. No parallel infrastructure modifications are allowed.
   - This includes changes that alter execution behavior (MATLAB invocation method, wrapper/launcher, environment configuration, path setup, or related scripts).

4. Infrastructure changes MUST be executed SERIAL ONLY.
   - Only one infrastructure agent may run at a time.

5. Analysis agents are READ-ONLY with respect to infrastructure.
   - They may create runs and write outputs under `results/<experiment>/runs/run_<timestamp>_<label>/`.
   - They must NOT modify system files, environment configuration, or execution behavior.

## MATLAB Runnable Script Contract (STRICT)

Any runnable MATLAB script that is executed via `tools/run_matlab_safe.bat` must satisfy all of the following:

1. Runnable file must be a PURE SCRIPT.
   - Forbidden in runnable scripts: `function` definitions of any kind.
   - This includes local functions and nested functions.

2. Helper logic must live in separate `.m` helper files.
   - Runnable scripts may call helpers, but must not define helper functions inline.

3. Runnable scripts must write outputs and explicit error/status artifacts.
   - Scripts should persist intended outputs and write clear status/error artifacts for failure diagnosis.

4. Preflight validation is mandatory.
   - `tools/run_matlab_safe.bat` must validate runnable script structure before launching MATLAB.
   - Invalid runnable scripts must be blocked before execution.

### ASCII SAFETY (MANDATORY)

- All MATLAB scripts MUST be ASCII-only.
- No Unicode characters are allowed.
- No smart quotes:
  - `“` `”` -> replace with `"`
  - `‘` `’` -> replace with `'`
- No special dashes:
  - `–` `—` -> replace with `-`
- No invisible characters (zero-width, BOM, etc).
- Files must be saved as:
  - UTF-8 WITHOUT BOM or pure ASCII

Before ANY MATLAB execution:
- Agents MUST verify:
  - `NON_ASCII_COUNT = 0`

If `NON_ASCII_COUNT > 0`:
- STOP
- CLEAN FILE
- DO NOT RUN

Every MATLAB script MUST begin with:
- `clear; clc;`

Invalid text character errors from MATLAB `eval(fileread(...))` are caused by non-ASCII characters.
This rule prevents execution failures.

---

## MATLAB Execution Master Policy (ENFORCED)

The following policy is mandatory for all MATLAB agents. This overrides any softer behavioral patterns.

```
You are a MATLAB execution agent working inside a strict repository environment.

You MUST follow these rules exactly. Any deviation is a failure.

========================
EXECUTION RULES (HARD)
========================

1. You must create EXACTLY ONE MATLAB script file.
   - Script only (no functions)
   - No helper files
   - No multiple scripts

2. You must run EXACTLY ONE execution command:
   tools/run_matlab_safe.bat <ABSOLUTE_PATH_TO_SCRIPT.m>

3. The script must be executed using:
   eval(fileread('<ABSOLUTE_PATH_TO_SCRIPT.m>'))

4. Do NOT use:
   - direct matlab invocation (`matlab -batch`, `matlab -r`)
   - inline commands passed to wrapper
   - multiple runs
   - background execution

5. Use ABSOLUTE PATHS only.

6. You must NOT use:
   - innerjoin
   - implicit table alignment

   Instead:
   → perform MANUAL alignment using T_K matching.

7. Column detection must use contains() only.

========================
OUTPUT RULES (MANDATORY)
========================

You must ALWAYS write ALL outputs:

- CSV table
- Markdown report
- Status CSV

Even if:
- input is missing
- execution fails
- data is empty

Never exit silently.

========================
FAILURE HANDLING
========================

You are allowed:

- ONE execution attempt
- ONE debug attempt

After that:

→ STOP
→ WRITE outputs
→ REPORT failure

You are NOT allowed to:
- loop fixes
- retry indefinitely
- modify code repeatedly

========================
INPUT POLICY
========================

- Do NOT scan entire repository
- Only search relevant folders
- If no input found:
  → write empty outputs
  → set INPUT_FOUND = NO

========================
SCRIPT COMPLEXITY RULE
========================

Start minimal.

If a method is unstable:
→ skip or fallback
→ do NOT block execution

========================
STATUS FILE (REQUIRED)
========================

EXECUTION_STATUS
INPUT_FOUND
ERROR_MESSAGE
N_T
MAIN_RESULT_SUMMARY

========================
SUCCESS DEFINITION
========================

Execution is SUCCESS if:
- script ran
- files were written

Even if results are partial.

========================
PRINCIPLE
========================

Execution > Perfection
```

---

### CRITICAL: Distinction between R variables

There are TWO different R variables in this repository:

1. Relaxation:
   R_relax(T,t) = -dM/dlog(t)
   -> time-dependent dynamics

2. Aging:
   R_age(T)
   -> scalar ratio of times

Rules:

* Any time-dependent quantity MUST be named R_relax
* Any scalar aging quantity MUST be named R_age
* Using plain "R" in NEW code is FORBIDDEN
* Legacy code using "R" is allowed but must be explicitly clarified

---

### MANDATORY MATLAB SCRIPT TEMPLATE

All runnable MATLAB scripts MUST:

1. Start from:
   `docs/templates/matlab_run_template.m`

2. Include:
   - `createRunContext(...)`
   - `runDir` usage

3. MUST write:
   - `execution_status.csv`
   - at least one CSV result table
   - at least one `.md` report

4. MUST use:
   `catch ME`
   `rethrow(ME);`
   `end`

5. MUST NOT include:
   - silent catch
   - debug prints left in final form
   - interactive input
   - fallback logic

Violation of ANY rule:

-> SCRIPT INVALID
-> WILL FAIL VALIDATOR
-> MUST NOT BE USED

All future agent prompts MUST include:

Start from:
`docs/templates/matlab_run_template.m`

Any script not based on template is invalid by definition.
