# REPO-INFRA-02: Repository-wide non-MATLAB inventory and MATLAB conversion plan

## Policy authority and scope (governing)

- `REPO_INFRA_01B_AVAILABLE` = **YES**
- `GOVERNING_POLICY` = **REPO-INFRA-01B**
- `POLICY_SCOPE` = **repository-wide**

The repository-wide language, figure, accelerator, and promotion policy is defined in `reports/maintenance/repo_language_figure_policy_INFRA_01B.md`. This document is **authoritative** for all modules (Switching, Relaxation, Aging, MT, cross-module, maintenance, tools, and documentation context). The earlier Relaxation-only `RLX-INFRA-01` family remains a **valid historical record** but is **superseded in scope** by REPO-INFRA-01B, not deleted and not automatically invalidated by language choice.

## 1. Executive summary

A repository-wide search for non-MATLAB script extensions (for example `mjs`, `js`, `py`, `ipynb`, `R`, `sh`, `ps1`, `jl`, `lua`) was performed, excluding the vendored `github_repo` tree. **139** script files were found. The highest-risk groups are: (1) **non-MATLAB scientific figure emitters** (PowerShell `System.Drawing` and `Chart`, Python `matplotlib`, and a dedicated Switching canonical-paper pack) that conflict with the default **MATLAB-first figure** rule unless explicitly approved per task; (2) the **Relaxation Node (`mjs`) chain** around **RLX-22 through RLX-24**, which implements **interpolation, time-warp style collapse, smoothing, and log-time derivative and rate-spectrum style** analyses; and (3) **cross-module** `mjs` and **orchestration** `ps1` that perform **OLS, LOOCV, and model-style scoring** outside MATLAB. **RLX-23** requires **full MATLAB parity** before manuscript use of time-spectrum or rate-style claims. **RLX-22B** requires **MATLAB parity for the time-warp and interpolation-heavy claims**; the existing report already sets conservative manuscript gates (treated here as **PARTIAL** relative to a full end-to-end replay). **Non-MATLAB results are not automatically invalid**; they remain **provisional** until parity or documented review, per INFRA-01B. **MT** and **docs** paths contained **no** such script files in this extension survey; **MT** and **Docs** row counts in the inventory are **zero** for this file-type definition.

## 2. Repository-wide search scope and limitations

- **Searched:** Entire working tree with the extension list above, **excluding** `github_repo/`, `node_modules/`, and `.git/`.
- **Not counted as non-MATLAB analysis:** `.m` MATLAB sources; binary data; static `md` and `csv` except as **outputs** of scripts in lineage.
- **Limitation:** Role and risk for each file use **name, path, and spot-check of headers**; `analysis_new/.../xy/...` mirrors are marked as **legacy or duplicate copies** and should be **BLOCKING_UNKNOWN** until someone confirms whether they remain wired into active workflows.
- **Limitation:** Run-scoped outputs under `results/` and `results_old/` are only partially enumerated in lineage; follow each runner header for exact directories.

## 3. Inventory of non-MATLAB scripts by module

Machine-readable rows: `tables/maintenance_repo_nonmatlab_inventory_INFRA_02.csv`.

| Module label | Approximate row count (this survey) |
| --- | ---: |
| Switching | 46 |
| Tools | 23 |
| Maintenance | 30 |
| CrossModule | 22 |
| Relaxation | 11 |
| Aging | 4 |
| Unknown | 3 |
| Docs | 0 |
| MT | 0 |

## 4. What each major script family appears to do

- **Relaxation `mjs` (RLX-15, 20 console, 21, 22, 22B, 23, 24, AX-18C):** Reads canonical relaxation and cross-module CSVs; writes **new** `tables/relaxation/*.csv` and `reports/relaxation/*.md`. RLX-23 and RLX-24 implement **moving-window smoothing**, **finite-difference and local-regression style derivatives on log-time**, and **classification and robustness tables**. RLX-22B implements **interpolation (`interp1` style)** on time grids, **vertical and horizontal collapse**, and **incremental time-warp gain** relative to tau proxies. RLX-20 audit emits **JSON to stdout only**.
- **Switching and analysis `ps1`:** Mix of **orchestrated MATLAB runs**, **audits**, and **WinForms chart** pipelines that **SaveImage** many **PNG** panels (for example kernel collapse and barrier projection).
- **Switching `run_switching_canonical_paper_figures.ps1`:** Assembles **PNG and PDF** under `results/switching/figures/canonical_paper/` with manifest and status tables when inputs exist.
- **Tools Python:** `matplotlib` **savefig** to `figures/` or `run_dir/figures` for kappa, aging prediction, and spread observables; **not** the default MATLAB **fig+png** contract unless explicitly approved.
- **Maintenance and inventory `ps1` / `py`:** Fingerprint, governor, validation, and table **accelerators** (generally **lower** science risk when they only rearrange or audit existing CSVs).

## 5. Output lineage and affected artifacts

Machine-readable families: `tables/maintenance_repo_nonmatlab_output_lineage_INFRA_02.csv`.

Key **Relaxation** families (partial list): `relaxation_plateau_timewarp_22B_*`, `relaxation_universal_time_spectrum_23_*`, `relaxation_slow_tail_robustness_24_*`, `relaxation_canonical_timescale_22_*`, `relaxation_internal_time_correlations_21_*`, matching **reports** `relaxation_*.md` with the same stem.

Key **Switching** families: `results/switching/figures/canonical_paper/*.{png,pdf}` plus `tables/switching_canonical_paper_figures_*.csv`.

Key **Tools** figure families: `figures/kappa2_vs_shape.png`, `figures/R_vs_prediction.png`, other agent tool PNGs named in each script header.

## 6. Risk classification

- **HIGH:** Non-MATLAB **figure generation** for scientific or paper-style outputs; **RLX-23** and **RLX-24** derivative and smoothing stacks; **RLX-22B** timewarp and interpolation; **AX-18C** OLS and LOOCV.
- **MEDIUM:** Orchestration scripts where scientific transforms may be embedded; Python utilities without figures that still emit **metrics**.
- **LOW:** Scratch (`tmp`, `.codex_tmp`, `_legacy`) and **pure inventory** scripts that do not claim new physics metrics.

Ranked examples: `tables/maintenance_repo_nonmatlab_risk_ranking_INFRA_02.csv`.

## 7. What is safe to keep as accelerator

- **Table-only** inventory, manifest, fingerprint, and **stdout JSON QC** (RLX-20 style) when outputs are clearly labeled and **do not** silently become manuscript evidence.
- **Maintenance** governor and **read-only** audits that do not compute new smoothed derivatives or figures.

## 8. What is provisional until MATLAB parity

- All **non-MATLAB scientific metrics** and any output in the INFRA-01B **parity domains** (smoothing, derivatives, interpolation, fitting, time-warping, rate-spectrum style extraction, reconstruction, decomposition, model selection).
- All **non-MATLAB figures** until replaced by **MATLAB `.fig` and `.png`** for the same scientific task or explicitly approved otherwise for that task.

## 9. What should be converted or replayed in MATLAB

- **First:** Non-MATLAB **publication or review** figure paths (Switching canonical paper pack, major `analysis/*.ps1` chart suites, Tools `matplotlib` and `System.Drawing` emitters).
- **Second:** **RLX-23** and **RLX-24** **full replay** or port into `Relaxation ver3/`-style MATLAB naming (exact new filenames are **not** created in this inventory task).
- **Third:** **RLX-22B** parity on **interpolation and timewarp** metrics; keep narrative aligned with existing **conservative gates** in the markdown report.
- **Fourth:** **AX-18C** **OLS and LOOCV** baseline tables in MATLAB for inspectable linear algebra.

## 10. Priority conversion and parity plan

Machine-readable plan: `tables/maintenance_repo_matlab_conversion_plan_INFRA_02.csv`.

- **P0 (figure policy):** At least **two** entries in the plan (Switching canonical paper figures; `tools/agent24h_render_figures.ps1`) are **convert or quarantine** items.
- **P1 (science parity):** RLX-23, RLX-24, RLX-22B, RLX-22, AX-18C, and high-priority Switching **WinForms** analysis scripts.

## 11. MATLAB parity requirements

Checklist: `tables/maintenance_repo_matlab_parity_requirements_INFRA_02.csv` (input identity, row counts, schemas, numeric tolerances, flags, **fig+png** when applicable, **no non-MATLAB figure generation** for canonical promotion, lineage documentation, manuscript claim gating for RLX-23 and RLX-24).

**Suggested tolerances:** exact match on **row counts** and **status flag strings**; **1e-10** absolute for **direct stable arithmetic** on the same float grid; **larger** tolerances only with a **short written justification** tied to **smoothing or grid** differences.

## 12. What is not invalidated

- **RLX-INFRA-01** artifacts and all **existing** CSV and report files remain **valid historical records**; they are not deleted by this survey.
- **Non-MATLAB** outputs are **not** false solely because of language; they are **provisional** where INFRA-01B says so.

## 13. Recommended next steps

1. Treat `reports/maintenance/repo_language_figure_policy_INFRA_01B.md` as the **only** governing policy for **language, figures, accelerators, and promotion** (repository-wide).
2. If **P0** figure scripts remain in active manuscript or review paths, **schedule MATLAB figure conversion** (or obtain **explicit per-task** non-MATLAB approval and still align with review expectations).
3. If **RLX-23** or **RLX-24** slow-tail conclusions are needed for a paper, open a **dedicated MATLAB parity task** for those stems **before** promoting claims.
4. If **RLX-22B** timewarp or interpolation claims are needed beyond the **built-in conservative gates**, run a **MATLAB replay** of the same **inputs** and compare **key CSV columns** to the `mjs` outputs under the tolerances in the parity table.
5. For **Switching and Aging** high-risk **PS1 and Python** figure paths, open **module-ordered** parity tasks after P0 **Switching** paper-figure policy is clear.
6. Resolve whether **`analysis_new/**` mirror scripts** are obsolete; if obsolete, **quarantine_until_review** at the directory level to reduce **BLOCKING_UNKNOWN** risk.

## Artifact index (INFRA-02)

| Artifact |
| --- |
| `reports/maintenance/repo_nonmatlab_inventory_conversion_plan_INFRA_02.md` (this file) |
| `tables/maintenance_repo_nonmatlab_inventory_INFRA_02.csv` |
| `tables/maintenance_repo_nonmatlab_output_lineage_INFRA_02.csv` |
| `tables/maintenance_repo_nonmatlab_risk_ranking_INFRA_02.csv` |
| `tables/maintenance_repo_matlab_conversion_plan_INFRA_02.csv` |
| `tables/maintenance_repo_matlab_parity_requirements_INFRA_02.csv` |
| `tables/maintenance_repo_nonmatlab_inventory_INFRA_02_status.csv` |
