# Repository execution rules (MATLAB)

This document is the canonical reference for **strict MATLAB execution behavior** for all agents and automation in this repository. It does not replace other policy documents; when documents overlap, follow the precedence order in `docs/AGENT_RULES.md` (Documentation Precedence).

## Infrastructure laws (normative)

- Canonical run roots, manifest (`run_manifest.json`), execution fingerprints, output ownership, drift taxonomy, and consolidation gates are defined in `docs/infrastructure_laws.md`.
- Infrastructure agents must not create parallel execution stacks, manifest systems, or fingerprint conventions; see PART 1-2 of that document.
- Automated MATLAB runs use **one** wrapper entrypoint: `tools/run_matlab_safe.bat` (PART 1, execution entrypoint).

## MATLAB Execution Rules (STRICT)

- MATLAB execution must use `tools/run_matlab_safe.bat` to avoid startup hangs caused by MathWorks Service Host.

## EXECUTION GUARDRAILS (FROM REAL FAILURES)

These guardrails come from real Windows CMD + MATLAB failures. They preserve the **correct mental model** for agents and **do not** prescribe a different execution flow than the one already in use. When infrastructure is **INFRA_STABLE**, treat them as non-negotiable hygiene.

### Explicit MATLAB invocation (Windows CMD)

- Invoke MATLAB with a **fully explicit** path to `matlab.exe` and a **literal** `-batch` argument on the command line (example shape: `"C:\Program Files\MATLAB\R20xx\bin\matlab.exe" -batch "run('...');"`).
- **Do not** execute the batch step by stuffing the whole `-batch` string into a `%VARIABLE%` and expanding it for the call in ways that obscure quoting.
- **CMD parentheses pitfall:** Do not put MATLAB code that contains **`(` `)`** (e.g. `pause(1)`) inside **CMD-expanded** variables used to build the command line. Parentheses are special in `cmd.exe`; after `%VAR%` expansion, the line can be re-parsed incorrectly and MATLAB never receives the intended `-batch` command.

### Debug layer order (procedure only)

When **diagnosing** why a run failed, reason about evidence in this order:

1. **MATLAB_ALIVE** — MATLAB starts and `-batch` actually runs (e.g. a trivial `disp`).
2. **RUNNER_ENTERED** — Any minimal runner/probe used by the workflow runs and can prove disk I/O if applicable.
3. **SCRIPT_ENTERED** — The intended script is entered (e.g. an explicit early `disp` in the canonical script).
4. **WRITE_SUCCESS** — Required artifacts exist (e.g. `execution_status.csv`, `run_dir` per the signaling contract).

### Do not debug deeper before the current layer is proven

If MATLAB does not launch or `-batch` does not execute, fix invocation, path to `matlab.exe`, and quoting **before** investigating repo layout, runner files, or pipeline logic. If the canonical script never enters, fix entry and paths **before** debugging computations or observables. If writes do not occur, fix `run_dir` and status output **before** interpreting science results.

### Layer verification vs. execution architecture

**Layer verification is a DEBUG PROCEDURE, not an execution architecture.** It describes how to triage and narrate failures. It does **not** require multiple MATLAB processes, staged steps inside the wrapper, or extra orchestration layers in repository tooling.

### Single-call wrapper (STRICT)

The approved wrapper **MUST** remain a **single** MATLAB invocation per run, in the canonical form:

`matlab.exe -batch "run('<ABSOLUTE_PATH_TO_SCRIPT.m>');"`

- **Do not** add multi-stage execution inside `tools/run_matlab_safe.bat` (no chained MATLAB calls, no mandatory “probe then main” sequences in the batch file).
- **Do not** turn the wrapper into an orchestrator for layered probes or staged execution.

Agents must not “fix” ambiguity by adding wrapper orchestration; align documentation and debugging practice instead.

## Execution Signaling Contract

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
→ fail fast and surface errors explicitly (no fallback behavior)
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

---

## Phase 7 Closure — Canonical Execution and Failure Semantics

Phase 7 is formally closed. Canonical execution and failure semantics are now locked as repository system truth.

### Canonical execution lock

- Canonical execution mode is **wrapper only**.
- Canonical entrypoint is `tools/run_matlab_safe.bat`.
- Non-wrapper automated execution is forbidden.

### Allowed mode

- Wrapper-mediated runnable script execution only.

### Forbidden modes

- direct `matlab -batch`
- inline execution
- `run()` outside wrapper

### Failure semantics lock

- Canonical failure semantics are: `catch -> write FAILED -> rethrow`.
- Canonical runs must produce run-scoped `execution_status.csv` and a report (`.md`) artifact.
- No silent success paths are permitted.

### Closure status

- `EXECUTION_MODE_LOCKED = YES`
- `PIPELINE_AUDITED = YES`
- `FAILURE_PROPAGATION_PROVEN = YES`
- `PIPELINE_TRUSTWORTHY = YES`
- `PHASE7_CLOSED = YES`
