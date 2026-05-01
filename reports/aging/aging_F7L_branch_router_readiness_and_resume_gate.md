# F7L — Aging branch-router readiness and config-routing gap audit

Read-only governance artifact. No MATLAB execution, code edits, dataset rebuilds, tau/R writer runs, staging, commits, or pushes. Execution expectations remain in [`docs/repo_execution_rules.md`](../../docs/repo_execution_rules.md).

**Anchors:** `a3bdc10` (branch router), `29254e2` (F7J scope map), `ddbe212` (F7I lineage), `84431dc` (F7H roadmap), `ced4798` (F7G metadata columns).

---

## 1. Is the branch router sufficient for readers?

**Verdict: sufficient for branch selection and pointer literacy**, with an **optional** future enhancement (one short “F7H session checklist” row) — **not** blocking.

`docs/aging_observable_branch_router.md` already maps:

| Need | Covered |
|------|---------|
| Question → branch | Quick decision table |
| Branch → fields | Branch summaries |
| Fields → artifact/script | Table + narrative paths |
| FM sign visibility | FM sign visibility matrix |
| Fit / direct | Table column + fit vs direct section |
| Allowed claims | §9 + pointer to `aging_F7J_allowed_claims_map.csv` |
| Known confusions | Dedicated section |

Detail: `tables/aging/aging_F7L_branch_router_readiness.csv`.

---

## 2. Is F7H resumable now? (no physics winner)

**F7H was blocked** because the **default** consolidated dataset path under `results/aging/runs/run_2026_03_12_211204_aging_dataset_build/...` was **missing** in the audited workspace, while **`tables/aging/aging_observable_dataset.csv`** and the **`results_old/...`** snapshot **exist** here (existence probe: consolidation **True**, archival **True**, default **False**).

**Resume posture (metadata verification only):**

| Mode | Safe with explicit pointer? |
|------|-------------------------------|
| **Current 22-row consolidation** (`tables/aging/...`) | **Yes** — set session **`AGING_OBSERVABLE_DATASET_PATH`** to an **absolute** path to that file before invoking `aging_timescale_extraction`. |
| **Archival 30-row snapshot** (`results_old/...`) | **Yes** — same env var, archival path. |
| **Compare both in F7H** | **Yes** — run the **same writer twice** with **different** env values; `createRunContext` allocates a **new** `run_*` directory each time → **no overwrite** by default. **Compare outputs as metadata/lineage artifacts**, not as ranked physics truth. |

**Not a blanket “blocked on lineage”** for file existence: operator must still **document** which consolidation epoch / upstream structured export each file represents in **`run_notes`** (bounded lineage narrative), per F7I/F7J.

Gate table: `tables/aging/aging_F7L_F7H_resume_gate.csv`.

---

## 3. Stable branch/pointer labels (reporting only — not implemented config)

See `tables/aging/aging_F7L_branch_pointer_label_plan.csv`.

Examples:

- `dataset_source_branch = current_tables_22row_consolidation`
- `dataset_source_branch = archival_results_old_30row_snapshot`
- `tau_method = dip_multi_curvefit` (`WF_TAU_DIP_CURVEFIT`)
- `fm_signal_mode = magnitude_abs_for_fm_tau` when discussing **`aging_fm_timescale_analysis`** inputs  
- `fm_signal_mode = signed_matrix_for_short_tw_audit` only if explicitly scoping matrix/F3b paths (**not** default dip tau leg)

---

## 4. Code-default risks (no edits — session mitigation)

| Risk | Detail | Mitigation (documentation / session only) |
|------|--------|-------------------------------------------|
| **`aging_timescale_extraction`** | **`defaultDatasetPath`** points at **missing** historical `results/.../211204/...` unless **`AGING_OBSERVABLE_DATASET_PATH`** is set. | Set env **before** MATLAB; confirm log prints “Dataset override … active”. |
| **`aging_fm_timescale_analysis`** | **`applyDefaults`** uses same **missing** dataset path plus **hard-coded** paths to **prior** dip tau and dip-clock metrics runs. | For **FM leg** of a chain, callers must supply **`cfg`** overrides (`datasetPath`, `dipTauPath`, etc.) — **not** covered by dip env alone. |
| **Downstream writers** | Clock ratio / rescaling depend on **prior tau CSVs** existing. | Scope F7H **incrementally**: verify **dip tau** metadata on disk first, then extend. |

---

## 5. Minimal F7H rerun plan (pseudocommands — **not executed here**)

**Scope:** metadata verification only — inspect **`tau_vs_Tp.csv`** headers and **F7G** columns after successful run; **no physical interpretation**.

**Windows CMD-style session pointer (example shapes):**

```bat
REM Run A — current 22-row consolidation branch
set AGING_OBSERVABLE_DATASET_PATH=C:\Dev\matlab-functions\tables\aging\aging_observable_dataset.csv
REM Then invoke MATLAB wrapper with Aging/analysis/aging_timescale_extraction.m only per repo rules
REM Record in run_notes: dataset_source_branch=current_tables_22row_consolidation

REM Run B — archival 30-row snapshot branch (separate session or clear/re-set env)
set AGING_OBSERVABLE_DATASET_PATH=C:\Dev\matlab-functions\results_old\aging\runs\run_2026_03_12_211204_aging_dataset_build\tables\aging_observable_dataset.csv
REM Same writer entrypoint; new run_dir timestamp prevents overwrite
REM Record in run_notes: dataset_source_branch=archival_results_old_30row_snapshot
```

**PowerShell equivalent:** `$env:AGING_OBSERVABLE_DATASET_PATH='...';` then wrapper call.

**Do not** claim physics equivalence between Run A and Run B — **metadata and coverage comparison only**.

---

## 6. Is config implementation required before F7H?

**`CONFIG_IMPLEMENTATION_REQUIRED_BEFORE_F7H` = `PARTIAL`**

- **No** unified config registry is **required** to **resume** dip-writer **metadata verification**: **`AGING_OBSERVABLE_DATASET_PATH`** + **run_notes labels** are enough.
- **Partial** gap: **FM tau** and **clock-ratio** chains still rely on **`cfg` structs** and **multiple default paths** — treat as **follow-on scope** if F7H expands beyond dip **`tau_vs_Tp.csv`** verification.

Gap inventory: `tables/aging/aging_F7L_config_routing_gap_audit.csv`.

---

## 7. Next safe step (single choice)

**Resume F7H metadata verification** using **session-only `AGING_OBSERVABLE_DATASET_PATH`** and **stable labels** in **`run_notes`**, starting with the **dip** writer (`aging_timescale_extraction`). Optionally run **twice** to compare **22-row vs 30-row** **metadata** outputs **without** selecting a physics winner.

**Alternative (lower priority):** add **one** optional subsection to the branch router (“F7H session checklist”) — documentation-only, separate commit.

---

## Deliverables

| File |
|------|
| `tables/aging/aging_F7L_branch_router_readiness.csv` |
| `tables/aging/aging_F7L_F7H_resume_gate.csv` |
| `tables/aging/aging_F7L_branch_pointer_label_plan.csv` |
| `tables/aging/aging_F7L_config_routing_gap_audit.csv` |
| `tables/aging/aging_F7L_next_step_status.csv` |
| `reports/aging/aging_F7L_branch_router_readiness_and_resume_gate.md` |

Machine-readable verdicts: `tables/aging/aging_F7L_next_step_status.csv`.
