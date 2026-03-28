# Observable dictionary — consistency audit

**Scope:** `docs/observable_human_dictionary.md`, `tables/observable_human_dictionary.csv`, `tables/observable_semantic_mapping.csv`, versus Agent 24H artifacts and related aging tables.

---

## Checks performed

### 1. Observable naming vs “spread/skew/width of *what*?”

- **Result:** **PASS** for primary entries — each key observable row in the CSV includes **non-empty** `spread_of_what`, `skew_of_what`, or explicit **N/A** with **`peak_or_other_scalar`** / structure field where the quantity is not a moment.
- **Residual risk:** Short human prose could still be misread; the **CSV is the strict machine layer**.

### 2. Map vs PT vs fit domain separation

- **Result:** **PASS** — `primary_domain_map_PT_fit_cross` is set per row; the markdown **domain table** matches catalog intent (`experimental_observable_catalog.csv`).
- **Flag:** `skew_I_weighted` (**map** histogram in **I**) vs `skew_pt_weighted` (**PT PMF in **I**) must stay **distinct** — dictionary states both.

### 3. PT spread vs map spread (kappa1 story)

- **Result:** **CONSISTENT** with `tables/agent24h_correlations.csv`: map `q90_minus_q50` vs \(\kappa_1\) **−0.1156** (n = 14); PT `tail_width_q90_q50_PT` vs \(\kappa_1\) **+0.6649** (n = 12). Dictionary **does not** equate them.

### 4. Agent 24H latent ↔ observable replacement

- **Result:** **CONSISTENT** — \(\kappa_1\) joint PT tail + \(S_\mathrm{peak}\); \(\alpha\) **partial** and **kappa1-augmented PT hurts** \(\alpha\) LOOCV (a_fit_02); \(\Phi_{1,2}\) **paper language** not single scalars (`latent_to_observable_replacement_table.csv`, `observable_replacement_model_tests.csv`).

### 5. Aging **R** model hierarchy (critical) — **four tiers**

- **Requirement:** **Tier 1** = canonical baseline; **Tier 2** = minimal **physical** model; **Tier 3** = **best LOOCV RMSE** on audited n = 11 set; **Tier 4** = **hermetic** best under project rule — without **replacing Tier 2** as the core interpretive statement.
- **Evidence:**
  - **Tier 1:** `tables/aging_prediction_models.csv` (**n = 10**, LOOCV RMSE **11.9148173531162**); `tables/aging_kappa2_models.csv` (**n = 11**, LOOCV RMSE **10.9809226364879**).
  - **Tier 2:** `tables/aging_kappa2_models.csv` — LOOCV RMSE **6.98804575007817**; `tables/aging_kappa2_best_model.csv` still labels this row **`best_model`** (see §6).
  - **Tier 3:** `tables/aging_hermetic_closure_models.csv` — `R ~ g(P_T) + kappa1 + alpha + kappa1*alpha`, LOOCV RMSE **5.68199255914414**; `tables/aging_meta_audit_model_ranking.csv` rank **1** (`BEST_LOOCV_N11`).
  - **Tier 4:** `tables/aging_hermetic_closure_models.csv` — `R ~ g(P_T) + kappa1 + alpha + abs(alpha_res)`, LOOCV RMSE **6.35176881617559**; meta-audit **hermetic rank 1** (`BEST_HERMETIC_BY_PROJECT_RULE`).
- **Result:** **PASS** — `docs/observable_human_dictionary.md` documents **Tiers 1–4** with citations; prose states **Tier 2** as **minimal physically interpretable**; **3–4** as refinements.

### 6. Ambiguity: “best model” row vs meta-audit

- **`tables/aging_prediction_best_model.csv`:** **n = 10**, **`R ~ g(P_T) + kappa1`** — Agent 24B–style headline.
- **`tables/aging_kappa2_best_model.csv`:** **n = 11**, **`R ~ g(P_T) + kappa1 + alpha`** — **not** updated to Tier 3; interpret as **“best among the kappa2 script’s primary comparison table”**, not **global minimum LOOCV** on all extensions.
- **`tables/aging_meta_audit_model_ranking.csv`:** **Global best LOOCV** on the audited stack = **Tier 3** (`kappa1*alpha`); **hermetic** leader = **Tier 4** (`abs(alpha_res)`).
- **Recommendation:** When citing “best aging model,” specify **metric**: **lowest LOOCV** → Tier 3 + meta-audit; **hermetic / transition** → Tier 4; **minimal physics story** → **Tier 2**.

### 7. Other strong forms (outside named tiers 1–4)

- **`tables/aging_alpha_closure_models.csv`:** e.g. **`R ~ g(P_T) + kappa1 + abs(alpha)`** — LOOCV RMSE **5.74277144560232** (rank **2** overall in meta-audit). **Different** from Tier 3–4 naming; dictionary points to meta-audit for full ordering.

### 8. Spearman coverage

- **`tables/agent24h_correlations.csv`:** Spearman column **NaN** for listed pairs — dictionary marks **NOT ESTABLISHED** there.
- **`tools/_agent24a_result.json`:** Spearman reported for **A** models — cited for **A** only.

### 9. Variables with multiple meanings

- **`spread90_50`:** Only **PT (barrier)** in dictionary; guarded against **map** `q90_minus_q50`.
- **`width_mA`:** **Map ridge** width — distinguished from **`std_threshold_mA_PT` / `iq75_25_mA`** (**barrier PMF** width in **I**).

---

## DICTIONARY_READY_FOR_USE

**PARTIAL**

**Reason:** Human dictionary is **complete** for **latents**, **tiered aging R**, and **critical observables**; **extended catalog** rows live primarily in **CSV** for machine use. Spearman is **sparse** in `agent24h_correlations.csv`. **Multiple aging “best” tables** require **careful citation**.

**MAIN_GAPS:**

- Spearman **not populated** in `tables/agent24h_correlations.csv` for most latent–observable pairs.
- **n = 10** vs **n = 11** aging cohorts **change** numeric benchmarks; easy to **mis-quote** “best RMSE” without **n**.
- **\(\alpha\)**, **\(\alpha_\mathrm{res}\)**, and **\(\kappa_1 \cdot \alpha\)** remain **fit-side** or **derived** — **partial** experimental language (Agent 24H) still applies.
- Alternate winning forms (**`abs(alpha)`**, etc.) remain in **`aging_alpha_closure_models.csv`**; use **`aging_meta_audit_model_ranking.csv`** for a single rank table.

**RECOMMENDED_NEXT_STEP:**

- Optional: add a **one-row “citation guide”** in `reports/aging_prediction_report.md` or **`experimental_observable_replacement_report.md`**: **n=10** vs **n=11** vs **meta-audit ranks** (Tiers **1–4**).
- Optionally **fill Spearman** in `agent24h_correlations.csv` via a **light** MATLAB export (read-only script) — **not** done in this dictionary pass.

---

## Update: Full aging hierarchy

The observable dictionary previously documented only **Tiers 1–2** for aging **R(T)**. It now includes **all validated tiers** aligned with **`tables/aging_meta_audit_model_ranking.csv`**:

- **Global best (lowest LOOCV RMSE)** on the audited n = 11 comparison: **Tier 3** — `R ~ g(P_T) + kappa1 + alpha + kappa1*alpha` (`tables/aging_hermetic_closure_models.csv`; meta-audit rank **1** overall).
- **Hermetic closure** under the project criterion: **Tier 4** — `R ~ g(P_T) + kappa1 + alpha + |alpha_res|` (`tables/aging_hermetic_closure_models.csv`; `BEST_HERMETIC_BY_PROJECT_RULE` in meta-audit).

**No contradiction with Tier 2:** **Tier 2** remains the **minimal physically interpretable** model (**barrier geometry + collective amplitude + deformation ratio**). **Tiers 3–4** are **higher-order quantitative corrections** (coupling and residual reorganization); they **do not replace** Tier 2 as the **core physical statement**.

`tables/observable_semantic_mapping.csv` adds semantic rows for **`alpha_res`** and **`kappa1*alpha`** (product term) and extends **Tier 3–4** mapping rows.

---

AGING_HIERARCHY_COMPLETE: YES

PHYSICAL_MODEL_DEFINED: YES (Tier 2)

QUANTITATIVE_REFINEMENTS_DOCUMENTED: YES

---

*Audit completed without re-running heavy analyses; tables and JSON cited as-is.*

LANGUAGE_MODEL_PRIMARY: YES
OBSERVABLES_SECONDARY: YES
MAPPING_LAYER_ADDED: YES

MATHEMATICAL_DEFINITIONS_COMPLETE: YES
PHYSICAL_INTERPRETATION_PRESENT: YES
FUTURE_LAYER_DEFINED_NOT_IMPLEMENTED: YES
