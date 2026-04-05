# Post-rollback boundary verification — Switching canonical

## Authority

Verification used **`tables/canonical_boundary_truth.csv`** (16-file MATLAB closure), **`tables/canonical_boundary_violations_truth.csv`**, execution logs (**`tables/rollback_execution_status.csv`**, **`tables/final_rollback_execution_status.csv`**), and **`tables/manual_review_resolution.csv`**. No rollback was performed in this step.

## Approved REVERT set — cleared

**Yes.** All **28** paths from the partial rollback (**5**) plus final rollback (**23**) were checked with **`git diff HEAD -- <path>`**. **No** diff remained for any of those paths: working-tree content for each matches the blob at **`HEAD`** (**`e1506a4955eaf9d29354e3990a6459db6b472fa1`**).

So **out-of-scope scripts** that were approved for **REVERT** are **not** carrying uncommitted drift relative to **`HEAD`** anymore.

## Preserved set (DEFER_PRESERVE = 21)

Per **`manual_review_resolution.csv`**, these were **intentionally not** reverted. They are **outside** the **MATLAB runtime dependency closure** except where noted:

- **Docs (4):** Governance / navigation only — **no** canonical **`run_switching_canonical.m`** load path — **harmless** for runtime closure cleanliness.
- **Deleted governance tables (4) + bulk aggregate (1):** State is **artifact retention**, not executable scope inside the 16-file graph — **HIGH** hygiene risk for the **repo**, not for MATLAB closure execution.
- **`tables/runtime_execution_markers_fallback.txt`:** **Governance / evidence** for the known **`REPO_TABLES_FALLBACK_WRITE`** issue — **LOW** runtime risk for the canonical MATLAB call chain (file is not a closure dependency); **policy** risk remains if fallback path is used.
- **Deferred `tools/*` (11):** **MEDIUM** **automation / loader** risk if agents invoke them; they are **not** in the **16-file closure** — potential **indirect** contamination of workflows, **not** the canonical MATLAB graph itself.

## Canonical runtime boundary — remaining issues

**Closure files matching `HEAD` (clean):** **12** of **16** paths in **`canonical_boundary_truth.csv`** that exist as tracked files — **no** diff vs **`HEAD`**.

**Unsettled vs committed baseline:**

| Path | Issue |
|------|--------|
| `Switching/analysis/run_switching_canonical.m` | **Untracked** — canonical entrypoint exists locally but is **not** in **`HEAD`** |
| `tools/write_execution_marker.m` | **Untracked** — closure infra not in committed tree |
| `Aging/utils/createRunContext.m` | **Modified** vs **`HEAD`** (KEEP during rollback) |
| `Switching ver12/main/Switching_main.m` | **Modified** vs **`HEAD`** |

So **canonical scope** is **not** fully aligned with a **single committed snapshot**: the **authoritative entrypoint** is still **off-`HEAD`** (untracked), and **two** tracked closure files retain **local** edits.

**Known violation class (unchanged):** **`canonical_boundary_violations_truth.csv`** still documents **`REPO_TABLES_FALLBACK_WRITE`** for **`write_execution_marker.m`** — not removed by rollback.

## Runtime contamination risk (summary)

- **DEFER_PRESERVE tooling:** **`DEFER_PRESERVE_RUNTIME_RISK_PRESENT = YES`** — deferred helpers can still affect **automation** if used; they are **not** part of the **16-file** MATLAB closure.
- **REMAINING_RUNTIME_SCOPE_VIOLATIONS = YES** — interpreted as: **residual** uncommitted/untracked state on **in-boundary** paths and **deferred** infra **plus** documented **fallback** behavior; **not** “noncanonical scripts still dirty” (those **REVERT** targets are **clean**).

## Is canonical scope “clean enough”?

**`CANONICAL_SCOPE_CLEAN_AFTER_ROLLBACK = NO`** in **`tables/post_rollback_boundary_status.csv`**: approved **REVERT** surface is **cleared**, but **committed + working tree** still **diverge** on **entrypoint / marker / two legacy-infra files**, and **21** deferred items remain.

## Execution-chain audit readiness

**`READY_FOR_EXECUTION_CHAIN_AUDIT = YES`**: the **REVERT** work is **complete** and **traceable**; an **execution-chain audit** can proceed against **current** tree state, with **explicit** caveats above (untracked entrypoint, local edits on closure files, deferred tools).

## Artifacts

- **`tables/post_rollback_boundary_verification.csv`** — per-file / batch rows.
- **`tables/post_rollback_boundary_status.csv`** — summary flags.
