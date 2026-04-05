# Controlled partial rollback execution (safe set only)

## Scope

Execution followed **`tables/rollback_decision_table.csv`** with **no reinterpretation**. Only rows with **`FINAL_DECISION = REVERT`**, **`ROLLBACK_PRIORITY = HIGH`**, and **`DECISION_CONFIDENCE = HIGH`** were acted on.

## Files reverted

| File | Action |
|------|--------|
| `Switching/analysis/run_PT_kappa_relaxation_mapping.m` | REVERTED |
| `Switching/analysis/run_PT_to_relaxation_mapping.m` | REVERTED |
| `Switching/analysis/run_relaxation_deep_search.m` | REVERTED |
| `Switching/analysis/run_relaxation_extraction_from_known_runs.m` | REVERTED |
| `Switching/analysis/run_relaxation_outlier_audit.m` | REVERTED |

**Source version:** tree at commit **`e1506a4955eaf9d29354e3990a6459db6b472fa1`** (**`HEAD`** on **`main`**, matching **`origin/main`** at execution time).

**Mechanism:** `git restore --worktree --source=HEAD -- <file>` for all five; for the last two files, **`git restore --staged --worktree --source=HEAD`** was used once so the index and worktree both matched **`HEAD`** (full replacement from git object; no partial line edits).

## Why this was safe

- These five paths are **not** in the Switching canonical MATLAB closure per **`tables/canonical_boundary_truth.csv`**; they are Relaxation / PT–relaxation–oriented scripts under `Switching/analysis/`.
- **Only** uncommitted drift relative to **`HEAD`** was removed (**~30** inserted lines total across five files in the pre-execution `git diff`).
- **No** `KEEP`, **no** `MANUAL_REVIEW_REQUIRED`, and **no** lower-priority **`REVERT`** rows were touched.
- **No** MATLAB logic was edited by hand—only restoration from the committed blob at **`HEAD`**.

## Confirmation: no other files touched

The git commands referenced **only** the five paths above. No other paths were passed to `git restore` / `git checkout`. New audit outputs (**`tables/rollback_execution_log.csv`**, **`tables/rollback_execution_status.csv`**, this report) are documentation of the step, not rollbacks of source files.

## Remaining unresolved items

**`REMAINING_FILES_FOR_REVIEW = 44`** — rows in **`tables/rollback_decision_table.csv`** with **`FINAL_DECISION = MANUAL_REVIEW_REQUIRED`** were **not** changed. The broader working tree still contains other modified and untracked files per prior inventory; those are **out of scope** for this partial rollback.

## Risks remaining

- **Repository-wide state** is **`UNVERIFIED`** in **`tables/rollback_execution_status.csv`**: many non-reverted changes may still exist elsewhere; only the five targeted files were aligned to **`HEAD`**.
- **Canonical execution** was not re-run; integrity of `run_switching_canonical.m` and infra was not modified by this step.
- **Governance artifacts** and **MANUAL_REVIEW** paths remain as before this execution.

## Traceability

See **`tables/rollback_execution_log.csv`** and **`tables/rollback_execution_status.csv`**.
