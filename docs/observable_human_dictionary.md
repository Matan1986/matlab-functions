# Observable human dictionary (interpretation layer)

**Status:** Canonical *interpretation* companion to Agent 24H tables and reports.  
**Policy:** Claims cite tracked `tables/` and `reports/` only. Where a number is absent, the text says **NOT ESTABLISHED** (no new fits).

---

## Language Convention

* Mathematical variables (`P_T`, `\kappa_1`, `\kappa_2`, `\alpha`, `\Phi_1`, `\Phi_2`, …) are the PRIMARY model language
* Observables are SECONDARY measurement proxies
* Mapping is interpretative, not substitutive
* No observable replaces a model variable

## Core Mathematical Model Statements

Switching (latent decomposition):
\[
S \approx P_T + \kappa_1 \Phi_1 + \kappa_2 \Phi_2
\]

Aging:
\[
R \approx f(P_T, \kappa_1, \alpha)
\]

Relaxation:
\[
A \approx f(P_T)
\]

## Mathematical Definitions (Primary Layer)

### Variable: P_T
Mathematical definition: \(P_T\) is the temperature-indexed barrier/threshold landscape along the switching current axis \(I\) (PMF/CDF family over barrier-threshold outcomes).
Mathematical role: provides the baseline barrier geometry contribution used in switching and as the PT-dependent part of the aging model.
Operational definition (from data): extracted as the PT backbone / temperature-indexed quantile ladder (via `barrier_descriptors` and the PT backbone lineage used throughout the repo).

### Variable: \kappa_1
Mathematical definition: \(\kappa_1\) is the rank-1 residual amplitude multiplying the first deformation mode \(\Phi_1\) in the switching decomposition after subtracting the PT backbone.
Mathematical role: leading collective correction amplitude; enters the aging hierarchy as an additive term and supports the dominant ridge-vs-backbone mismatch.
Operational definition (from data): obtained as the first-mode coefficient from the residual-strip / decomposition fit (`alpha_structure.csv` lineage).

### Variable: \kappa_2
Mathematical definition: \(\kappa_2\) is the rank-2 residual amplitude multiplying the second deformation mode \(\Phi_2\) in the switching decomposition after PT backbone subtraction.
Mathematical role: subleading deformation amplitude; enters the aging hierarchy through the deformation ratio \(\alpha\).
Operational definition (from data): obtained as the second-mode coefficient from the rank-2 / second-mode decomposition fit (see `alpha_structure.csv` lineage and kappa2 structure tables).

### Variable: \alpha
Mathematical definition: \(\alpha = \kappa_2/\kappa_1\).
Mathematical role: controls the relative weight of the second deformation mode versus the dominant correction in the minimal deformation (Tier-2) aging model.
Operational definition (from data): computed directly from the fitted coefficients \(\kappa_2\) and \(\kappa_1\) from the rank-2 decomposition (`alpha_structure.csv`).

### Variable: \Phi_1
Mathematical definition: \(\Phi_1\) is the first deformation shape (dominant eigenvector / mode template) of the residual switching structure after subtracting the PT backbone.
Mathematical role: defines the spatial/ridge profile that is weighted by \(\kappa_1\) in the switching relation \(S \approx P_T + \kappa_1\Phi_1 + \kappa_2\Phi_2\).
Operational definition (from data): recovered as the rank-1 residual mode template from the decomposition pipeline (the same basis used to fit \(\kappa_1\)).

### Variable: \Phi_2
Mathematical definition: \(\Phi_2\) is the second deformation shape (second eigenvector / mode template) of the residual switching structure after PT backbone subtraction.
Mathematical role: defines the subleading localized distortion profile that is weighted by \(\kappa_2\) in switching and characterized in \(\alpha\)-based deformation studies.
Operational definition (from data): recovered as the rank-2 residual mode template from the decomposition pipeline; follow-on characterization metrics live in `phi2_structure_metrics.csv`.

## Physical Mapping (Secondary, Interpretative)

### Variable: P_T
Mathematical role: baseline barrier landscape governing the PT-dependent contribution to switching and aging.
Physical interpretation: the temperature-indexed probability mass / CDF backbone of threshold outcomes along current \(I\) (the distribution the map is compared against).
Observable evidence (non-defining):
- correlated observables: `tail_width_q90_q50_PT`, `spread90_50` (PT quantile/spread summaries)
- best proxy (empirical): `spread90_50` as implemented in the fitted tables for the baseline PT contribution \(g(P_T)\)
- evidence: `tables/aging_prediction_models.csv` LOOCV RMSE **11.9148173531162** (n = 10), Pearson **0.9117808799152**; `tables/aging_kappa2_models.csv` LOOCV RMSE **10.9809226364879** (n = 11)

### Variable: \kappa_1
Mathematical role: leading residual-mode amplitude (rank-1 correction) in the switching decomposition; main additive correction in aging.
Physical interpretation: collective response amplitude of the system that quantifies the dominant “ridge opens vs backbone mismatch”.
Observable evidence (non-defining):
- correlated observables: `S_peak` / `S_peak_mA` and `tail_width_q90_q50_PT`
- best proxy (empirical): `tail_width_q90_q50_PT + S_peak_mA`
- evidence: `tables/agent24h_correlations.csv` Pearson \(\kappa_1\)~`S_peak` **0.9706** (n = 14) and \(\kappa_1\)~`tail_width_q90_q50_PT` **0.6649** (n = 12); `tables/observable_replacement_model_tests.csv` shows \(\kappa_1\) improves the aging predictive term set (e.g. `R_pred_01`, k1_fit_01–02)

### Variable: \alpha
Mathematical role: deformation ratio \(\alpha=\kappa_2/\kappa_1\) that controls the relative weight of the second deformation mode in the minimal physical aging model.
Physical interpretation: relative subleading deformation of the activation/front structure (22–24 K residual emphasis in higher tiers).
Observable evidence (non-defining):
- correlated observables: `skew_pt_weighted` (PT PMF asymmetry) together with `width_mA` (ridge width), plus map-side shape asymmetries
- best proxy (empirical): `skew_pt_weighted + width_mA`
- evidence: `tables/agent24h_correlations.csv` Pearson \(\alpha\)~`asymmetry_q_spread` **0.2813** (n = 14) and \(\alpha\)~`q90_minus_q50_map` **0.6961** (n = 14); `tables/aging_kappa2_models.csv` Tier-2 LOOCV RMSE **6.98804575007817** (n = 11) with \(\alpha\) included

### Variable: \kappa_2 (optional)
Mathematical role: rank-2 residual amplitude; determines \(\alpha\) through \(\alpha=\kappa_2/\kappa_1\).
Physical interpretation: subleading ridge mismatch amplitude captured by the second residual deformation mode.
Observable evidence (non-defining):
- correlated observables: `I_peak_mA`
- best proxy (empirical): `I_peak_mA`
- evidence: `tables/agent24h_correlations.csv` Pearson \(\kappa_2\)~`I_peak_mA` **0.4818** (n = 14)

## Mandatory interpretation rule (validity)

For every **observable** entry below, the following are **required**:

1. **Spread of *what*?** — Name the **random variable / axis** (e.g. threshold current **I** on the **barrier PMF**, or **I** in the **measured map histogram**), or write **N/A** if the quantity is not a spread.
2. **Skew of *what*?** — Same: **which distribution** (PT PMF vs map histogram vs quantile construction), or **N/A**.
3. **Width of *which* distribution or structure?** — Distinguish **ridge width on the 2D switching map** from **quantile width of the barrier PDF in I**, or **N/A**.

**Primary data domain** (every entry):

| Domain | Meaning |
| --- | --- |
| **map** | Measured **switching map** (signal vs current / field; ridge geometry and map-derived histograms of **measured** threshold events). |
| **PT (barrier)** | **Probability mass / CDF** of the **barrier or threshold** along **switching current I** at each temperature (stacked “PT backbone” and merges such as `barrier_descriptors`). |
| **fit** | **Decomposition / SVD / rank modes** on residuals after backbone subtraction — **not** a raw experimental histogram unless noted. |
| **cross** | Interpolated or merged quantities on a **shared temperature grid** (e.g. `R_T_interp`, `A_T_interp`). |

---

## Aging: **R(T)** predictive model hierarchy

**Cohort:** Unless noted, **n = 11** aligned temperatures (see `tables/aging_kappa2_models.csv`, `tables/aging_hermetic_closure_models.csv`). **n = 10** Tier 1 benchmark: `tables/aging_prediction_models.csv`. **Do not flatten** this ladder: **Tier 1** is the canonical baseline; **Tier 2** is the **minimal physically interpretable** model; **Tiers 3–4** are **quantitative refinements** (see interpretation block below). Full ranked comparisons: `tables/aging_meta_audit_model_ranking.csv`.

### Tier 1 — Canonical baseline

\(R \approx g(P_T) + \kappa_1\)  
**(PT landscape scalar + collective correction)**

- **Role:** baseline PT contribution \(g(P_T)\) (barrier geometry) plus **first residual-mode amplitude** \(\kappa_1\) (collective / map-linked state).
- **Evidence (n = 10):** `tables/aging_prediction_models.csv` — LOOCV RMSE **11.9148173531162**, Pearson(y, ŷ) **0.9117808799152**; `tables/observable_replacement_model_tests.csv` (R_pred_01).
- **Evidence (n = 11):** `tables/aging_kappa2_models.csv` — LOOCV RMSE **10.9809226364879**, Pearson **0.919275527521051**.

### Tier 2 — Deformation model (minimal physical model)

\(R \approx g(P_T) + \kappa_1 + \alpha\)  
**(adds geometric deformation)**

- **Role:** Tier 1 plus **\(\alpha = \kappa_2/\kappa_1\)** — deformation of the **activation front** relative to the dominant correction (fit-derived; **partial** observable proxies per Agent 24H).
- **Evidence:** `tables/aging_kappa2_models.csv`; `tables/aging_kappa2_best_model.csv` — **n = 11**, LOOCV RMSE **6.98804575007817**, Pearson **0.982177433124039**, Spearman **0.909090909090909**.

### Tier 3 — Global best (smooth coupling)

\(R \approx g(P_T) + \kappa_1 + \alpha + \kappa_1\alpha\)  
**(adds coupling between amplitude and deformation; best LOOCV RMSE on the audited n = 11 table set)**

- **Role:** **Nonlinear cross-term** between **collective amplitude** and **deformation ratio** — lowest LOOCV among the hermetic-closure extension rows on this cohort.
- **Evidence:** `tables/aging_hermetic_closure_models.csv` — **n = 11**, LOOCV RMSE **5.68199255914414**, Pearson **0.982939789310599**; ranked **overall #1** in `tables/aging_meta_audit_model_ranking.csv` (`BEST_LOOCV_N11`).

### Tier 4 — Transition-resolved (hermetic under project criterion)

\(R \approx g(P_T) + \kappa_1 + \alpha + |\alpha_\mathrm{res}|\)  
**(adds residual reorganization active near 22–24 K; satisfies closure criterion)**

- **Role:** **Residual deformation** beyond the **\(\alpha\)** geometry line; emphasizes **reorganization** in the **22–24 K** window per hermetic audit metrics.
- **Evidence:** `tables/aging_hermetic_closure_models.csv` — **n = 11**, LOOCV RMSE **6.35176881617559**, Pearson **0.989016125291927**; **hermetic rank #1** in `tables/aging_meta_audit_model_ranking.csv` (`BEST_HERMETIC_BY_PROJECT_RULE`).

**Related sweeps (not separate named tiers here):** `tables/aging_alpha_closure_models.csv` includes other \(\alpha\) / \(\alpha_\mathrm{res}\) constructions (e.g. `abs(alpha)`); see meta-audit for rank vs Tier 3–4.

### Interpretation

- **Tier 1:** **Barrier geometry** + **activation amplitude** (\(\kappa_1\) on the dominant correction).
- **Tier 2:** Adds **deformation of the activation front** (\(\alpha\)).
- **Tier 3:** Captures **smooth coupling** between **amplitude** and **deformation** (\(\kappa_1 \cdot \alpha\)).
- **Tier 4:** Introduces **residual reorganization** beyond geometric deformation (**| \(\alpha_\mathrm{res}\)** |).

**Note:** **Tier 2** is the **minimal physically interpretable** model in this ladder. **Tiers 3–4** are **quantitative refinements** and **must not replace Tier 2** as the **core physical statement** in prose.

---

## Latent and backbone objects

### PT

**Layer:** latent (backbone object; not a single scalar)

**Primary data domain:** **PT (barrier)** — stacked **threshold / barrier distribution in switching current I** at each **T** (histogram / PMF / CDF family).

**Formal definition:** The **backbone** is the **temperature-indexed collection** of **barrier-side threshold statistics** in **I** (quantile ladder, normalized PMF summaries). It is **not** the raw 2D switching map.

**Spread of what?** Summaries (e.g. `spread90_50`, `tail_width_q90_q50_PT`) describe spread of **I** under the **barrier / PT PMF** at each **T** — **not** automatically the map histogram.

**Skew of what?** PT skew metrics describe asymmetry of **that same barrier PMF in I** (e.g. `skew_pt_weighted`).

**Width of what?** PT “width” metrics (e.g. `std_threshold_mA_PT`, `iq75_25_mA`) are **widths of the barrier distribution in I**, not map ridge thickness unless explicitly tied to a map pipeline.

**How it is computed in this repo:** See lineage in `tables/experimental_observable_catalog.csv` (PT rows) and merges referenced there (`alpha_from_PT`, `barrier_descriptors`, PT matrix exports).

**Observable proxy (if latent):** **N/A** — the object **is** the barrier statistics; scalars are **partial** summaries (`tables/latent_to_observable_replacement_table.csv`: PT_backbone).

**Empirical support:**

- Pearson: **NOT ESTABLISHED** as a single scalar (object-level).
- Spearman: same.
- LOOCV impact: **A(T)** — PT-only model beats adding \(\kappa_1\) on Agent 24A snapshot (`tools/_agent24a_result.json`; test A_pred_01 in `tables/observable_replacement_model_tests.csv`). **R(T)** — barrier spread alone weaker than spread + \(\kappa_1\) (Tier 1).
- Notes: `reports/experimental_observable_replacement_report.md` §1–2.

**What it actually measures:** The **experimentally inferred distribution of switching thresholds in current** as a function of **temperature**, before / alongside map-specific deformation.

**Human interpretation:** Think **“how wide and asymmetric is the barrier in I at this T?”** — the **PDF backbone** the map is compared against.

**Physical meaning (current hypothesis):** **Barrier / activation** structure in **I**; backbone for **deformation** (map minus backbone).

**Where it is used:** **S** (switching barrier geometry); **A** (24A PT scores); **R** (Tiers **1–4** aging models via the PT statistic \(g(P_T)\), implemented in fitted tables as `spread90_50`).

**Failure modes / limitations:** **No single scalar** replaces the full PT object; map-only quantile spreads **mis-track** \(\kappa_1\) vs PT tail width (`tables/agent24h_correlations.csv`).

**Important distinctions:** **PT spread in I** \(\neq\) **map** `q90_minus_q50` on measured threshold histograms at each T (catalog warns \(\rho \approx -0.12\) for map spread vs \(\kappa_1\) on n = 14).

---

### kappa1

**Layer:** latent

**Primary data domain:** **fit** — scalar **amplitude** on **rank-1 residual mode** \(\Phi_1\) (after PT backbone alignment); see `tables/experimental_observable_catalog.csv`.

**Spread / skew / width of what?** **N/A** — \(\kappa_1\) is **not** a distribution moment; it **weights** a **spatial / ridge** mode shape.

**Formal definition:** **Rank-1 amplitude** from residual-strip / decomposition fit (**not** a direct histogram moment).

**How it is computed in this repo:** `tables/alpha_structure.csv`; decomposition runs (catalog lineage).

**Observable proxy (if latent):** **PT:** `tail_width_q90_q50_PT` **jointly** with **map** `S_peak` / `S_peak_mA` (Agent 20A). **NOT** raw map `q90_minus_q50` alone.

**Replacement quality:** **PARTIAL** — strong **prediction** of \(\kappa_1\) from PT tail + \(S_\mathrm{peak}\); **Tier 1 aging** still improves vs spread-only (`tables/observable_replacement_model_tests.csv` R_pred_01).

**Empirical support:**

- Pearson: \(\kappa_1\) vs `S_peak` **0.9706** (n = 14); vs `tail_width_q90_q50_PT` **0.6649** (n = 12); vs map `q90_minus_q50` **−0.1156** (n = 14) — `tables/agent24h_correlations.csv`.
- Spearman: **NOT ESTABLISHED** in that table (NaN).
- LOOCV impact: \(\kappa_1 \sim\) tail width + \(S_\mathrm{peak}\) vs tail alone — `tables/observable_replacement_model_tests.csv` k1_fit_01–02; reports `reports/kappa1_from_PT_report.md`.
- Notes: **A** prediction — \(\kappa_1\) does **not** beat PT-only on 24A snapshot (A_pred_01).

**What it actually measures:** **How large** the **dominant smooth correction** is between **map** and **PT backbone** (scalar strength of \(\Phi_1\)).

**Human interpretation:** A **single knob** for the **main “ridge opens vs backbone”** mismatch.

**Physical meaning (current hypothesis):** **Deformation / correction** amplitude atop **barrier**; **state** input for **R** (Tiers **1–4** wherever \(\kappa_1\) enters).

**Where it is used:** **S** (decomposition); **R** **Tiers 1–4**; **A** (24A: PT wins without \(\kappa_1\)).

**Failure modes / limitations:** Map-only spread **poor** proxy; **context-dependent** replacement inside every model.

**Important distinctions:** **\(\kappa_1\)** \(\neq\) **PT spread** and \(\neq\) **map spread** — it is **fit** amplitude **predicted by** PT tail + map scale.

---

### kappa2

**Layer:** latent

**Primary data domain:** **fit** — amplitude on **second mode** \(\Phi_2\).

**Spread / skew / width of what?** **N/A** (scalar mode weight).

**Formal definition:** **Rank-2 / second-mode amplitude** from decomposition (sign/convention pipeline-dependent — catalog note).

**Observable proxy (if latent):** **Map:** `I_peak_mA` primary; barrier gaps in dedicated \(\kappa_2\) reports (catalog).

**Replacement quality:** **PARTIAL** — `tables/observable_replacement_model_tests.csv` k2_fit_01 (LOOCV favors `I_peak` vs multi-term barrier mix on stated n).

**Empirical support:**

- Pearson: \(\kappa_2\) vs `I_peak_mA` **0.4818** (n = 14) — `tables/agent24h_correlations.csv`.
- Spearman: **NOT ESTABLISHED** (NaN).
- LOOCV: k2_fit_01; `reports/kappa2_state_geometry_report.md`.
- Notes: \(\kappa_2\) **does not** beat \(\alpha\)-augmented **R** model in `aging_kappa2_models.csv` row comparison for the **best** aging line — hierarchy uses **\(\alpha\)**, not \(\kappa_2\), as Tier-2 add-on.

**What it actually measures:** Strength of **subleading** map–backbone mismatch (often **localized** **width/slope**-like).

**Where it is used:** **S**; enters **\(\alpha\)**; dedicated \(\kappa_2\) reports.

**Failure modes / limitations:** Sign/convention across tables; **not** the named Tier-2 aging term (that is **\(\alpha\)**).

---

### alpha

**Layer:** latent (derived from fit: \(\kappa_2/\kappa_1\))

**Primary data domain:** **fit** — **ratio** of **second** to **first** residual amplitudes.

**Spread / skew / width of what?** **N/A** (dimensionless ratio, not a moment of one distribution).

**Formal definition:** \(\alpha = \kappa_2 / \kappa_1\) from `tables/alpha_structure.csv` (catalog).

**Observable proxy (if latent):** **PT:** `skew_pt_weighted`, `asymmetry_PT`, `spread90_50` combinations; **map:** `width_mA` (ridge width in **I** along ridge). **NOT** “closed” by observables; **do not** add \(\kappa_1\) to PT geometry for \(\alpha\) LOOCV per Agent 21C (worsens fit).

**Replacement quality:** **PARTIAL** — `tables/observable_replacement_model_tests.csv` a_fit_01–02; residual **22–24 K** regime (`reports/experimental_observable_replacement_report.md`).

**Empirical support:**

- Pearson: \(\alpha\) vs map `asymmetry_q_spread` **0.2813**; vs map `q90_minus_q50` **0.6961** (n = 14) — **map** quantities; interpret as **not** pure PT — `tables/agent24h_correlations.csv`.
- Spearman: **NOT ESTABLISHED** in that file.
- LOOCV: a_fit_01–02; **R** **Tiers 2–4** (base linear \(\alpha\) in Tier 2; interaction in Tier 3): `tables/aging_kappa2_models.csv`, `tables/aging_hermetic_closure_models.csv`.
- Notes: **Aging** — Tier 2 **stronger** than Tier 1 on n = 11; **Tiers 3–4** refine LOOCV / transition metrics per meta-audit; \(\alpha\) is **deformation / mode-coupling** coordinate, **not** a barrier histogram skew by definition.

**What it actually measures:** **Relative size** of **second** vs **first** correction to the map relative to backbone.

**Human interpretation:** “How **subleading** is the next mismatch compared to the **main** one?”

**Physical meaning (current hypothesis):** **Mode coupling / deformation ratio**; **not** a substitute for full **\(\Phi_2\)** shape.

**Where it is used:** **S**; **R** **Tiers 2–4**; interpretability studies (alpha closure reports).

**Failure modes / limitations:** **22–24 K** residual; **partial** observable closure; **do not** collapse to a single “experimental \(\alpha\)” without caveats.

**Important distinctions:** **PT skew of barrier PMF** helps **predict** \(\alpha\) but \(\alpha\) **is not** that skew.

---

### phi1

**Layer:** latent (shape / mode)

**Primary data domain:** **fit** — **first residual spatial mode** (strip / ridge after backbone).

**Spread / skew / width of what?** **N/A** as scalar moments; the **mode** may imply **broadening** of **ridge response in map coordinates** — describe in **map language**, not as a fake histogram label.

**Formal definition:** **Dominant** eigenvector / mode of residual **after subtracting PT–CDF backbone** (decomposition pipeline).

**Observable proxy (if latent):** **None as a single number** — **prose:** “**broad symmetric ridge correction vs backbone**” (`tables/paper_safe_observable_dictionary.csv`; Agent 24H).

**Empirical support:** Strip LOOCV — `tables/observable_replacement_model_tests.csv` S_strip_01 (latent strip vs PT-only).

**What it actually measures:** **Where** the map **systematically deviates** from the **barrier PDF** along the ridge — **shape**, not one spread.

**Where it is used:** **S** decomposition; **\(\kappa_1\)** weights this shape.

**Failure modes / limitations:** **Cannot** be replaced by one observable in the fit.

---

### phi2

**Layer:** latent (shape / mode)

**Primary data domain:** **fit** — **second residual mode**.

**Spread / skew / width of what?** **N/A** at mode level; **map language:** **width/slope**-like **secondary bump**; metrics in `tables/phi2_structure_metrics.csv` describe **energy splits** / template match — **not** a single PMF skew.

**Observable proxy (if latent):** **Derived shape metrics** (even/odd fraction, shoulder ratios) — **paper language OK**, **stable unique label: NO** (Agent 24H).

**What it actually measures:** **Subleading** **localized** distortion (shoulders, width modulation).

**Where it is used:** **S**; **\(\kappa_2\)**; \(\phi_2\) physics reports.

---

## Key observables (explicit **what** + domain)

### spread90_50

**Layer:** observable  
**Primary data domain:** **PT (barrier)**  
**Spread of what?** **High-side spread** of the **normalized barrier / threshold PMF in switching current I** (same family as tail-width descriptors; catalog: “normalized PT PMF”).  
**Skew of what?** **N/A** (this row is a spread, not skew).  
**Width of what?** Use **spread** language: **interquantile / tail** extent in **I** on the **PT** side — **not** map ridge thickness.

**How it is computed in this repo:** `tables/alpha_from_PT.csv`; barrier merges — `tables/experimental_observable_catalog.csv`.

**Observable proxy (if latent):** **N/A** (it **is** an observable summary of **PT**).

**Empirical support:** **R(T)** **Tiers 1–4** (all include `spread90_50` where that family is used); `tables/aging_kappa2_models.csv`; `tables/aging_prediction_models.csv`; `tables/aging_hermetic_closure_models.csv`.

**What it actually measures:** How **stretched** the **upper part** of the **barrier distribution in I** is at each **T**.

**Where it is used:** **R** (aging); **S** barrier summaries; **\(\alpha\)** geometry studies.

**Important distinctions:** **PT** `spread90_50` \(\neq\) **map** `q90_minus_q50` on **measured** threshold histograms.

---

### S_peak_mA (S_peak)

**Layer:** observable  
**Primary data domain:** **map**  
**Spread / skew / width of what?** **N/A** — **peak** statistic.  
**Peak of what?** **Peak signal** on the **orthogonal switching axis** in the **measured switching map** (repo_state / catalog; experiment-specific axis definition in pipeline).

**How it is computed in this repo:** `tables/alpha_structure.csv`; Switching scaling runs.

**Empirical support:** Pearson vs \(\kappa_1\) **0.9706** (n = 14) — `tables/agent24h_correlations.csv`.

**What it actually measures:** **Overall map scale** / **contrast** on the **switching coordinate**, not a barrier PDF moment.

**Where it is used:** **S**; **\(\kappa_1\)** proxy; **cross-experiment** coordinate `X_bridge_I_over_wS` uses **I, w, S** (catalog).

---

### I_peak_mA (I_peak)

**Layer:** observable  
**Primary data domain:** **map**  
**Peak of what?** **Switching current** at the **ridge peak** in the **measured map** (mA).

**Spread / skew / width:** **N/A**

**Empirical support:** Pearson vs \(\kappa_2\) **0.4818** (n = 14) — `tables/agent24h_correlations.csv`.

**What it actually measures:** **Where** the **ridge maximum** sits on the **current axis** of the **map**.

**Where it is used:** **S**; **\(\kappa_2\)** proxy.

---

### width_mA

**Layer:** observable  
**Primary data domain:** **map**  
**Width of what?** **Ridge width** on the **switching map** (extent in **I** or mapped current axis along the ridge — **spatial/response** width of the **ridge structure**, **not** the PT PMF width unless explicitly equated in a script).

**Spread / skew of what?** **N/A** (this is a **structural** width, not a histogram central moment unless defined otherwise).

**Empirical support:** Enters **best LOOCV** \(\alpha\) **observable** model with **PT skew** (Agent 20B; `tables/observable_replacement_model_tests.csv` a_fit_01).

**Important distinctions:** **Map ridge width** vs **PT** `std_threshold_mA_PT` / `iq75_25_mA` (**barrier PMF width in I**).

---

### skew_pt_weighted

**Layer:** observable  
**Primary data domain:** **PT (barrier)**  
**Skew of what?** **Third central moment** / weighted skew of the **threshold PMF in I** on the **PT grid** (`tables/experimental_observable_catalog.csv`).

**Spread / width:** **N/A** as primary label (skew is not spread).

**Empirical support:** **\(\alpha\)** observable model tests — `tables/observable_replacement_model_tests.csv` a_fit_01; `reports/alpha_from_PT_report.md`.

---

### skew_I_weighted

**Layer:** observable  
**Primary data domain:** **map** (measured side)  
**Skew of what?** **Skewness of the measured I distribution** (weighted) at each **T** — **map-derived histogram**, **not** the PT barrier PMF unless pipelines are proven identical.

**Spread / width:** **N/A**

**Empirical support:** `tables/alpha_structure.csv` / Agent 19F correlations (catalog).

---

### q90_minus_q50_map

**Layer:** observable  
**Primary data domain:** **map**  
**Spread of what?** **Upper minus median spread** of the **measured threshold distribution in I** at each **T** (catalog: `q90_minus_q50_map`).

**Skew / width:** **N/A** (defined as **quantile spread**, not skew).

**Empirical support:** Weak vs \(\kappa_1\): Pearson **−0.1156** (n = 14) — `tables/agent24h_correlations.csv`.

---

### tail_width_q90_q50_PT

**Layer:** observable  
**Primary data domain:** **PT (barrier)**  
**Spread of what?** **q90 − q50** tail width of the **PT / barrier PMF in I** (mA).

**Skew / width:** **N/A** as skew; **is** a **tail spread**, not full width.

**Empirical support:** Pearson vs \(\kappa_1\) **0.6649** (n = 12); joint with `S_peak` for \(\kappa_1\) LOOCV — `tables/agent24h_correlations.csv`, k1_fit_01–02.

---

### asymmetry_PT

**Layer:** observable  
**Primary data domain:** **PT (barrier)**  
**Asymmetry of what?** **(q90−q50) − (q50−q25)** on the **PT PMF in I** (`tables/alpha_from_PT.csv`).

**Spread / skew:** Asymmetry metric; **not** identical to `skew_pt_weighted` (different construction).

---

### asymmetry_q_spread

**Layer:** observable  
**Primary data domain:** **map**  
**Asymmetry of what?** **Bulk-vs-tail asymmetry** of **measured quantile spreads** in **I** (catalog).

---

## Cross-experiment observables (domain = **cross**)

### R_T_interp

**Layer:** observable / merged  
**Primary data domain:** **cross**  
**Spread / skew / width of what?** **N/A** — this is **R** itself, not a moment of a distribution.  
**Definition:** **Aging clock ratio** \(\tau_\mathrm{FM}/\tau_\mathrm{dip}\) (see `docs/repo_state.json`) **interpolated** onto the **switching temperature grid** (catalog).

**Where it is used:** **R** models **Tiers 1–4** (`tables/aging_kappa2_models.csv`, `tables/aging_prediction_models.csv`, `tables/aging_hermetic_closure_models.csv`).

**Model hierarchy reminder:** **Tier 1** is **not** the strongest predictor. **Tier 2** is the **core interpretable** step above Tier 1. **Tier 3** has **lowest LOOCV RMSE** in `tables/aging_meta_audit_model_ranking.csv`; **Tier 4** is **hermetic-best** under the project transition rule — see dictionary § **Aging: R(T) predictive model hierarchy**.

---

### A_T_interp / Relax_tau_T

**Layer:** observable (relaxation family)  
**Primary data domain:** **cross** (for `A_T_interp`) or **relaxation module** (`Relax_tau_T` per `docs/repo_state.json`).  
**Spread / skew / width:** **N/A** — **timescale** / **rate** family.

**Empirical support:** Agent 24A — `tools/_agent24a_result.json`; A_pred_01.

---

### X_bridge_I_over_wS

**Layer:** derived  
**Primary data domain:** **cross**  
**Definition:** **Geometric coordinate** \(I/(w S)\) unifying relaxation and aging trends (catalog; `docs/repo_state.json` bridge).

**Spread / skew / width:** **N/A**

---

## Extended rows

Additional catalog variables (`median_I_mA`, `std_threshold_mA_PT`, `iq75_25_mA`, `skewness_quantile`, `cheb_m2_z`, `pt_svd_score1`, `pt_svd_score2`, \(\phi_2\) metrics, trajectory scalars, etc.) are listed with the same **domain / spread-skew-width-of-what** fields in **`tables/observable_human_dictionary.csv`** to keep this file bounded.

---

## Machine-readable and mapping tables

| Artifact | Path |
| --- | --- |
| Full dictionary (CSV) | `tables/observable_human_dictionary.csv` |
| Cross-layer semantic map | `tables/observable_semantic_mapping.csv` |
| Consistency audit | `reports/observable_dictionary_consistency_report.md` |

---

*Dictionary aligned with Agent 24H outputs, `tables/aging_meta_audit_model_ranking.csv`, and the **four-tier** aging **R** model hierarchy (Tiers 1–4).*

## Future Direction — Effective Physical Variables

* The current formulation uses mathematical latent variables (P_T, \(\kappa_1\), \(\alpha\), …)
* These variables have partial physical interpretations
* A future step is to define **effective physical variables** that:
  * are directly measurable or experimentally meaningful
  * retain predictive power
  * reparameterize (not replace blindly) the latent variables

Important:
* This layer is NOT implemented yet
* Current model remains in mathematical variables
