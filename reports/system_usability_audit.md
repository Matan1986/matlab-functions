# System Usability Audit

Date: 2026-03-31
Scope: Broad read-only usability audit of MATLAB script creation, execution flow, and output usefulness.
Constraints followed: no MATLAB execution, no code fixes.

## Evidence Summary

- Root runnable candidates checked: run_*.m at repo root (30 files)
- Precheck pass/fail: 4 pass, 26 fail
- Validator pass/fail: 6 pass, 24 fail
- Wrapper-named run_*_wrapper.m: 17 files, 0 pass precheck, 0 pass validator
- Run output inventory scanned: 692 run directories under results/*/runs/run_*
- Runs with run-root execution_status.csv: 65
- Runs with at least one CSV and one MD: 424
- Runs with figures: 348
- Runs with figure manifest: 0
- Runs with all target outputs together (status + csv + md + figures or figure manifest): 0
- Recent trend (latest 30 runs): 0 with all target outputs together

## Layer 1: Script Creation Flow

### What works

- A strict contract exists and is explicit in policy docs.
- Script naming and output intent are documented in multiple places.

### Usability blockers

1. Mandatory template is not runnable under current validator.
- docs/repo_execution_rules.md mandates starting from docs/templates/matlab_run_template.m.
- That template defines a function and does not start with clear; clc;.
- Wrapper precheck passes it, then validator blocks it (CHECK_HEADER, CHECK_FUNCTION).

2. Mandatory template has API mismatch with run context helper.
- Template calls [runDir, runId] = createRunContext(...).
- createRunContext returns one struct output (run).
- This likely fails at runtime even before scientific logic.

3. Secondary template is also non-compliant.
- templates/canonical_runnable_script.m fails both precheck and validator.

4. New script pass probability is low without deep system knowledge.
- Only 4/30 root run_*.m pass precheck.
- Only 6/30 pass validator.
- Naming confusion is high: 17/30 are wrapper-named files and all fail both gates.

Verdict for layer 1: current creation flow is not smooth for new authors.

## Layer 2: Execution Flow

### Wrapper behavior

- Good: absolute path + .m checks are enforced.
- Good: failures are explicit (PRECHECK_FAILED, validator reason lines).
- High friction: wrapper uses fixed 300-second timeout while documented workloads include 50-65 minute runs.
- High friction: wrapper docs claim eval(fileread(...)), implementation uses matlab -batch with run(...).
- Drift risk: run discovery falls back to directory scan when run_dir_pointer.txt is missing, but run contract forbids scanning.

### Precheck behavior

- Precheck is fast but brittle (pattern matching only).
- It over-requires writetable for CSV detection, so writecell CSV workflows are blocked.
- Frequent fail reasons in root scripts:
  - no CSV writetable (21)
  - missing createRunContext (20)
  - missing execution_status.csv (20)
  - no .md output (16)

### Validator behavior

- Validator blocks most root scripts (24/30).
- Top failure codes:
  - REQUIRED_OUTPUTS (20)
  - CHECK_RUN_CONTEXT (20)
  - CHECK_DRIFT (20)
  - CHECK_HEADER (19)
- Strictness is inconsistent:
  - strict on header/script form
  - loose on output location/filename semantics (can pass scripts that do not write exact run_dir/execution_status.csv)

Verdict for layer 2: failure feedback is readable, but gating behavior is both overly blocking and internally inconsistent.

## Layer 3: Output Usefulness

### Required research bundle target

Target evaluated:
- execution_status.csv
- at least one CSV table
- report (MD)
- figures OR figure manifest

### Observed state

- No run in scanned inventory has the full target bundle together (0/692).
- Figure manifest was not found in any run (0/692).
- Status-producing runs are mostly table/report audit runs and do not include figures (65 status runs, 0 with figures).
- Recent 30 runs: also 0 complete bundles.

### Practical effect

- Typical run outputs are not immediately handoff-ready for research.
- Users commonly need extra reruns or additional scripts for visuals and full package completeness.

Verdict for layer 3: outputs are partially useful, but default completeness is insufficient for smooth end-to-end research workflow.

## Required Verdicts

- SYSTEM_RUNNABLE_FOR_NEW_SCRIPTS = NO
- PRECHECK_TOO_STRICT = YES
- VALIDATOR_BLOCKING_WORKFLOW = YES
- OUTPUTS_RESEARCH_USEFUL = NO
- FIGURES_GENERATED_BY_DEFAULT = NO
- MAIN_FRICTION_POINT = Template-contract mismatch plus strict precheck/validator gate combo
- READY_FOR_PRODUCTIVE_WORK = NO

## Top 3 Blockers

1. Mandatory template is invalid under validator and mismatched with createRunContext API.
2. Wrapper timeout (300s) is incompatible with documented long-run research durations.
3. Output bundle completeness is effectively zero in current run inventory (no status+csv+md+figures/manifest together).

## Top 3 Strengths

1. Run metadata backbone exists at scale (run_manifest.json, config_snapshot.m, log.txt, run_notes.txt in most runs).
2. Wrapper and validator provide explicit, machine-parseable failure reasons.
3. Canonical run directory convention is heavily adopted under results/<experiment>/runs/run_*.

## Must Fix Immediately

1. Make the mandated template truly validator-compliant and API-correct.
2. Align timeout policy with realistic research runtimes (or make timeout configurable).
3. Unify output contract so one normal run yields status + csv + md + figures/manifest by default.

## Can Wait

1. Tighten validator semantics for exact output location and filename rules.
2. Remove documentation drift (eval(fileread) vs actual wrapper run path).
3. Improve naming and onboarding to separate wrapper/helper files from runnable entry scripts.
