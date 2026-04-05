# Controlled rollback plan — Switching canonicalization incident

## Rollback philosophy (boundary-first, not quality-first)

Decisions in **`tables/rollback_decision_table.csv`** follow **`tables/canonical_boundary_truth.csv`** and related artifacts as the **authoritative** definition of what is **in** the Switching canonical MATLAB closure. **Usefulness of noncanonical edits is explicitly not a reason to KEEP** code that is outside that closure; however, **`boundary_breach_inventory.csv`** already marked most noncanonical analysis scripts for **manual review** rather than automatic **REVERT**. This plan **does not collapse** that judgment into bulk REVERT: those rows remain **`MANUAL_REVIEW_REQUIRED`** so a human can diff and decide, avoiding silent loss of intentional noncanonical work while still stating that they are **not canonical** by boundary truth.

**Governance and audit artifacts** (docs, registries, boundary CSVs, audit reports) are **not** treated as runtime contamination by default; many are **`KEEP`** with **`GOVERNANCE_PRESERVE_REQUIRED = YES`**.

## Authoritative inputs

- **`tables/boundary_breach_inventory.csv`**, **`tables/boundary_breach_status.csv`**
- **`tables/canonical_boundary_truth.csv`**, **`tables/canonical_boundary_violations_truth.csv`**, **`tables/canonical_boundary_truth_status.csv`**
- **`reports/boundary_breach_inventory.md`**, **`reports/canonical_boundary_truth.md`**

## Safe to keep (deterministic KEEP)

- **Canonical runtime / closure:** `Switching/analysis/run_switching_canonical.m`, `Aging/utils/createRunContext.m`, `tools/write_execution_marker.m`, `Switching ver12/main/Switching_main.m` (fileread path donor). Reverting these carries **HIGH** **`EXECUTION_RISK_IF_REVERTED`** for the canonical pipeline or upstream path resolution.
- **Policy execution tooling:** `tools/run_matlab_safe.bat`, `tools/pre_execution_guard.ps1`, `tools/validate_matlab_runnable.ps1` per **`docs/repo_execution_rules.md`**.
- **Governance docs** (in-scope in breach inventory): Switching boundary docs, **`docs/repo_execution_rules.md`**, **`docs/run_system.md`**, **`docs/AGENT_RULES.md`**, execution classification/status docs, **`docs/agent_prompt_exclude.md`**.
- **Evidence reports:** `reports/canonical_boundary_truth.md`, `reports/leakage_cleanup.md`.
- **Governance / registry tables:** New or retained `tables/switching_*.csv`, `tables/canonical_*.csv`, preflight/infra audit tables in the breach set, except where a separate row calls for manual review (deletions, marker file).

## Should revert (deterministic REVERT)

**Five files** — **`FINAL_DECISION = REVERT`**, **`ROLLBACK_PRIORITY = HIGH`**, **`HIGH_PRIORITY_REVERT_COUNT = 5`:**

- `Switching/analysis/run_PT_kappa_relaxation_mapping.m`
- `Switching/analysis/run_PT_to_relaxation_mapping.m`
- `Switching/analysis/run_relaxation_deep_search.m`
- `Switching/analysis/run_relaxation_extraction_from_known_runs.m`
- `Switching/analysis/run_relaxation_outlier_audit.m`

**Reason:** Relaxation or PT–relaxation **mapping** scripts living under **`Switching/analysis/`** are **outside** a **Switching-only** canonicalization scope; the breach inventory already recommended **REVERT** for these. **`EXECUTION_RISK_IF_REVERTED = NONE`** for the **canonical** `run_switching_canonical.m` closure (they are not in **`canonical_boundary_truth.csv`**).

## Manual review before rollback (MANUAL_REVIEW_REQUIRED)

**44** rows — including:

- **Noncanonical Switching analysis scripts** (phi/kappa/alpha/robustness/experimental, etc.): **OUT_OF_SCOPE** by boundary truth, but breach inventory required **manual** review; plan keeps **`MANUAL_REVIEW_REQUIRED`** so operators **diff against `HEAD` or pre-incident commit** before reverting.
- **`Switching ver12/plots/plotSwitchingPanelF.m`:** Legacy plot not in closure; revert may affect non-canonical workflows.
- **Uncertain docs:** `docs/repo_map.md`, `docs/repo_context_infra.md`, `docs/repo_context_minimal.md`, `docs/templates/`.
- **Infra helpers not in closure:** `tools/getLatestRun.m`, `tools/load_observables.m`, `tools/resolve_results_input_dir.m`, and untracked helpers (`classify_run_status.m`, `load_run.m`, etc.) — **MEDIUM** execution/automation risk if reverted blindly.
- **Deleted tracked tables** (e.g. `phi_kappa_*`, `CANONICAL_ANALYSIS_COMPLETE.txt` in breach list): restore vs accept deletion needs **retention policy** review.
- **`tables/runtime_execution_markers_fallback.txt`:** Tied to **`REPO_TABLES_FALLBACK_WRITE`** in **`canonical_boundary_violations_truth.csv`** — policy choice on clearing vs preserving.
- **Bulk row:** `tables/ (bulk: tracked legacy artifact deletions, ~150+ paths)` — **HIGH** rollback **priority** for **data recovery** decisions, not automatic git operations.

## Governance / control artifacts to preserve

Rows with **`GOVERNANCE_PRESERVE_REQUIRED = YES`** (see **`GOVERNANCE_PRESERVE_COUNT`** in **`tables/rollback_plan_status.csv`**) include **boundary CSVs** (`canonical_boundary_truth.csv`, violations, access audit), **Switching policy registries**, **preflight** tables, and **core governance docs**. Even when created or updated during the incident, they **lock or audit** the canonical system and should not be discarded **without an explicit decision** to replace them.

## Execution readiness

**`PLAN_READY_FOR_EXECUTION = NO`** in **`tables/rollback_plan_status.csv`**.

**Reason:** A large **`MANUAL_REVIEW_REQUIRED`** set remains (noncanonical analysis, tooling, uncertain docs, bulk deletions). **Only** the **five** **HIGH**-priority **REVERT** rows are safe to treat as **deterministic** scope rollback relative to Relaxation drift **without** further human review. Executing a full tree rollback **without** resolving manual rows risks **HIGH** collateral damage to wrappers, loaders, and evidence.

**Next step (when executed outside this document):** Apply **`REVERT`** only to the five files above (e.g. `git checkout <ref> -- <paths>`), then work through **`MANUAL_REVIEW_REQUIRED`** in priority order (bulk aggregate, then tooling, then noncanonical scripts).

## Machine-readable outputs

- **`tables/rollback_decision_table.csv`**
- **`tables/rollback_plan_status.csv`**
