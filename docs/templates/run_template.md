# Template: RUN

**Context (required):** Read `docs/repo_context_minimal.md` first. Do not attach `docs/agent_prompt_exclude.md` paths unless named by the task.

## Goal

- One MATLAB run via `tools/run_matlab_safe.bat "<ABSOLUTE_PATH_TO_SCRIPT.m>"`.
- One script file; outputs only under `run_dir` from `createRunContext`.

## Report back

- `run_dir` path
- `execution_status.csv` outcome (see `docs/execution_status_schema.md`)
- `failure_class` for `tables/agent_runs_log.csv` (see `docs/execution_failure_classification.md`)
