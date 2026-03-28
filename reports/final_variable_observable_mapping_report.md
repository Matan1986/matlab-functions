# Final model variable ↔ observable mapping (Agent 24E)

**Type:** Survey and synthesis from existing tracked tables and `reports/*.md` (no heavy recomputation).  
**Authoritative repo context:** `docs/repo_state.json`, `docs/AGENT_RULES.md`, `docs/results_system.md`.

---

## Concise variable hierarchy

1. **Barrier object (PT)** — Per-temperature threshold distribution / CDF backbone in current \(I\) (or aligned current) space. Feeds scalar **geometry features** (quantile spreads, asymmetry, skew) and the **mean path** \(S_\mathrm{CDF}\) used to form residuals.
2. **Rank-1 correction** — Scalar **\(\kappa_1(T)\)** multiplying **\(\Phi_1(x)\)** : dominates **out-of-sample** improvement of the switching strip relative to PT-only baselines (closure test and full-prediction stack).
3. **Rank-2 correction** — Scalar **\(\kappa_2(T)\)** on **\(\Phi_2(x)\)** : measurable gain in some holdout metrics, but **aggregate** LOOCV increment over rank-1 is small for the \(S\) strip; \(\Phi_2\) is **not** LOO-stable as a shape.
4. **Deformation ratio** — **\(\alpha = \kappa_2/\kappa_1\)** : useful state variable; **partly** predicted from PT geometry (`\(\alpha_\mathrm{geom}\)`) with a **residual** `\(\alpha_\mathrm{res}\)` concentrated near 22–24 K.
5. **Trajectory / path** — Angles and steps in \((\kappa_1,\kappa_2)\) and smoothed \(\Delta\theta\): strong **associations** with \(R(T)\) in places, but **do not** beat compact PT summaries for \(R\) in the best LOOCV models surveyed; **negligible** for aggregate \(S\) LOOCV beyond rank-2 geom.
6. **Cross-experiment scalars** — **\(A(T)\)** (relaxation timescale family) and **\(R(T)\)** (aging clock ratio): **\(X = I_\mathrm{peak}/(w S_\mathrm{peak})\)** remains the preferred unified geometric bridge for \(A\); **\(R\)** is well served by **PT spread + \(\kappa_1\)** in Agent 24B.

---

## Task 1 — Model variables (role and interpretation status)

| variable | current mathematical role | physical interpretation status | status |
| --- | --- | --- | --- |
| PT backbone | PMF/CDF over threshold current; constructs \(S_\mathrm{CDF}\) and feature rows | Barrier / sampling geometry in \(I\)-space | **LOCKED** (object) / **OPEN** (microscopic physics) |
| \(\kappa_1\) | Rank-1 coefficient on \(\Phi_1\) in residual decomposition | Amplitude of dominant collective correction; co-determined by barrier spread and \(S_\mathrm{peak}\) | **PARTIAL** |
| \(\kappa_2\) | Rank-2 / orthogonal leftover amplitude | Couples strongly to \(I_\mathrm{peak}\); loads on mixed width/derivative-like shapes | **PARTIAL** |
| \(\alpha\) | \(\kappa_2/\kappa_1\) | PT-geometry component + regime residual near 22–24 K | **PARTIAL** |
| \(\Phi_1\) | First residual mode shape | Spatial pattern of rank-1 correction | **LOCKED** (within pipeline) |
| \(\Phi_2\) | Second mode shape | Kernel-reducible but not pure deformation span; LOO-unstable | **OPEN** |
| Trajectory | \(\Delta\theta\), \(ds\), \(\kappa\)-curve, arc length along \(T\) | Reorganization in \((\kappa_1,\kappa_2)\); bend near 22–24 K | **PARTIAL** |
| \(A(T)\) | Relaxation timescale(s) per Relaxation module | Response timescale; bridge via \(X\) | **PARTIAL** |
| \(R(T)\) | \(\tau_\mathrm{FM}/\tau_\mathrm{dip}\) | Aging clock; join to switching via PT + state | **PARTIAL** |

---

## Task 2 — Observable survey (existing artifacts)

### Registry (`docs/repo_state.json`)

- **Switching (core):** `S_peak`, `I_peak`, `width_I`; derived `asym`, `X`.
- **Aging (primary):** `Dip_depth`, `FM_abs`; derived `Dip_T0`, `Dip_sigma`, `FM_step_mag`, `R`.
- **Relaxation (primary):** `A`; derived `Relax_tau_T`, `Relax_beta_T`, `Relax_t_half`, `Relax_initial_slope`.
- **Minimal physics basis (declared):** `X`, `R`, `A`.

### Barrier / landscape (from PT runs and cross-experiment merges)

- Quantiles: `q50_I`, `q75_I`, `q90_I`, `q95_I` (see `tables/kappa1_from_PT.csv` and PT exports referenced in kappa/alpha reports).
- Spreads: `tail_width_q90_q50` (= **spread90_50** family), `q75_minus_q25`, `extreme_tail_q95_q75`.
- Mass / tail: `tail_mass_quantile_top12p5` (weak vs \(\kappa_1\) in Agent 20A).
- Summary / barrier tables: `mean_threshold_mA`, `median_I`, `std_threshold_mA`, `asym_q_barrier`, `skewness` / `skewness_quantile` (kappa2 report).
- **PT SVD scores** used in `R` trajectory vs PT-only models (Agent 23B).

### Switching geometry / ridge-related

- **Canonical geometric bridge:** `X` — defended vs `S_peak` alone for \(A\) and \(R\) alignment (`reports/speak_vs_x_cross_experiment_report.md`).
- From `tables/alpha_structure.csv` and related: `I_peak_mA`, `width_mA`, `S_peak`, `asymmetry_q_spread`, `skew_I_weighted`, quantile spreads on measured distributions.
- Composite / scan observables (e.g. ridge band widths, participation) appear in `reports/observable_search_report.md` — useful for appendix-level naming, **not** yet tied to \(\kappa_1\) in the surveyed kappa reports.

### Residual / collective

- **\(\kappa_1\), \(\kappa_2\), \(\alpha\)** per temperature (`tables/alpha_structure.csv` and decomposition runs).
- Rank spectrum / variance fractions (`reports/rank2_report.md`, `reports/closure_report.md`).
- Deformation coefficients \(\beta_1,\beta_2\) vs \(\kappa_2\) (`reports/deformation_closure_report.md`, `tables/deformation_closure_metrics.csv`).
- Mode coupling: \(\kappa_2\) partly explained by \(\kappa_1\) + PT mean (`reports/mode_coupling_report.md`).

### Trajectory / reorganization

- Constructs in Agent 23B: `delta_theta_rad`, `delta_theta_smoothed_rad`, `kappa_curve`, `ds_step`, `arc_length_cumulative`.
- Collective-state geometry: PCA of \((\kappa_1,\kappa_2)\), bend angle, speed ratios (`reports/collective_state_report.md`).
- Full prediction: **selected** trajectory feature for \(\alpha_\mathrm{res}\) is `delta_theta_smoothed_rad` with **negligible** aggregate LOOCV gain (`reports/full_prediction_with_trajectory.md`, Agent 24C).

---

## Task 3 — Matching (predictive vs geometric vs physical)

| variable | best predictive proxy | best geometric proxy | best physical proxy candidate |
| --- | --- | --- | --- |
| PT / landscape | Feature bundle in aging model: **spread90_50 + \(\kappa_1\)** for \(R\) | **spread90_50**, **asymmetry**, **skew_pt_weighted** | Quantile structure of barrier PMF |
| \(\kappa_1\) | **tail_width (q90−q50) + \(S_\mathrm{peak}\)** (Agent 20A LOOCV) | Same + **q90_I** | “Rank-1 collective amplitude” (operational) |
| \(\kappa_2\) | **\(I_\mathrm{peak}\)** (Agent 19A LOOCV) | **\(I_\mathrm{peak}\)** + barrier gap metrics | Second-mode amplitude onto \(\Phi_2\) |
| \(\alpha\) | **skew_pt_weighted + width_mA** (Agent 20B) | **asymmetry**, **spread90_50** | Split: \(\alpha_\mathrm{geom}\) + \(\alpha_\mathrm{res}\) |
| \(\Phi_1\) | Via **\(\hat\kappa_1 \Phi_1\)** (rank-1 stack) | Empirical \(\Phi_1(x)\) | Dominant deformation of switching curve |
| \(\Phi_2\) | Subleading **LOOCV** increment | Kernel correlations (d\(\Phi_1\)/dx, \(x\Phi_1\)) | Secondary shape / width-asymmetry mixture |
| Trajectory | **Smoothed \(\Delta\theta\)** for \(\alpha_\mathrm{res}\) (tiny gain) | **\(ds\)**, path metrics | Reorganization in collective plane |
| \(A(T)\) | **Power law in \(X\)** | **\(X\)** (preferred), \(S_\mathrm{peak}\) partial | Relaxation–switching bridge coordinate |
| \(R(T)\) | **spread90_50 + \(\kappa_1\)** (Agent 24B) | **PT SVD scores** (23B vs trajectory) | Barrier spread + collective amplitude |

**Rule used:** where LOOCV or holdout RMSE exists, it **outranks** correlation-only stories (per task instructions).

---

## Task 4 — \(\kappa_1\) interpretation check

See machine-readable rows in `tables/kappa1_interpretation_survey.csv`.

**Headline (conservative):** \(\kappa_1\) has a **strong, documented predictive reduction** using **barrier tail width and \(S_\mathrm{peak}\)**. It is **not** adequately summarized as “upper tail only” (tail-dominated flag is **NO** in Agent 20A). A **dedicated ridge-curvature ↔ \(\kappa_1\)** link is **not** evidenced in the surveyed reports. Calling \(\kappa_1\) “collective susceptibility” is **acceptable only as operational shorthand** for the **rank-1 coefficient**, not as an independent measured susceptibility. Equating \(\kappa_1\) with **failure / collapse amplitude** is **misleading** relative to the decomposition narrative.

---

## Task 5 — Final synthesis tables

### Table A — Model variable → best paper-facing proxy

| model variable | best existing observable proxy | evidence type | confidence | notes |
| --- | --- | --- | --- | --- |
| PT / landscape | **spread90_50** (+ other PT row features as needed) | LOOCV / multivariate aging | high | Scalar summaries are lossy; full row underpins \(\kappa_1\) models |
| \(\kappa_1\) | **(q90−q50) + \(S_\mathrm{peak}\)** | LOOCV | high | Report collinearity with \(S_\mathrm{peak}\) |
| \(\kappa_2\) | **\(I_\mathrm{peak}\)** | LOOCV | medium–high | \(\Phi_2\) shape stability caveat |
| \(\alpha\) | **skew_pt_weighted + width_mA**; discuss **\(\alpha_\mathrm{res}\)** | LOOCV + decomposition | medium | PT+kappa1 extension hurts LOOCV (21C) |
| \(\Phi_1\) | **Rank-1 term** in strip prediction | Holdout RMSE | high | |
| \(\Phi_2\) | **Rank-2 term** + kernel tests | RMSE + correlation | low–medium | Unstable under LOO shape removal |
| Trajectory | **\(\Delta\theta\)** (narrative); **smoothed** for \(\alpha_\mathrm{res}\) | LOOCV comparisons | low–medium | Negligible for aggregate \(S\) |
| \(A(T)\) | **\(X\)** | LOO + peak alignment | high | |
| \(R(T)\) | **spread90_50 + \(\kappa_1\)** | LOOCV | medium–high | Trajectory add-on not rewarded in 24B |

### Table B — Physical concept → candidates

| physical concept | candidate observable(s) | status |
| --- | --- | --- |
| landscape accessibility | PT quantiles; spread90_50; asymmetry; skew; barrier descriptor spreads | **LOCKED** as multivariable / **OPEN** as one number |
| collective response amplitude | \(\kappa_1\); \(\hat\kappa_1\) from PT+\(S\) | **PARTIAL** |
| second-mode / deformation | \(\kappa_2\); \(\beta_1,\beta_2\) | **PARTIAL** |
| reorganization strength | \(\Delta\theta\), \(ds\), arc length, bend metrics | **PARTIAL** (narrative > \(S\) LOOCV) |
| instability / regime proximity | 22–24 K band; \(\alpha_\mathrm{res}\); \(\kappa_2\) spike | **OPEN** |
| relaxation bridge | \(X\) | **PARTIAL–strong** for \(A\) |
| aging bridge | spread90_50 + \(\kappa_1\); PT SVD | **PARTIAL–strong** for \(R\) |

---

## Open ambiguities

- **Single-scalar PT:** No single barrier number captures both aging and switching needs; papers should show **which scalar** is used for which claim.
- **\(\Phi_2\) naming:** Kernel affinity **does not** imply a unique physical label; LOO instability argues against treating \(\Phi_2\) as a fixed “material mode.”
- **Trajectory:** Useful for **geometry of state-space paths** and some \(R\) associations; **not** a substitute for PT+state in the best \(R\) models surveyed, and **not** needed for \(S\) at the reported LOOCV resolution.
- **Legacy vs canonical runs:** Some older reports (e.g. coefficient physics 18B) use different tail constructs than Agent 20A—**prefer 20A/24B** for publication numbers unless reproducing a specific historical run.

---

## Paper-oriented symbol / naming recommendations

- **Keep** \(\kappa_1\), \(\kappa_2\), \(\alpha = \kappa_2/\kappa_1\) with explicit “from residual decomposition on aligned switching strip.”
- **Distinguish** **PT** (distribution / CDF object) from **PT scalars** (e.g. **\(W = q_{90}-q_{50}\)**, **spread90_50**, **asymmetry**).
- **Use** **\(X\)** for the cross-experiment switching–relaxation bridge; **avoid** presenting **\(S_\mathrm{peak}\)** alone as equivalent to \(X\) for multi-experiment claims.
- **Use** **\(R\)** for the aging clock ratio with the **interpolation caveat** when aligned to the switching temperature grid.
- **Cite** \(\alpha = \alpha_\mathrm{geom} + \alpha_\mathrm{res}\) when discussing regime residuals; **do not** claim \(\alpha = f(\mathrm{PT},\kappa_1)\) improves LOOCV without noting Agent 21C’s negative delta.
- **Present** trajectory terms as **secondary** to rank-1 structure for **\(S\)**, and as **non-dominant** vs PT+state for **\(R\)** in the best models surveyed.

---

## Deliverables (this agent)

| file | purpose |
| --- | --- |
| `tables/final_variable_mapping.csv` | Per-variable roles, proxies, evidence, confidence |
| `tables/kappa1_interpretation_survey.csv` | Structured \(\kappa_1\) interpretation audit |
| `tables/physical_proxy_candidates.csv` | Concept → observable mapping |
| `reports/final_variable_observable_mapping_report.md` | Human-readable synthesis (this file) |

---

*Survey date: 2026-03-26. Sources include `reports/kappa1_from_PT_report.md`, `reports/kappa2_state_geometry_report.md`, `reports/alpha_structure_report.md`, `reports/alpha_from_PT_report.md`, `reports/alpha_with_kappa1_report.md`, `reports/alpha_decomposition_report.md`, `reports/full_prediction_with_trajectory.md`, `reports/R_state_report.md`, `reports/R_trajectory_report.md`, `reports/aging_prediction_report.md`, `reports/speak_vs_x_cross_experiment_report.md`, `reports/closure_report.md`, `reports/collective_state_report.md`, `reports/phi2_physics_report.md`, `reports/deformation_closure_report.md`, `reports/mode_coupling_report.md`, `reports/rank2_report.md`, `reports/coeff_physics_report.md`, and root `tables/*.csv` headers.*
