# P_T extraction readiness audit (read-only)

**Date:** 2026-03-24  
**Scope:** Minimal switching model  
`S(I,T) = S0(T) * ∫_{-∞}^{I} P_T(I_th) dI_th + κ(T) Φ((I - I_peak(T))/w(T))`  
**Mandated context:** `docs/AGENT_RULES.md`, `docs/results_system.md`, `docs/repo_state.json`, `docs/repo_audit_report.md`, `docs/repo_consolidation_plan.md`, `docs/write_system_enforcement_plan.md` (outputs for any new work must use canonical run folders and helpers).

---

## 1. Executive summary

The repository **already contains a practical pipeline to estimate an effective threshold density on the **current grid** from saved `S(I,T)` maps**, export it as **`PT_matrix.csv`**, summarize **mean / std / skew vs T**, and **consume that matrix** in a **residual decomposition** that matches the **S0·CDF(P_T) + κ·Φ** structure (with **derivative fallback** if `PT_matrix` is missing). **Energy-space summaries** (`mean_E`, `std_E`, `skew`) are implemented on top of `P_T(I)` with a **fixed linear map** `E = α I_th` for **T ≤ 30 K**.

**Gaps relative to the stated scientific goal:** (i) **`run_threshold_distribution_model.m`** does **not** yet fit or export a parametric P_T; its **Task 3 CDF fit is a stub** (metrics left `NaN`). (ii) **`switching_barrier_distribution_from_map`** builds P_T from **per-T normalized** curves, so **S0(T) and the Φ residual are not identified inside that file**—they appear in **`switching_residual_decomposition_analysis.m`**. (iii) **Cross-experiment comparison to A(T) and R(T)** is **not wired as a single turnkey script** from P_T outputs; pieces exist in other analyses.

---

## 2. Inventory: existing code vs your model components

| Topic | Primary locations | What exists |
|--------|-------------------|-------------|
| **P_T(I) from switching map** | `analysis/switching_barrier_distribution_from_map.m` | Per temperature: normalize `S` row to [0,1], optional **movmean/SGOLAY** smooth, **monotone CDF**, **`p = max(dS/dI,0)`**, renormalize to PDF on **I**; **`PT_matrix.csv`**, **`PT_summary.csv`** (`mean_threshold_mA`, `std_threshold_mA`, `skewness`, `cdf_rmse`, …). |
| **CDF / cumulative response** | Same; `Switching/analysis/switching_residual_decomposition_analysis.m` | Reconstructed **CDF** from P_T via **`cumtrapz`**; **`buildCdfModel`** builds **S_cdf = S_peak · CDF** aligned to map currents. |
| **Derivative-based extraction (fallback)** | `switching_residual_decomposition_analysis.m` → `cdfFallbackFromRow` | If no PT matrix: **gradient** on **min–max normalized S**, **movmean** smooth, monotone enforce, same PDF→CDF path. |
| **Width / I_peak / S_peak** | Alignment + full-scaling runs; residual decomposition | Uses **`switching_full_scaling_parameters.csv`** and **`switching_alignment_core_data.mat`** for **I_peak, width, S_peak** and **Smap** rows. |
| **`run_threshold_distribution_model.m`** | Repo root script | **Collapsed curves** in **u = (I−I_peak)/width**, **mean shape**, **area vs width·S_peak**, **onset at 10% S_peak**; **canonical run** via **`createRunContext`**. **Task 3 “CDF fit”** currently **does not compute** logistic/erfc fits (placeholders). **Does not output P_T(I).** |
| **Unified barrier mechanism** | `analysis/run_unified_barrier_mechanism.m` | **Cross-experiment** barrier **axis** from **relaxation + aging + switching observables**—**not** a reconstruction of switching P_T from raw maps. |
| **Relaxation-side “barrier distribution”** | `analysis/barrier_landscape_reconstruction.m` | **Activation-coordinate / effective barrier** along **relaxation A(T)** (Arrhenius-style projection)—**different object** from switching **P_T(I_th)**. |
| **Threshold / residual structure (normalized u)** | `analysis/switching_threshold_residual_structure_test.m` | **Residual structure** after **normalized threshold-style models** on **per-curve u** grids; complements map-based P_T but **different entry point**. |
| **Energy mapping from P_T** | `Switching/analysis/switching_energy_mapping_analysis.m` | Reads **`PT_matrix.csv`**, maps **`E = α I_th`**, reports **`mean_E`, `std_E`, `skew`** per T (**canonical T ≤ 30 K** default). |

**Wrappers:** `run_barrier_distribution_wrapper.m` calls `switching_barrier_distribution_from_map()`.

---

## 3. Helpers, assumptions, and outputs

### 3.1 `switching_barrier_distribution_from_map`

- **Helpers:** `createRunContext`, `save_run_table`, `save_run_report`, `save_run_figure`, `buildReviewZip`-style ZIP (see file), `create_figure` for plots.  
- **Inputs:** Switching run with **`switching_alignment_core_data.mat`** and/or **`switching_alignment_samples.csv`**.  
- **Assumptions:** Strictly increasing **T** and **I** grids; **≥ `minPointsPerTemperature`** (default **6**) valid points per row; **row-wise min–max normalization** of S before differentiation; **positive derivative** PDF; **default smoothing window 5**.  
- **Outputs (canonical run):** `tables/PT_matrix.csv`, `tables/PT_summary.csv`, `tables/source_run_manifest.csv`, figures (`S(I,T)`, `dS/dI` / P_T heatmap, CDF reconstruction), markdown report, `review/` ZIP.

### 3.2 `switching_residual_decomposition_analysis`

- **Assumptions:** Target **`S(I,T) = S0(T)*CDF + κ(T)*Φ((I−I_peak)/w)`** with **`S0 = S_peak`** in code; **canonical interpretation T ≤ 30 K** for shape of **Φ** and **κ**.  
- **P_T path:** Loads **`PT_matrix.csv`** if **`ptRunId`** set or **latest** PT run found; **interpolates P_T in T** at each map temperature, renormalizes on **alignment currents**, then **CDF = cumtrapz**.  
- **Outputs:** `phi_shape.csv`, `kappa_vs_T.csv`, quality metrics, **source manifest** with **`cdf_model_method`** (`PT_matrix_reconstruction` vs `rowwise_derivative_fallback`), figures, report, ZIP.

### 3.3 `switching_energy_mapping_analysis`

- **Assumptions:** **`E = α I_th`** with **fixed α** (no fit); **T ≤ 30 K** window.  
- **Outputs:** `energy_stats.csv` (**T, mean_E, std_E, skew**), robustness tables, figures, report, ZIP.

### 3.4 `run_threshold_distribution_model.m`

- **Assumptions:** Reads **legacy nested** alignment CSVs under a **fixed source run** path.  
- **Outputs:** Tables (**summary, collapse, area, onset**), figures, **`analysis_summary.md`**, review ZIP. **No P_T table.** **CDF parametric fit not implemented** in the current script body.

### 3.5 `run_unified_barrier_mechanism.m`

- **Outputs:** Cross-experiment run with **barrier projection tables**, figures, report—**uses relaxation reference times**, not switching P_T PDFs.

---

## 4. Data products you can reuse today

| Artifact | Typical path (under a run) | Use for P_T / parameters |
|----------|----------------------------|---------------------------|
| **`PT_matrix.csv`** | `results/switching/runs/run_*/tables/PT_matrix.csv` | Full **P_T(I)** on saved **I** grid; feeds **residual decomposition** and **energy mapping**. |
| **`PT_summary.csv`** | same run / `tables/PT_summary.csv` | **Two (or three) effective parameters vs T:** **mean_threshold_mA**, **std_threshold_mA**, **skewness**; plus **cdf_rmse** quality. |
| **`switching_alignment_core_data.mat`** | alignment run root | **`Smap`, `temps`, `currents`** for recomputation or alternate P_T estimators. |
| **`switching_full_scaling_parameters.csv`** | full-scaling run `tables/` | **I_peak, width, S_peak** vs T for **Φ** argument and **S0**. |
| **`kappa_vs_T.csv`**, **`phi_shape.csv`** | residual decomposition run | **κ(T)** and **Φ(x)** from **minimal two-term model** after CDF subtraction. |
| **`energy_stats.csv`** | energy-mapping run | **mean_E, std_E, skew(T)** as **proxy** parameters in **E** space (α-scaled **I**). |

**Cross-experiment:** Relaxation **A(T)** and aging **R** appear in many `analysis/*.m` runs; **`docs/repo_state.json`** lists **A**, **X**, **R** as bridge observables—**join is methodological** (merge tables by **T**), not a single packaged “P_T vs A vs R” run today.

---

## 5. Feasibility: extracting P_T(T) (or effective proxy) below ~30 K

**Yes, with important caveats.**

- **Code is already aligned to a low-T window** where interpretation is intended: **`switching_residual_decomposition_analysis`** and **`switching_energy_mapping_analysis`** default **`canonicalMaxTemperatureK` / `canonicalTemperatureMaxK` = 30**.  
- **P_T is available per temperature row** in **`PT_matrix.csv`** for every **T** that passes **`minPointsPerTemperature`** and finite range checks—not only T≤30, but **downstream science scripts filter** for reporting.  
- **Effective scalar summaries vs T** (**mean, std, skew** of **I_th** under P_T) are **already computed** in **`PT_summary.csv`** and again in **energy space** in **`energy_stats.csv`**.

**Caveats specific to low T**

- **Fewer temperatures** in the canonical window ⇒ **noisier** interpolation of P_T between T when using **`cdfFromPT`** (linear in T per current column).  
- **Steeper / narrower** curves at low T ⇒ **derivative noise** amplified unless smoothing is adequate (default **window 5** may need tuning per dataset).  
- **Per-row normalization** of S decouples **absolute S0(T)** from the inferred PDF; **amplitude is carried in S_peak** in the **residual decomposition**, not inside **`switching_barrier_distribution_from_map`**.

---

## 6. Risks

| Risk | Evidence / mechanism |
|------|----------------------|
| **Sparse current grid** | P_T is a **histogram-style** density on **discrete I**; **trapz** integration assumes sufficient sampling near the transition. |
| **Derivative instability** | **`gradient`** on smoothed **normalized** S; **`cdfFallbackFromRow`** uses same idea—**high-frequency noise** can distort P_T tails. |
| **Normalization ambiguity** | Row **min–max** on S defines an **effective CDF**; **not unique** if **S** has **rigidity / baseline** not captured by min–max—addressed in part by **residual** term **κΦ**. |
| **Low-T rigidity contamination** | Explicitly modeled in **`switching_residual_decomposition_analysis`** as **δS = S − S_cdf** and **Φ** mode; if **PT_matrix** is wrong, **κ** absorbs structure. |
| **High-T under-resolution** | More temperatures above 30 K in many maps; **canonical analysis truncates** at 30 K for **Φ/κ** interpretation—**high-T P_T** may be **under-used** or **noisier** if physics shifts. |
| **`run_threshold_distribution_model` stub** | **No parametric CDF fit** executed; **cannot** yet validate **“cumulative threshold”** via **logistic/erfc** on the **mean curve** in that script. |
| **Results policy** | Any **new** exporter must use **`createRunContext`** + **`save_run_*`** per **`docs/AGENT_RULES.md`** / **`docs/results_system.md`** (see **`docs/write_system_enforcement_plan.md`**). |

---

## 7. Minimal implementation plan (safest path)

Ordered for **small steps**, **reversible** changes, **maximum reuse**.

1. **Treat `switching_barrier_distribution_from_map` + `PT_summary.csv` as the canonical P_T(I) + parameter vs T product**  
   - Run (or re-run) from the **same alignment run** you trust for **`Smap`**.  
   - Inspect **`cdf_rmse`** vs T to flag **unreliable rows** before physics interpretation.

2. **Run `switching_residual_decomposition_analysis` with explicit `ptRunId`** pointing at that **PT run**  
   - Confirms **`PT_matrix_reconstruction`** path and yields **κ(T)** + **Φ(x)** for the **full minimal model**.  
   - Record **`cdf_rows_from_pt` vs `cdf_rows_from_fallback`** in **`residual_decomposition_quality.csv`**.

3. **Run `switching_energy_mapping_analysis` on the same PT run** (optional but cheap)  
   - Gives **mean_E(T), std_E(T)** in the **T ≤ 30 K** window for **cross-domain language** (still **α·I** proxy).

4. **Cross-experiment comparison (later, minimal)**  
   - **Join** `PT_summary` or `energy_stats` **on T** with tables from **`relaxation`** / **`aging`** runs (e.g. **temperature_observables.csv**, **observable_matrix.csv**) in a **new `cross_experiment` run**—**no change** to P_T code required if columns are aligned.  
   - Emit **`save_run_table`** correlation / regression summaries + **`save_run_report`**.

5. **Optional: complete `run_threshold_distribution_model.m` Task 3**  
   - Fit **logistic / erfc** to **`S_mean(u)`** on **`u_fit`**, populate **summary_metrics.csv**, and **document** that this tests **mean collapsed curve** only—not **full P_T(I,T)**.

6. **Optional: export_observables**  
   - If you need a **single index CSV** at run root for tooling, call **`export_observables`** with a small **wide table** of **(T, mean_I_th, std_I_th, …)** per **`docs/AGENT_RULES.md`**.

---

## 8. Relation to `docs/repo_state.json`

Switching **core observables** in **`repo_state.json`** (**S_peak, I_peak, width_I, X, …**) are **inputs** to the **Φ** factor and **collapse**; they are **not** yet listed as first-class **P_T-derived** observables. A future registry update could add derived names (e.g. **mean_I_th**, **std_I_th**) **when** you stabilize definitions—outside the scope of this read-only audit.

---

## 9. Conclusion

**Readiness: high** for an **effective P_T(I) on the measured grid** and **at least two parameters vs T** (**mean**, **width/std**; **skew** as third), with **canonical run outputs** already implemented. **Readiness: partial** for **closed-form P_T** or **full identification** of **S0, P_T, κ, Φ** without running **residual decomposition**. **Readiness: low** for **automated A(T)/R(T) comparison** until a **small cross-experiment join run** is added. **Immediate scientific blocker** in **`run_threshold_distribution_model.m`** is the **unfinished CDF fitting block**, not the absence of P_T code elsewhere.

---

*End of read-only audit.*
