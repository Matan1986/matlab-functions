# AGING-OLD-FIT-SUMMARY-METHOD-AUDIT-01 — Old fit / summary route (read-only)

**Task:** Method audit of the **legacy fit + stage-6 summary** lane (`AFM_like`, `FM_like`, `Dip_area_selected`, `FM_E`) before any scientific use or replay.  
**Execution:** No MATLAB, Python, replay, fitting, tau, or ratios. No code edits.  
**Rules:** [`docs/repo_execution_rules.md`](../../docs/repo_execution_rules.md) (documentation and execution hygiene only for this task).  
**Preflight:** `git diff --cached --name-only` was **empty** at audit time.

---

## Executive summary

The four objects are **not** the same as five-column **Track B** consolidation fields **`Dip_depth`** and **`FM_abs`**. They are produced on the **stage 5 parametric fit** and **stage 6 Track A summary** path, fed by **`fitFMstep_plus_GaussianDip`** operating on **`pauseRuns_raw`** (raw per-pause `DeltaM` in a fit window), with stage 5 persisting per-pause scalars and stage 6 packing **`state.summary`**. **Direct numeric substitution** for consolidation comparators is **forbidden** without a **bridge** and **documented config** (F7V / F7X5). A **canonical replay** of stage 5+6 (e.g. `run_aging_trackA_canonical_replay_parity.m` when MATLAB is allowed) is the primary way to **re-materialize** this route with provenance; **tau** on this lane is at best **partial** (diagnostic / proxy scripts exist; standard dip/FM tau readers target Track B-style inputs per F7U).

---

## 1. Where are the objects produced?

| Object | Primary writer | Stage / lane |
|--------|----------------|--------------|
| **`Dip_area_selected`** | `Aging/pipeline/stage5_fitFMGaussian.m` | Stage 5 — after `fitFMstep_plus_GaussianDip` |
| **`FM_E`** | `Aging/models/fitFMstep_plus_GaussianDip.m` (then copied in stage 5) | Stage 5 — fit model output |
| **`AFM_like`** | `Aging/pipeline/stage6_extractMetrics.m` → `state.summary.AFM_like` | Stage 6 — **Track A** summary |
| **`FM_like`** | `Aging/pipeline/stage6_extractMetrics.m` → `state.summary.FM_like` | Stage 6 — **Track A** summary |

Downstream **exports** and **parity** scripts (e.g. `Aging/analysis/run_aging_trackA_canonical_replay_parity.m`) read pause runs + `state.summary` and write tables — they **do not redefine** the physics of the fields.

---

## 2. Input signal / object

- **Fit core:** `fitFMstep_plus_GaussianDip(pauseRuns_raw, dip_window_K, fitOpts)` — fits **`DeltaM`** vs **`T`** in a window around each pause temperature **`waitK`** (`T_common`, `DeltaM` on each pause run).  
- **Stage 5** maps fit outputs onto **`state.pauseRuns`** (aligned with the main pause-run struct).  
- **`Dip_area_selected`** combines **fit-derived area** `Dip_area_fit = Dip_A * sqrt(2*pi) * Dip_sigma` with optional **`Dip_area_direct`** from stage 4 when `cfg.dipAreaSource` selects `'direct'` or conditional `'mode'`.

---

## 3. Direct vs fit-derived vs stage 6 summary

| Object | Classification |
|--------|----------------|
| **`FM_E`** | **Fit-derived** scalar from the tanh-step component (RMS of mean-centered step in the fit window). |
| **`Dip_area_selected`** | **Fit-derived** unless config forces **direct** dip area — still assigned in **stage 5**. |
| **`AFM_like`** | **Stage 6 summary vector**: either **`Dip_A`**, **`Dip_area_selected`**, or **extrema-smoothed** scalars depending on **`cfg.AFM_metric_main`** and **`cfg.agingMetricMode`**. |
| **`FM_like`** | **Stage 6 summary**: in the default fit path equals **`FM_E`** element-wise. |

---

## 4. Background / baseline / reference

Contract vocabulary (see `reports/aging/aging_F7X5_definition_contract_draft.md`): the fit uses a **parametric** background **`C + m*(T-Tp) + Astep*tanh((T-Tp)/w)`** plus a **Gaussian dip**. This is **`STAGE5_FIT_PARAMETRIC`**, **not** **`SMOOTH_COMPONENT_STAGE4_DIRECT`** (`DeltaM_smooth` / sgolay). Do not equate “background” here with stage 4 smooth or consolidation semantics.

---

## 5. What “like” means in `AFM_like` and `FM_like`

Repository usage: **summary / figure-lane labels** for **one scalar per pause temperature** intended to represent **AFM (dip) strength** and **FM (step) strength** in the **fit picture**. They are **not** synonyms for stage 4 **`dip_signed`**, **`FM_signed`**, or consolidation **`Dip_depth` / `FM_abs`** (`stage6_extractMetrics.m` comments; `docs/aging_observable_user_guide_draft.md`).

---

## 6. Signed vs absolute vs area-like vs fit-parameter-like

- **`FM_E`**, **`Dip_area_selected`** (fit branch): **non-negative** scalars from the fit construction (`Dip_A`, `sigma` > 0 enforced in decode).  
- **`AFM_like`**: **`height`** mode uses **`Dip_A`** (amplitude-like); **`area`** mode uses **`Dip_area_selected`** (area-like, μB·K/Co in figure labels).  
- **`FM_like`**: matches **`FM_E`** — **energy-like / RMS** of the fluctuating step component, not **`FM_abs`** from consolidation.

---

## 7. Tau path

- **No** first-class **tau extraction** contract for **`AFM_like` / `FM_like`** equivalent to the Track B **`Dip_depth` / `FM_abs` vs `tw`** readers (F7U / `aging_multipath_status_01_blockers.csv`: **`BLK_TRACKA_TAU_READER`**).  
- **Diagnostic** tau-like proxies appear in **`run_aging_trackA_tau_minimal_replay.m`** (polyfit on `log10(tw)` — **not** certified canonical tau).  
- **Status:** **`TAU_PATH_FOR_OLD_ROUTE_READY` = PARTIAL** at best (metadata and adapter gaps).

---

## 8. Comparability to `Dip_depth` / `FM_abs`

| Baseline | Relation to old route |
|----------|------------------------|
| **`Dip_depth`** | **Not directly the same object** as **`AFM_like`** or fit **`Dip_area_selected`** (different stages: stage 4 decomposition / consolidation vs stage 5–6 fit summary). **Bridge** required for any claimed alignment. |
| **`FM_abs`** | **Not** interchangeable with **`FM_E` / `FM_like`** (consolidation magnitude policy vs fit RMS on tanh step). **Bridge** required. |

---

## 9. Recommended next step (documentation-level)

1. **Bridge mapping / F7V alignment** before cross-route plots or ratios.  
2. When MATLAB policy allows: **canonical Track A replay** (`run_aging_trackA_canonical_replay_parity.m`) to regenerate **`aging_trackA_replay_dataset.csv`** with logged **`cfg`** and fit status — **not** done in this audit.  
3. **Exclude** naive substitution of Track A names for Track B columns in tau/ratio pipelines until adapters exist.

---

## Evidence files (non-exhaustive)

- `Aging/pipeline/stage5_fitFMGaussian.m`  
- `Aging/pipeline/stage6_extractMetrics.m`  
- `Aging/models/fitFMstep_plus_GaussianDip.m`  
- `docs/aging_observable_user_guide_draft.md`  
- `reports/aging/aging_F7X5_definition_contract_draft.md`  
- `tables/aging/aging_F7X5_contract_scope_matrix.csv`  
- `reports/aging/aging_multipath_status_01.md`  
- `Aging/analysis/run_aging_trackA_canonical_replay_parity.m`  
- `Aging/analysis/run_aging_trackA_tau_minimal_replay.m`  

**Note:** `Aging/analysis/aging_structured_results_export.m` runs stage 4–5 but exports **`Dip_depth`** / **`FM_abs`**-style columns for structured maps — it does **not** replace the Track A **`AFM_like` / `FM_like`** contract.

---

## Machine-readable annex

| File | Role |
|------|------|
| `tables/aging/aging_old_fit_summary_method_audit_01_object_inventory.csv` | Per-object definitions |
| `tables/aging/aging_old_fit_summary_method_audit_01_lineage.csv` | Q&A lineage |
| `tables/aging/aging_old_fit_summary_method_audit_01_comparability.csv` | vs `Dip_depth` / `FM_abs` |
| `tables/aging/aging_old_fit_summary_method_audit_01_next_step.csv` | Next action row |
| `tables/aging/aging_old_fit_summary_method_audit_01_status.csv` | Verdict keys |

---

## Cross-module

No Switching, Relaxation, Maintenance/INFRA, or MT scope in this audit.
