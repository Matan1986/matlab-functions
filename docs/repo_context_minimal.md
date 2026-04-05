# Repository context (minimal — Switching infrastructure)

ASCII only. Read this before any Switching infra or execution task.

## Canonical boundary

- **Canonical Switching runner (full pipeline):** `Switching/analysis/run_switching_canonical.m` — defines trusted observable construction and run-scoped outputs when executed successfully.
- **Minimal path / wiring proof:** `Switching/analysis/run_minimal_canonical.m` — smaller surface area; useful for wrapper and artifact checks.
- **Legacy computation stack:** `Switching ver12/` (on path from the canonical runner). Do not treat as independent canonical definitions; use `docs/switching_canonical_definition.md` for extracted definitions.

## Allowed sources

- **Execution:** `tools/run_matlab_safe.bat` with one absolute path to a `.m` script (see `docs/repo_execution_rules.md`, `docs/infrastructure_laws.md`).
- **Run factory:** `Aging/utils/createRunContext.m` — creates `results/<experiment>/runs/run_<timestamp>_<label>/`, manifest, logs.
- **Policies:** `docs/AGENT_RULES.md` (precedence), `docs/run_system.md` (strict run contract where adopted), `docs/results_system.md`, `docs/output_artifacts.md`.

## Forbidden sources (for new infra work)

- Direct `matlab -batch` / `matlab -r` from agents (bypassing the wrapper).
- New global sinks: repo-root `tables/`, `reports/`, `figures/` as primary outputs for agent analyses (`docs/infrastructure_laws.md`).
- Parallel edits to wrappers, `createRunContext`, or validators (serial infra rule).

## Required artifacts (signaling)

Per `docs/repo_execution_rules.md`, a valid automated run should leave traceable evidence: script entry proof, `execution_status.csv`, and a defined `run_dir`.

**`execution_status.csv` columns (single schema):** `docs/execution_status_schema.md` and `docs/run_system.md` section 3.

**No** repository-root `run_dir_pointer.txt` — deprecated (parallel-safe run identity via `run_dir/run_manifest.json` only).

## Observability (append-only, non-blocking)

- **`tables/agent_runs_log.csv`:** timestamp, script, run_dir, run_valid, failure_class — see `docs/execution_failure_classification.md`.
- **`tables/agent_warnings_log.csv`:** soft issues (non-canonical inputs, missing artifacts, soft violations).
- **`tables/pre_execution_failure_log.csv`:** wrapper guard failures (`PRE_EXECUTION_INVALID_SCRIPT`); written only when MATLAB was not started.

## Prompt templates

- `docs/templates/run_template.md`, `audit_template.md`, `fix_template.md`, `plan_template.md` — each starts by pointing here.

## Current phase

- **Execution entry:** `tools/run_matlab_safe.bat` -> `matlab -batch "run('<absolute_script_path>')"`.
- **Agent prompt scope:** Do not bulk-load documents listed in `docs/agent_prompt_exclude.md`.
- **Switching focus:** Infrastructure, traceability, and agent guidance; scientific Aging/Relaxation pipelines are out of scope for this context file.
