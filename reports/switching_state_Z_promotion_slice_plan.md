# SW-STATE-Z — Promotion slice for canonical state audit runner

**Date:** 2026-05-04  
**Mode:** Audit/planning only — **no** stage / commit / push / MATLAB.

## Preflight

- `git diff --cached --name-only`: **empty** — proceeded.

## Inventory (SW-STATE-X / SW-STATE-Y / validation run)

| Bucket | Paths | Git visibility |
|--------|--------|----------------|
| **Repaired runner** | `Switching/analysis/run_switching_canonical_state_audit.m` | **Untracked** (`??`) — not ignored |
| **X audit** | `reports/switching_state_X_runner_semantic_repair.md`, `tables/switching_state_X_changes.csv`, `tables/switching_state_X_status.csv` | **Ignored** (`reports/**`, `tables/**`) — requires **`git add -f`** |
| **Y audit** | `reports/switching_state_Y_runner_test_run.md`, `tables/switching_state_Y_outputs.csv`, `tables/switching_state_Y_status.csv` | **Ignored** — **`git add -f`** |
| **Durable canonical-state outputs** | Six CSV under `tables/switching/` + `reports/switching/switching_canonical_state_audit.md` | **Ignored** — **`git add -f`** |
| **Run directory sidecars** | `results/switching/runs/run_2026_05_04_231550_switching_canonical_state_audit/` (manifest, log, copies, `execution_status.csv`, etc.) | **Ignored** (`results/**`) |

## Classification

| Class | Paths |
|-------|--------|
| **STAGE_RUNNER** | `Switching/analysis/run_switching_canonical_state_audit.m` |
| **STAGE_X_AUDIT** | Three SW-STATE-X audit artifacts (see CSV) |
| **STAGE_Y_AUDIT** | Three SW-STATE-Y audit artifacts |
| **STAGE_DURABLE_STATE_OUTPUT** | Six `switching_canonical_state_*.csv` + one `switching_canonical_state_audit.md` |
| **DO_NOT_STAGE_RUN_DIR_SIDECAR** | Entire tree under `results/switching/runs/run_2026_05_04_231550_switching_canonical_state_audit/` |
| **DO_NOT_STAGE_UNEXPECTED** | *(none identified)* |
| **NEEDS_OWNER_DECISION** | Whether **durable outputs** should be committed vs **runner-only** commit with regeneration policy |

## Run-directory sidecars — recommendation

**Default: DO_NOT_STAGE_RUN_DIR_SIDECAR.**

- Entire **`results/**`** tree is **gitignored**; run folders are **expendable provenance** for this governance runner.
- Durable **tables + report** at repo root paths already capture the intended published artifacts; run copies duplicate those files.
- **Exception:** Only if repo policy mandates tracking **`results/switching/runs/**`** for audit replay — not assumed here.

## Force-add policy

Ignored paths **must** use explicit **`git add -f -- <path> ...`** per path (never `git add .` / `-A`).

## Slice readiness checklist

| Criterion | Status |
|-----------|--------|
| Runner repaired (SW-STATE-X) | **YES** |
| MATLAB validation succeeded (`run(...)`, SW-STATE-Y) | **YES** |
| `eval(fileread)` failure documented (not script defect) | **YES** |
| No figures generated | **YES** |
| No cross-module writes from runner | **YES** (Switching outputs only) |
| Durable outputs identified | **YES** (six CSV + one MD) |
| Run-dir excluded | **Recommended YES** |

## Recommended staging command (exact paths, copy-paste after review)

**Do not run until owner confirms durable-output policy.**

```bash
git add -- Switching/analysis/run_switching_canonical_state_audit.m

git add -f -- \
  reports/switching_state_X_runner_semantic_repair.md \
  tables/switching_state_X_changes.csv \
  tables/switching_state_X_status.csv \
  reports/switching_state_Y_runner_test_run.md \
  tables/switching_state_Y_outputs.csv \
  tables/switching_state_Y_status.csv \
  reports/switching_state_Z_promotion_slice_plan.md \
  tables/switching_state_Z_candidate_paths.csv \
  tables/switching_state_Z_stage_plan.csv \
  tables/switching_state_Z_status.csv

git add -f -- \
  tables/switching/switching_canonical_state_claim_safety_matrix.csv \
  tables/switching/switching_canonical_state_completed_tests.csv \
  tables/switching/switching_canonical_state_cross_module_blockers.csv \
  tables/switching/switching_canonical_state_family_inventory.csv \
  tables/switching/switching_canonical_state_open_tasks.csv \
  tables/switching/switching_canonical_state_status.csv \
  reports/switching/switching_canonical_state_audit.md
```

Then **`git diff --cached --name-only`** must be reviewed before commit.

**Optional runner-only slice:** omit the second `git add -f` block (six CSV + report) and commit audits + runner only — owner must accept **regenerate-on-clone** for durable tables/report.

## Commit message suggestion

`feat(switching): add canonical state audit runner and promotion audits`

(or split into two commits: runner + X/Y/Z docs first, durable outputs second).

---

*End of report.*
