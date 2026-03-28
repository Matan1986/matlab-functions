# Experimental observable survey and latent-variable replacement (Agent 24H)

**Audience:** Experimental condensed-matter readers.  
**Policy:** Read-only synthesis from canonical `tables/`, `reports/`, `docs/repo_state.json`, and `analysis/run_aging_prediction_agent24b.m` / `run_A_prediction_from_switching_agent24a.m` logic. **No new heavy fits** — replacement tests cite existing LOOCV rows.

**Figures:** `figures/latent_vs_observable_proxy_comparison.png`, `figures/phi1_phi2_in_experimental_language.png`, `figures/observable_replacement_summary.png` (rendered via `tools/agent24h_render_figures.ps1` from the same CSVs; MATLAB twin: `analysis/run_agent24h_figures.m`).

**Correlation snippet:** `tables/agent24h_correlations.csv` (Pearson on aligned rows; Spearman column reserved — fill with MATLAB if needed).

---

## 1. Executive summary (plain language)

- **PT backbone:** This is already **the measured threshold distribution** (histogram / CDF in current at each temperature). You can describe it with **spreads, medians, skew**, but **no single number** replaces the full object. **Paper: yes. One-number model: no.**

- **\(\kappa_1\):** Behaves like a **correction strength** set mainly by **barrier upper spread (PT q90−q50)** and **map scale (\(S_\mathrm{peak}\))**. Those two observables **predict** \(\kappa_1\) very well out-of-sample (Agent 20A). **Replacing \(\kappa_1\) inside every model** is not always wise: for **aging \(R\)** you still gain from keeping \(\kappa_1\) beyond spread alone (Agent 24B). **Paper language: strong proxy. Full model replacement: context-dependent.**

- **\(\kappa_2\):** Tracks **peak current** and barrier-shape gaps in the dedicated \(\kappa_2\) study; a **simple \(I_\mathrm{peak}\)** model is competitive in LOOCV. **Good experimental proxy; not a single universal replacement** when signs/pipelines differ across tables. **Paper: proxy with caveats.**

- **\(\alpha=\kappa_2/\kappa_1\):** **Partly** captured by **PT skew + ridge width** (and asymmetry/spread combinations). A **residual** remains, concentrated near **22–24 K**. Crucially, adding \(\kappa_1\) to PT geometry for \(\alpha\) **hurts** LOOCV (Agent 21C) — do not “fix” \(\alpha\) with \(\kappa_1\) in that head-to-head. **Paper: proxy + regime caveat, not closed.**

- **\(\Phi_1\):** This is **what you see** as the **main smooth symmetric mismatch** between the **raw switching map** and the **PDF backbone** after alignment. **Not replaceable by one scalar** in the fit; **fully translatable in language** for the map.

- **\(\Phi_2\):** **Secondary structure** — mixed **width / slope** character, **localized** near the ridge, **even/odd** mix reported in `phi2_structure_metrics.csv`. **Paper language: yes. Stable unique label: no** (LOO shape stability flagged NO in prior phi2 report).

- **Cross-experiment:** **\(A(T)\)** is already well described by **barrier shape scores** on the snapshot tested (**Agent 24A**: PT-only beats adding \(\kappa_1\)). **\(R(T)\)** wants **barrier spread + a map-scale state term** (\(\kappa_1\)) in the best LOOCV row.

---

## 2. Observable catalog

The machine-readable catalog is **`tables/experimental_observable_catalog.csv`**. Grouped by role:

**Map / ridge (switching, measured or simple derivatives on map):** \(I_\mathrm{peak}\), \(S_\mathrm{peak}\), `width_mA`, measured `q90_minus_q50`, `asymmetry_q_spread`, `median_I_q50`, `skew_I_weighted`.

**PT / barrier geometry (from threshold PDF rows or barrier_descriptors):** `tail_width_q90_q50_PT`, `spread90_50`, PT `asymmetry`, `skew_pt_weighted`, `std_threshold_mA_PT`, `median_I_mA`, `iq75_25_mA`, `skewness_quantile`, `cheb_m2_z`, `pt_svd_score1/2`.

**Cross-experiment:** `X` (see `speak_vs_x_cross_experiment_report.md`), `A_T_interp`, `R_T_interp`.

**State / fit-linked (still “observables” only after decomposition):** `kappa1`, `kappa2`, `alpha` — listed in catalog as **latent-from-fit** for honesty.

**Shape descriptors for mode 2:** rows in `tables/phi2_structure_metrics.csv`.

---

## 3. Object-by-object replacement

| Object | What it is in the data | What observable tracks it | Model replace? | Paper replace? | Qualitative only? |
| --- | --- | --- | --- | --- | --- |
| PT backbone | Stacked threshold PDF / CDF | Quantile spreads, skew, median | Partial scalars | Yes (describe full map + summaries) | Never with one number alone |
| \(\Phi_1\) | Dominant residual shape on \(x\) | Visible symmetric deviation from backbone | Keep in fit | Yes | N/A |
| \(\kappa_1\) | Scalar weight on \(\Phi_1\) | PT tail width + \(S_\mathrm{peak}\); not raw map spread alone | Sometimes (predicts \(\kappa_1\)); not always for \(R\) | Yes as “correction strength” | — |
| \(\Phi_2\) | Next residual shape | Width/slope-like template match; even/odd energy | Keep in fit | Yes with caveats | Partial |
| \(\kappa_2\) | Scalar on \(\Phi_2\) | \(I_\mathrm{peak}\); barrier gaps (run-specific) | Often approximated | Yes as “secondary amplitude ∝ peak trend” | — |
| \(\alpha\) | \(\kappa_2/\kappa_1\) | PT skew + width; asymmetry + spread | Partial LOOCV | Yes with 22–24 K residual | Partly |

Formal categories: **`tables/latent_to_observable_replacement_table.csv`**.

---

## 4. What to point to on the **measured map**

- **\(\Phi_1\) (language):** After removing the **smooth threshold-PDF backbone**, the **largest leftover** is usually a **broad, mostly symmetric** change in **how “open” the ridge is** along the normalized ridge coordinate — not a sharp jump at one pixel.

- **\(\Phi_2\) (language):** Look for a **second, more localized** change: **shoulders** or **asymmetric steepening** on one side of the ridge, sometimes resembling **width modulation** of the main ridge rather than a simple lateral shift. Metrics: **even vs odd weight**, **center concentration**, **left/right shoulder ratio** (`phi2_structure_metrics.csv`).

- **\(\kappa_1\):** On the map, correlate mentally with **how tall/wide the active threshold sector is** in the **upper current tail** and with **overall map scale** (\(S_\mathrm{peak}\)). The **PT-side** upper spread tracks the fit amplitude better than the **raw map** q90−q50 on the small `alpha_structure` cohort (see `agent24h_correlations.csv`).

- **\(\kappa_2\):** Tracks trends in **where the ridge sits in \(I\)** (\(I_\mathrm{peak}\)) and **fine barrier asymmetry** — point to **changes in peak location** and **narrowing/broadening of the high-current tail** together.

- **\(\alpha\):** Read as **how secondary deformation compares to the main correction** — in practice tied to **PT asymmetry / skew** and **ridge width**, with a **kink** near **22–24 K** that is **not** fully captured by those scalars alone.

- **PT backbone:** Point to the **full threshold histogram / survival curve** at each \(T\); when compressing for slides use **median**, **q90−q50**, and **skew**.

---

## 5. Safe paper dictionary

See **`tables/paper_safe_observable_dictionary.csv`**. In short:

- Prefer **ridge**, **upper-threshold spread**, **map scale**, **PDF backbone**, **symmetric correction**, **width/slope bump**.
- Avoid **singular vector**, **latent direction**, **residual sector** unless you add the experimental translation in the same sentence.

---

## 6. Replacement tests (precomputed)

All rows cite existing artifacts in **`tables/observable_replacement_model_tests.csv`**. Highlights:

- **\(R\):** `spread + kappa1` vs `spread` only → **\(\kappa_1\) still buys ~1.87 RMSE** on \(n=10\).
- **\(A\):** **PT-only** slightly **beats PT+\(\kappa_1\)** in Agent 24A JSON — **\(\kappa_1\) not required** for that relaxation snapshot.
- **\(\kappa_1\) prediction:** **PT tail width + \(S_\mathrm{peak}\)** LOOCV **dominates** single-q90 models.
- **\(\alpha\):** **skew + width** beats **spread alone**; **adding \(\kappa_1\) hurts** LOOCV vs PT+asymmetry baseline.

---

## 7. Experimental-first minimal framework (rewrite)

**Switching:** The **threshold PDF** sets a **backbone**. The **switching map** differs from that backbone by a **dominant symmetric correction** (rank-one shape) whose **strength** is set by **upper-barrier spread** and **map scale**, plus a **smaller width/slope-like correction** (rank-two shape) tied in part to **peak current** and **barrier asymmetry**. The **deformation ratio** between second and first corrections is **partly** explained by **PT skew and ridge width**, with a **residual near 22–24 K**.

**Relaxation:** On the tested merge, **barrier shape scores** (e.g. **Chebyshev + PT SVD**) predict **\(A(T)\)** without **decomposition coefficients** — **observable-first** wording is justified there.

**Aging:** **Clock ratio \(R(T)\)** is **not** captured by **barrier spread alone** at the same LOOCV as **spread + \(\kappa_1\)** — keep **one state amplitude** (or an explicit substitute you validate) when claiming predictive language.

---

## 8. Final conclusion

The project **already crosses** into **experimentally named quantities** for **barrier geometry**, **ridge location/scale**, and **many predictive laws** (\(A\) snapshot; \(\kappa_1\) from spread+\(S\); \(\kappa_2\) from \(I_\mathrm{peak}\)). It **has not fully crossed** where **shapes** (\(\Phi_1,\Phi_2\)) matter: **fits should keep modes**, but **prose can describe what they look like on the map**. **\(\alpha\)** remains **partially latent** in the sense of **unresolved regime residual**.

---

## Artifacts index

| Deliverable | Path |
| --- | --- |
| Catalog | `tables/experimental_observable_catalog.csv` |
| Latent ↔ observable | `tables/latent_to_observable_replacement_table.csv` |
| Model tests | `tables/observable_replacement_model_tests.csv` |
| Paper dictionary | `tables/paper_safe_observable_dictionary.csv` |
| Correlations | `tables/agent24h_correlations.csv` |
| Report | `reports/experimental_observable_replacement_report.md` |
| Review ZIP | `review/experimental_observable_replacement_24h.zip` |

---

### Final output format (required)

KAPPA1_REPLACED_BY_OBSERVABLES: **PARTIAL — strong PT tail width + S_peak proxy; map-only spread insufficient; keep kappa1 for best R model**

KAPPA2_REPLACED_BY_OBSERVABLES: **PARTIAL — I_peak is primary simple proxy; full replacement depends on aligned pipeline**

ALPHA_REPLACED_BY_OBSERVABLES: **PARTIAL — PT skew + ridge width capture much; 22–24 K remainder; do not add kappa1 to alpha LOOCV per Agent 21C**

PHI1_TRANSLATED_TO_MAP_LANGUAGE: **YES — dominant broad symmetric deviation of the map from the PDF backbone**

PHI2_TRANSLATED_TO_MAP_LANGUAGE: **YES WITH CAVEATS — secondary width/slope shoulder pattern; template-match language; stability not perfect**

PROJECT_LANGUAGE_EXPERIMENTAL_READY: **PARTIAL — barrier/ridge/scaling language is ready; mode shapes stay fit-native with good map descriptions**

---

### Ten-line collaborator summary

1. We measure **switching maps** and build a **threshold PDF backbone** in current at each temperature.  
2. The map is **not** the PDF: the **first big difference** is a **smooth, mostly symmetric** correction along the ridge.  
3. The **strength** of that first correction tracks **how wide the high-current tail of the PDF is** and the **overall map scale** (\(S_\mathrm{peak}\)).  
4. A **smaller second difference** looks like **width and slope** structure near the ridge; it trends with **peak current** and **barrier skew**.  
5. The **ratio** of second-to-first correction is **partly** predicted by **PDF skew** and **ridge width**, but **not completely** — especially near **22–24 K**.  
6. For **relaxation time**, a **low-dimensional barrier shape** summary already works on the tested grid **without** decomposition coefficients.  
7. For the **aging clock ratio**, we still do best with **barrier spread plus one amplitude** tied to the **first correction** — spread alone is not enough.  
8. **\(X = I/(wS)\)** remains the cleanest **cross-experiment** coordinate for **relaxation**, compared with **\(S_\mathrm{peak}\)** alone.  
9. We should **say what we see on the map** for the two corrections instead of only naming **modes**.  
10. **Bottom line:** many “latent” scalars are already **the same information** as **spread, scale, peak, skew**; **shapes** stay in the fit but are **translatable** for a paper.

---

*Agent 24H — generated tables and report from repository canonical outputs; figures via `tools/agent24h_render_figures.ps1`.*
