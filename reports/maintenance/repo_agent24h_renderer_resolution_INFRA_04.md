# REPO-FIG-INFRA-04: Agent24h System.Drawing renderer resolution

## 1. Executive summary

`tools/agent24h_render_figures.ps1` is a **true non-MATLAB figure path**: it loads **System.Drawing**, rasterizes **three** PNG panels plus exports **`tables/agent24h_correlations.csv`**. This violates default manuscript or canonical scientific figure policy under `reports/maintenance/repo_language_figure_policy_INFRA_01B.md` unless explicitly approved. Per `reports/maintenance/repo_nonmatlab_P0_figure_decision_INFRA_03.md` and `reports/maintenance/repo_nonmatlab_P0_figure_mandatory_remediation_INFRA_03B.md`, quarantine is **temporary**; the mandatory outcome is **MATLAB `.fig` + `.png`** replacement **or** documented **retirement**.

**Resolution taken:** A **MATLAB replacement candidate** script was added: `tools/agent24h_render_figures_matlab_replacement.m`. It mirrors the visual and numeric intent of the PowerShell script, writes **only** to **`figures/infra_04_agent24h_replacement/`** and **`tables/infra_04_agent24h_replacement_correlations.csv`** so existing repo artifacts are not overwritten. The original PowerShell script was **not** edited or deleted.

**Gap:** In this working tree, **`tables/alpha_structure.csv`**, **`tables/phi2_structure_metrics.csv`**, and **`tables/kappa1_from_PT.csv`** were **not present** at audit time, so a full parity run of figures one and two cannot be executed here without restoring inputs. The third figure uses **literals embedded in the PowerShell script** (not CSV-backed); the MATLAB port preserves those constants with comments.

## 2. Original script role

The script header states intent: render PNG figures from **canonical CSVs** without MATLAB, useful for **CI or sandbox** acceleration. It:

- Reads `tables/alpha_structure.csv` for latent versus observable scatter relationships.
- Reads the **first row** of `tables/phi2_structure_metrics.csv` for Phi2 descriptor bars and explanatory text.
- Optionally reads `tables/kappa1_from_PT.csv` for additional correlation rows.
- Writes three PNGs under `figures/` and exports **`tables/agent24h_correlations.csv`** (Pearson mirrors).

## 3. System.Drawing and non-MATLAB figure issue

`Add-Type -AssemblyName System.Drawing` plus **`System.Drawing.Bitmap`**, **`Graphics`**, pens, brushes, fonts, and **`ImageFormat::Png`** implement **all** raster figure output. There is **no MATLAB figure object** and **no `.fig`** sidecar. Under INFRA-01B, this cannot serve as a **final** scientific or default manuscript figure path without explicit non-MATLAB approval.

## 4. Inputs and outputs identified

**Inputs (paths fixed in script):**

| Path | Role |
| --- | --- |
| `tables/alpha_structure.csv` | Columns used: `T_K`, `kappa1`, `kappa2`, `alpha`, `q90_minus_q50`, `S_peak`, `I_peak_mA`, `asymmetry_q_spread` |
| `tables/phi2_structure_metrics.csv` | First row: `phi2_even_energy_fraction`, `phi2_center_energy_frac_abs_x_le_tight`, `phi2_shoulder_tail_ratio_R_over_L`, `phi2_best_kernel_abs_corr`, `phi2_best_kernel_name` |
| `tables/kappa1_from_PT.csv` | Columns used: `kappa1`, `tail_width_q90_q50`, `S_peak` for masked pairwise-complete correlation rows |

**Outputs (original script):**

| Output | Type |
| --- | --- |
| `figures/latent_vs_observable_proxy_comparison.png` | PNG, four scatter panels |
| `figures/phi1_phi2_in_experimental_language.png` | PNG, bars plus narrative text |
| `figures/observable_replacement_summary.png` | PNG, two bar-chart comparisons |
| `tables/agent24h_correlations.csv` | CSV, Pearson summary |

**Embedded literals (figure three):** Aging LOOCV RMSE bars use **hardcoded** numeric constants in the PowerShell source (`y1a`, `y1b`, `y2a`, `y2b`); they are **not** recomputed from CSV in that script.

## 5. Visual and scientific intent

1. **Figure one:** Four scatter panels relating **latent scalars** (`kappa1`, `kappa2`, `alpha`) to **map or ridge observables** (`q90_minus_q50`, `S_peak`, `I_peak_mA`, asymmetry), colored by **`T_K`**, with **Pearson rho** in each subtitle. Overall title: latent decomposition versus direct observables.
2. **Figure two:** Four bar metrics summarizing **Phi2 shape descriptors** from stored metrics, plus a plain-language explanation block referencing rank-one and rank-two correction roles (switching ridge context in prose).
3. **Figure three:** Side-by-side bar comparisons for **aging LOOCV RMSE** style summaries labeled **spread only** versus **+ kappa1**, and **latent versus observable** RMSE pairs **`k1~W+S`** versus **`k2~Ipeak`**, using the script literals.

Scientific role is **interpretive visualization** of tabulated agent outputs; **not** a substitute for full MATLAB analysis pipelines. **`agent24h_correlations.csv`** is a numeric audit trail, not a figure.

## 6. Decision

**MATLAB replacement candidate created** (`tools/agent24h_render_figures_matlab_replacement.m`). **Formal retirement** of the PowerShell path was **not** chosen because INFRA-03B requires a **concrete** MATLAB or retirement resolution; a documented MATLAB port addresses the default policy gap while leaving the legacy accelerator **unchanged** for sandbox use until the project promotes the MATLAB outputs.

## 7. Replacement script behavior and output locations

- **Inputs:** Same `tables/*.csv` paths as the PowerShell script (relative to repository root derived from the `.m` file location).
- **Outputs (non-destructive):**
  - `figures/infra_04_agent24h_replacement/latent_vs_observable_proxy_comparison.fig` and `.png`
  - `figures/infra_04_agent24h_replacement/phi1_phi2_in_experimental_language.fig` and `.png`
  - `figures/infra_04_agent24h_replacement/observable_replacement_summary.fig` and `.png`
  - `tables/infra_04_agent24h_replacement_correlations.csv`
- **Behavior:** Errors early with a clear message if required CSVs are missing. Figure three uses the **same literal constants** as the PowerShell script, documented in comments.

No execution was performed in this task; **no** overwrite of existing `figures/*.png` or `tables/agent24h_correlations.csv`.

## 8. If the replacement were not created (not applicable)

Not applicable; a replacement script was added. If inputs remain unavailable, the next task is to **restore or regenerate** the canonical CSVs from their owning pipeline, then run the MATLAB script once under project execution rules and compare outputs to the quarantined PNGs.

## 9. What remains quarantined

Under INFRA-03 / INFRA-03B, the **original** PNG paths produced by **System.Drawing** (`figures/latent_vs_observable_proxy_comparison.png`, `figures/phi1_phi2_in_experimental_language.png`, `figures/observable_replacement_summary.png`) remain **quarantined for canonical or manuscript authority** until either:

- MATLAB outputs at the **same stems** (or policy-approved relocations) supersede them with **`.fig` and `.png`**, or
- Those paths are **explicitly retired** in documentation.

The new MATLAB outputs live under a **separate** directory name until promotion; **quarantine applies to the legacy raster path**, not to the MATLAB candidate folder.

## 10. Recommended next step

1. Materialize or locate the pipelines that write **`alpha_structure.csv`**, **`phi2_structure_metrics.csv`**, and **`kappa1_from_PT.csv`** into `tables/`.
2. Run `tools/agent24h_render_figures_matlab_replacement.m` once (via approved repo MATLAB execution policy when used in automation) and perform a **visual diff** against the existing PNGs for acceptance.
3. Either **promote** the MATLAB outputs to the canonical `figures/` stems with **`savefig` and `exportgraphics`**, or record **retirement** of the System.Drawing bundle if the visuals are deprecated.

---

**Governance references:** `reports/maintenance/repo_language_figure_policy_INFRA_01B.md`, `reports/maintenance/repo_nonmatlab_P0_figure_decision_INFRA_03.md`, `reports/maintenance/repo_nonmatlab_P0_figure_mandatory_remediation_INFRA_03B.md`.
