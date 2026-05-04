# SW-STATE-Y — One-shot MATLAB test run (canonical state audit runner)

**Date:** 2026-05-04  
**Runner:** `Switching/analysis/run_switching_canonical_state_audit.m` (untracked; SW-STATE-X comment-only repair).

## Preflight

- `git diff --cached --name-only`: **empty** (proceeded).

## Execution attempts

### 1) Required `eval(fileread(...))` pattern (failed — expected for this file shape)

```text
matlab -wait -batch "eval(fileread('C:/Dev/matlab-functions/Switching/analysis/run_switching_canonical_state_audit.m'))"
```

**Exit code:** **1**  
**MATLAB error:** `Function definitions are not supported in this context` — scripts that **end with local functions** cannot be executed via `eval(fileread(...))`; MATLAB only allows local/nested functions inside a proper code file executed with `run` or by name.

### 2) Blocking execution of the **same file** via `run(...)` (success)

```text
matlab -wait -batch "cd('C:/Dev/matlab-functions'); run('Switching/analysis/run_switching_canonical_state_audit.m')"
```

**Exit code:** **0**  
**Console:**

```text
switching_canonical_state_audit: SUCCESS
Tables: C:\Dev\matlab-functions\tables\switching
Report: C:\Dev\matlab-functions\reports\switching\switching_canonical_state_audit.md
```

This satisfies **one execution** of the intended runner file for validation; the `eval(fileread)` form is **not viable** for this script layout.

## Run directory

| Item | Value |
|------|--------|
| **run_dir** | `results/switching/runs/run_2026_05_04_231550_switching_canonical_state_audit` |
| **execution_status.csv** | **Present** — final row `SUCCESS`, `INPUT_FOUND=YES`, summary `wrote durable canonical state audit tables` |

Also present under `run_dir`: `run_manifest.json`, `config_snapshot.m`, `log.txt`, `execution_probe_top.txt`, copied `tables/switching_canonical_state_status.csv`, copied `reports/switching_canonical_state_audit.md`.

## Durable repo-root outputs (script contract)

Written/updated under:

- `tables/switching/switching_canonical_state_family_inventory.csv`
- `tables/switching/switching_canonical_state_claim_safety_matrix.csv`
- `tables/switching/switching_canonical_state_completed_tests.csv`
- `tables/switching/switching_canonical_state_open_tasks.csv`
- `tables/switching/switching_canonical_state_cross_module_blockers.csv`
- `tables/switching/switching_canonical_state_status.csv`
- `reports/switching/switching_canonical_state_audit.md`

**Note:** The task checklist named files such as `switching_canonical_state_open_questions.csv`, `claim_status`, `verdicts`, etc. — those names **do not match** this runner’s header or outputs. Verification here uses the **actual** filenames above (all present after the successful run).

## Gitignore / tracking

- `tables/**` ignores durable CSV outputs; `reports/**` ignores the markdown report. Outputs **exist on disk** but are **not** tracked unless force-added.

## Figures

- No figure-generation calls in this audit runner path; **no** new Switching figure outputs identified for this run.

## Cross-cutting file modifications

- This run writes **Switching** `tables/switching/`, `reports/switching/`, and `results/switching/runs/...` only.
- Working tree still contains **unrelated** pre-existing `M`/`??` paths (Aging, Relaxation, cross-module, maintenance); **none of those were required or attributable to this single MATLAB invocation** beyond normal Switching run sidecars.

---

*End of report.*
