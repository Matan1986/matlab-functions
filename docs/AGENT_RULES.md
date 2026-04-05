# Agent Rules

Use these rules for all analysis and diagnostic work in this repository.

- All outputs must be written to run folders under `results/<experiment>/runs/run_<timestamp>_<label>/`.
- Never commit figures, ZIP archives, or other generated run artifacts.
- Never write outputs inside module directories such as `Aging/`, `Relaxation ver3/`, or `Switching/`.
- Always generate a ZIP archive for sharing results from a completed run.
- Before generating figures, read docs/visualization_rules.md and follow its standards.
- STRICT: Figure naming must follow docs/visualization_rules.md (Figure Window Naming): set figure Name, set NumberTitle off, and keep Name == saved filename base (no title(...) naming).
- Before writing run artifacts, read docs/output_artifacts.md and use only its required artifact directories.
- Analysis scripts must not manage artifact paths directly. Artifact generation should use the repository helpers: save_run_figure, save_run_table, save_run_report.
- Exception: run-level `observables.csv` must remain at run root and should not be moved into `tables/` by `save_run_table`.
- MATLAB execution must use `tools/run_matlab_safe.bat` to avoid startup hangs caused by MathWorks Service Host.

## MATLAB Execution Rules (CRITICAL)

1. All MATLAB execution MUST go through the approved repository wrapper.
   - Direct invocation of `matlab` is not allowed for automated/agent runs.
   - This includes direct `matlab -batch`, direct `matlab -r`, and inline command-string execution styles.

2. Canonical invocation format is script-path only.
   - Use `tools/run_matlab_safe.bat "<ABSOLUTE_PATH_TO_SCRIPT.m>"`.
   - The wrapper launches MATLAB with `-batch` and executes the script via `run('<ABSOLUTE_PATH_TO_SCRIPT.m>')` (see `tools/run_matlab_safe.bat`). Optional: run `tools/validate_matlab_runnable.ps1` separately for diagnostics; the wrapper does not block on it.

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

4. Optional preflight validation (non-blocking).
   - Agents may run `tools/validate_matlab_runnable.ps1` before MATLAB for structured checks.
   - The batch wrapper does not invoke the validator; failures there do not block the wrapper.

## Agent Types

### Infrastructure Agents
- May modify: environment, setup, and documentation.
- Must run SERIAL ONLY (no concurrent infrastructure agents).
- Must NOT run in parallel with other infrastructure agents.
- Must NOT change MATLAB execution behavior outside of the approved rules.
- Before changing wrappers, run helpers, manifest writers, path resolution, or shared execution behavior: produce the pre-change report in docs/infrastructure_laws.md (PART 3: EXISTING_SYSTEMS_FOUND, CANONICAL_COMPONENT, DUPLICATION_RISK, REUSE_PLAN, FILES_TO_TOUCH, WHY_NEW_SYSTEM_IS_NOT_BEING_CREATED).
- Must not introduce a parallel run root convention, parallel manifest system, or parallel fingerprint scheme; see docs/infrastructure_laws.md (PART 1 and PART 2).

### Analysis Agents
- May run in parallel.
- Must NOT modify: environment, MATLAB execution method, or repository structure.
- Must operate in read-only mode for infrastructure (no execution-method changes, no wrapper/path changes).

## Documentation Precedence

When repository documents overlap, use this precedence order:

1. docs/AGENT_RULES.md for agent behavior and repository safety limits.
1a. docs/infrastructure_laws.md for infrastructure architecture only: canonical run roots, `run_manifest.json` and fingerprint fields, execution entrypoints (`run_matlab_safe.bat`), output ownership, drift violations, and consolidation gates. When this document conflicts with informal mentions elsewhere, infrastructure_laws wins for those topics.
1b. docs/system_master_plan.md for program lifecycle phases (0–6), phase-entry gates, module Type A/B model, cross-module canonical participation rule, and trust terminology (execution vs system vs isolation). When narrative elsewhere implies "closure" or "safe to proceed" without a domain, defer to this document.
2. docs/results_system.md for output locations and run artifact layout.
3. docs/run_system.md for run creation and run-context invariants.
4. docs/repository_structure.md for code placement and repository layout.
5. docs/output_artifacts.md for artifact subfolder usage within a run.
6. docs/agent_prompt_exclude.md lists documents that must **not** be bulk-loaded into agent prompts unless the task names them explicitly.

- Versioned folders (for example `* verX`) must NOT be assumed legacy or inactive based on naming alone.

## Architecture Alignment Policy

Not all modules in the repository are fully aligned with the current
architecture (pipeline / analysis / utils / run-based results).

Modules may gradually be aligned with the new architecture when they are
actively modified. Agents must not perform repository-wide refactors
to enforce architectural alignment.

Agents must not rename, relocate, normalize, or reorganize unrelated
modules, legacy folders, or directory trees unless the task explicitly
requires it.

## Legacy Visualization Code

Agents must not reuse visualization or figure post-processing utilities
from `General ver2/` in new development.

`General ver2/` is preserved for reproducibility only. All new figures
must follow `docs/figure_style_guide.md`.

## Visualization Helpers

All figure exports must go through `tools/save_run_figure.m`.

New figures should be created with `tools/figures/create_figure.m` when possible.

Visualization helpers must reside in `tools/figures/`.

## Agent Output Template

When reporting repository changes, use this structure:

Changes made

- repository policy or behavior changes
- documentation updates

Scripts modified

- list of modified scripts or helpers

Artifacts removed or relocated

- removed output folders or generated artifacts

Verification

- checks performed such as `git status`, path verification, or run-folder validation

Agents should keep reports concise and avoid repeating repository context that is already documented in repository_structure.md or results_system.md.
## System Registry (Authoritative Source)

`docs/system_registry.json` is the authoritative source for:

- module classification
- pipeline grouping
- system structure

All documentation MUST be consistent with this registry.

## Structural Change Gate (STRICT)

Any structural change task is COMPLETE only if ALL conditions are satisfied:

1. Registry update (if needed):

   * `docs/system_registry.json` reflects the current system structure

2. Registry <-> filesystem consistency:

   * All active folders == `system_registry.json["active_modules"]`
   * No extra or missing active modules

3. Documentation sync:

   * `docs/repository_map.md`
   * `docs/root_inventory_table.md`
   * `docs/snapshot_system_design.md`
     are consistent with `docs/system_registry.json`

4. Snapshot consistency:

   * Snapshot includes all modules required by `docs/system_registry.json`

If ANY condition fails:
-> Task is NOT complete

## Context Bundle Usage (Required)

- Read `docs/context_bundle.json` before starting.
- Optional: use `docs/context_bundle_full.json` for ChatGPT/analysis.
- Workflow: `RUN → SNAPSHOT → CONTEXT → TASK`.
