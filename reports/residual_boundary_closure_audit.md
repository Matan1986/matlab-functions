# Phase 1.6 — Residual boundary closure audit (Switching canonical)

**Scope:** Switching canonical system only. Aging and Relaxation are excluded scientifically except where a file is already documented as closure (e.g. `Aging/utils/createRunContext.m`).  
**Rules observed:** Inspect, classify, document only — no code changes, no rollback, no Phase 2 execution, no scientific analysis runs.

**Sources:** `tables/post_rollback_boundary_verification.csv`, `tables/post_rollback_boundary_status.csv`, `reports/post_rollback_boundary_verification.md`, `tables/manual_review_resolution.csv`, `tables/final_rollback_execution_log.csv`, `tables/final_rollback_execution_status.csv`, `reports/final_controlled_rollback_execution.md`, `tables/canonical_boundary_truth.csv`, `tables/canonical_boundary_violations_truth.csv`, `tables/boundary_breach_inventory.csv`.

---

## 1. Executive summary

Phase 1.5 cleared all **approved REVERT** targets against `HEAD` (`e1506a4`). The **residual** open items are: two **untracked** closure files, two **modified** closure files, one **documented violation** on marker fallback, and **deferred** non-closure items (docs, tools, tables policy).  

**Gate:** Residual **committed-baseline** blockers remain until the untracked entrypoint/marker are **tracked** (or the closure is formally redefined) and **createRunContext** / **Switching_main** are aligned with `HEAD` or an explicit reviewed commit. **Do not proceed to Phase 2** under a strict “clean canonical scope + committed boundary” definition until those are resolved.

---

## 2. Residual blockers (exact list)

Items that **block** declaring canonical boundary **clean vs git** at Phase 1 gate (committed baseline + no unreviewed drift on closure members):

| Item | Why blocking |
|------|----------------|
| `Switching/analysis/run_switching_canonical.m` | **Untracked**; sole documented Switching canonical runner; not on `HEAD` — no reproducible committed boundary. |
| `tools/write_execution_marker.m` | **Untracked**; on static closure path; same committed-baseline gap. |
| `Aging/utils/createRunContext.m` | **Modified vs HEAD**; in closure; unreviewed drift vs frozen baseline. |
| `Switching ver12/main/Switching_main.m` | **Modified vs HEAD**; in closure as raw-path donor (`fileread`); drift vs baseline. |

*Note:* User text referred to `Switching/Switching_main.m`; repository path is **`Switching ver12/main/Switching_main.m`** per boundary truth and git.

---

## 3. Non-blocking but unsafe (exact list)

Items that do **not** block “MATLAB numerical truth” of the 16-file chain by themselves but carry **policy, automation, or hygiene** risk:

| Item | Risk |
|------|------|
| `REPO_TABLES_FALLBACK_WRITE` | Writes under `tables/` when run dir unset — policy/separation violation (`canonical_boundary_violations_truth.csv`). |
| `LEGACY_EMBEDDED_EXTERNAL_RAW_PATH` | Off-repo raw paths embedded — operational fragility; known design. |
| `tables/runtime_execution_markers_fallback.txt` | Evidence of fallback behavior — governance signal. |
| `tools/classify_run_status.m` | Deferred; MEDIUM automation/runtime risk class in prior audit. |
| `tools/enforce_canonical_phi1_source.m` | Deferred; MEDIUM risk class. |
| `tools/ensure_dir.m` | Deferred; MEDIUM risk class. |
| `tools/get_run_status_value.m` | Deferred; MEDIUM risk class. |
| `tools/getLatestRun.m` | Deferred; MEDIUM risk class. |
| `tools/load_observables.m` | Deferred; MEDIUM risk class. |
| `tools/load_run.m` | Deferred; MEDIUM risk class. |
| `tools/resolve_results_input_dir.m` | Deferred; MEDIUM risk class. |
| `tools/run_artifact_path.m` | Deferred; MEDIUM risk class. |
| `tools/switching_canonical_control_scan.ps1` | Deferred; MEDIUM risk class. |
| `tools/switching_canonical_run_closure.m` | Deferred; MEDIUM risk class (audit/helper naming). |

---

## 4. Governance-only (exact list)

Items **outside** the MATLAB runtime closure or with **no effect on Switching canonical execution outputs** when only `run_switching_canonical` is run:

- `docs/repo_context_minimal.md`, `docs/repo_map.md`, `docs/repo_context_infra.md`, `docs/templates/` (DEFER_PRESERVE)
- `tables/CANONICAL_ANALYSIS_COMPLETE.txt`, `tables/phi_kappa_canonical_verdict.csv`, `tables/phi_kappa_stability_canonical_status.csv`, `tables/phi_kappa_stability_canonical_summary.csv` (deletion deferred)
- Bulk aggregate of legacy `tables/` deletions (policy, not runtime)
- `CASE_SENSITIVE_ISOLATION_CHECK` (LOW — provenance string; `canonical_boundary_violations_truth.csv`)

---

## 5. Task-by-task findings

### 5.1 Untracked truth (`run_switching_canonical.m`, `write_execution_marker.m`)

| Question | Answer |
|----------|--------|
| Expected tracked in canonical system? | **Yes** — both appear on the documented 16-file closure (`canonical_boundary_truth.csv`). |
| Untracked = boundary breach? | **Yes** for a **git-committed** canonical boundary: the “approved” closure is not fully represented on `HEAD`. |
| HEAD equivalent? | **No** committed path for these two at `HEAD` (they are new/untracked worktree files). |
| Blocks boundary cleanliness? | **Yes** until tracked (or closure formally narrowed and docs updated). |

### 5.2 Modified dependency (`createRunContext.m`, `Switching_main.m`)

| File | In claimed closure? | Drift vs HEAD? | Verdict |
|------|---------------------|----------------|---------|
| `Aging/utils/createRunContext.m` | Yes (run_dir, manifests) | Yes | **Blocking** until restore or explicit reviewed commit. |
| `Switching ver12/main/Switching_main.m` | Yes (EXTERNAL_INPUT / fileread) | Yes | **Blocking** for strict baseline; content defines embedded raw parent path. |

### 5.3 Violations and deferred tools

| ID / set | Governance vs runtime | Affects canonical execution truth? | Phase 2 blocking? | Verdict |
|----------|-------------------------|--------------------------------------|-------------------|---------|
| `REPO_TABLES_FALLBACK_WRITE` | Runtime-adjacent (marker) | Hygiene/tables path; not Switching physics core | Strict gate: **MUST_REMEDIATE_BEFORE_PHASE_2** if policy is zero fallback | **NON_BLOCKING_BUT_UNSAFE** (science path) / **MUST_REMEDIATE** (strict repo policy) |
| MEDIUM deferred `tools/*` (11 paths) | Governance / automation | No — not imported by 16-file MATLAB closure | No for canonical MATLAB truth | **NON_BLOCKING_GOVERNANCE** with **NON_BLOCKING_BUT_UNSAFE** automation note |

---

## 6. Final decision table (summary)

| Item | blocking_status | required_action_class |
|------|-----------------|------------------------|
| `run_switching_canonical.m` | BLOCKING | MUST_TRACK |
| `write_execution_marker.m` | BLOCKING | MUST_TRACK |
| `createRunContext.m` | BOUNDARY_DRIFT | MUST_RESTORE_OR_COMMIT |
| `Switching_main.m` | BOUNDARY_DRIFT | MUST_RESTORE_OR_COMMIT |
| `REPO_TABLES_FALLBACK_WRITE` | Policy | MUST_REMEDIATE_BEFORE_PHASE_2 (strict) |
| Deferred tools (11) | Non-blocking | RECLASSIFY_ONLY / defer |
| Deferred docs / tables | Non-blocking | NO_ACTION |

---

## 7. Recommendation

**Stay in Phase 1** until: (1) both untracked closure files are **committed** (or closure and docs are explicitly revised), and (2) **createRunContext** and **Switching_main** are **restored to HEAD** or changes are **reviewed and committed** as the new baseline. Optionally remediate `REPO_TABLES_FALLBACK_WRITE` before a strict governance Phase 2.

---

## 8. STATUS row (machine-readable)

See `tables/residual_boundary_closure_status.csv` for the authoritative STATUS row.
