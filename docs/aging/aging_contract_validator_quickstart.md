# Aging contract validator (F6U) — quickstart

**Script:** `Aging/validation/run_aging_contract_validator_audit_only.m`  
**Mode:** `audit_only` only (non-blocking, agent-assistive).

## Run (repository wrapper)

From the repo root, use the canonical MATLAB wrapper (see `docs/repo_execution_rules.md`):

`tools/run_matlab_safe.bat "<ABSOLUTE_PATH_TO_Aging/validation/run_aging_contract_validator_audit_only.m>"`

The validator script intentionally omits `clear` / `clc` so `matlab -batch` and the wrapper do not block on console control (see script header comment).

## Scan limits (pragmatic)

The scan caps directory visits, CSV count (500 total, 150 per root), JSON sidecar size (512 KB), and skips common vendor folders (`.git`, `slprj`, etc.). Tune constants at the top of `run_aging_contract_validator_audit_only.m` if needed.

## Git note

`tables/**` is ignored by default in this repository; F6U CSV outputs are still written on disk for local audits even when they do not appear in `git status`.

## Outputs

| Artifact | Path |
|----------|------|
| Issue log | `tables/aging/aging_F6U_contract_validator_issue_log.csv` |
| Per-file summary | `tables/aging/aging_F6U_contract_validator_file_summary.csv` |
| Per-check summary | `tables/aging/aging_F6U_contract_validator_check_summary.csv` |
| Status / verdicts | `tables/aging/aging_F6U_contract_validator_status.csv` |
| Report | `reports/aging/aging_F6U_audit_only_contract_validator_report.md` |

## Behavior

- Scans Aging-only roots (`tables/aging`, `reports/aging`, `results/aging`, `results_old/aging`, `Aging/`).
- Never modifies scientific outputs; writes validator CSVs and one markdown report only.
- Does not throw on contract violations; every row includes `suggested_fix` and `blocks_execution = NO`.

## Helpers

`Aging/validation/aging_F6U_validator_utils.m` contains parsing and path utilities used by the validator script.
