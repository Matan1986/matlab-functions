# Template: FIX

**Context (required):** Read `docs/repo_context_minimal.md` first.

## Rules

- Infrastructure or docs only if that is the task; no science edits unless explicitly requested.
- Non-blocking: prefer warnings + log rows over hard gates.

## After change

- Append `tables/agent_runs_log.csv` with `failure_class=NONE` if verification succeeded, else classify per `docs/execution_failure_classification.md`.
