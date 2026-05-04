# REPO-FIG-INFRA-04B — Agent24H renderer input lineage and traceability

## 1. Executive summary

The MATLAB replacement path for `tools/agent24h_render_figures.ps1` requires three CSV tables under `tables/`. None of those files were present in the working tree at this audit, and `tables/agent24h_correlations.csv` was also absent. Legacy PNGs under `figures/` for the three panels **do** exist. Git reports `tables/**` as ignored, so restored or regenerated table CSVs would typically remain **local-only** unless ignore rules or tracking policy change.

Lineage review shows **traceable** upstream writers in the repository for `alpha_structure.csv`, `phi2_structure_metrics.csv`, and `kappa1_from_PT.csv`. The correlations CSV is **not** a separate upstream scientific product; it is **exported by** the PowerShell renderer (and mirrored by the MATLAB replacement into a non-destructive filename). Panel three bar values remain **numeric literals** embedded in both the PowerShell and MATLAB scripts, not CSV-driven; provenance for promotion must be reconciled with authoritative LOOCV or aging outputs outside this audit.

**Decision:** `INPUTS_MISSING_BUT_TRACEABLE_REGENERATE_NEXT` — regenerate prerequisite tables using named in-repo pipelines, then run the replacement; formal retirement of the figure path is **not** recommended solely on missing CSVs.

## 2. Why INFRA-04B was needed

INFRA-04 established the non-MATLAB renderer and added a MATLAB replacement candidate but could not execute it because required `tables/` inputs were missing. INFRA-01B and INFRA-03B require closure: either traceable MATLAB `.fig` + `.png` replacement or documented retirement. This task answers whether missing inputs are **recoverable with repo-backed lineage**, without regenerating data or running pipelines.

## 3. Required inputs and current status

| Artifact | Role | Present in working tree | Tracked in git |
| --- | --- | --- | --- |
| `tables/alpha_structure.csv` | Input to PS1 and replacement | NO | NO (path under `tables/` ignore) |
| `tables/phi2_structure_metrics.csv` | Input to PS1 and replacement | NO | NO |
| `tables/kappa1_from_PT.csv` | Input to PS1 and replacement | NO | NO |
| `tables/agent24h_correlations.csv` | **Output** of PS1 (Pearson summary) | NO | NO |

Legacy raster outputs `figures/latent_vs_observable_proxy_comparison.png`, `figures/phi1_phi2_in_experimental_language.png`, and `figures/observable_replacement_summary.png` **were** present at audit time.

## 4. Search method

- Repository-wide search (rg-style) for the four basenames, the three PNG stems, and `agent24h_render_figures`.
- Read of `tools/agent24h_render_figures.ps1`, `tools/agent24h_render_figures_matlab_replacement.m`, and minimal reads of candidate upstream scripts identified by hits.
- `Test-Path` on required paths; `git ls-files` and `git check-ignore` for tracking and ignore state.

No MATLAB, Python, or figure generation was executed.

## 5. Search findings

- **Inputs:** All four CSV paths are missing on disk; `git ls-files` lists none of them.
- **Ignore:** `.gitignore` matches `tables/**`, so table CSVs are expected to be ignored when present locally.
- **References:** Multiple analysis and tools scripts reference `alpha_structure.csv`, `phi2_structure_metrics.csv`, and `kappa1_from_PT.csv` as read or write targets. `agent24h_correlations.csv` appears in source-of-truth audits as **no run backing** and is written only by the renderer path (plus parallel MATLAB script `analysis/run_agent24h_figures.m` for equivalent outputs).
- **Upstream writers identified:** See section 6.

## 6. Lineage assessment

**`tables/alpha_structure.csv`**  
- **Candidate upstream:** `analysis/run_alpha_structure_agent19f.m` documents write of `tables/alpha_structure.csv` via `writetable` after `switching_residual_decomposition_analysis` with explicit `decCfg` run identifiers.  
- **Lineage traceable:** YES for regeneration **from** that pipeline (subject to availability of underlying switching decomposition inputs and run IDs used in the script).

**`tables/phi2_structure_metrics.csv`**  
- **Candidate upstream:** `Switching/analysis/run_phi2_shape_physics_test.m` sets `metricsPath` to `tables/phi2_structure_metrics.csv` and calls `writetable(metricsTbl, metricsPath)`.  
- **Lineage traceable:** YES for regeneration **from** that script’s documented flow.

**`tables/kappa1_from_PT.csv`**  
- **Candidate upstream:** `analysis/run_kappa1_from_pt_agent20a.m` invokes `tools/run_kappa1_from_pt_agent20a.ps1` and documents output `tables/kappa1_from_PT.csv`.  
- **Lineage traceable:** YES for regeneration **from** that entrypoint.

**`tables/agent24h_correlations.csv`**  
- **Role:** Output of `tools/agent24h_render_figures.ps1` (`Export-Csv` after computing Pearson rows). The MATLAB replacement writes `tables/infra_04_agent24h_replacement_correlations.csv` instead.  
- **Lineage traceable:** YES as a **deterministic derivative** of the same loaded columns and the same correlation logic as the scripts; it is not a separate first-class dataset with its own science pipeline in the same sense as the three tables.

**Figure three (observable replacement summary):** Bar heights are **literals** in both PS1 and the MATLAB replacement (same numeric constants). That is traceable to **source code** but not to a CSV input; manuscript-grade promotion still requires cross-check against authoritative LOOCV exports (out of scope here).

## 7. Decision

**Primary:** `INPUTS_MISSING_BUT_TRACEABLE_REGENERATE_NEXT`

Prerequisite tables can be reproduced using named in-repo generators **once** the operator runs those pipelines with supported inputs. Missing files alone do **not** justify retirement without a separate scope decision.

**Secondary nuance:** Treat panel-three literals and the correlations export as a **split path**: CSV-backed panels need regenerated tables; literal panel and correlation audit trail need explicit reconciliation if outputs are promoted beyond sandbox labeling.

## 8. What remains quarantined

Per INFRA-01B / INFRA-03B, **System.Drawing**-origin PNGs at the legacy `figures/*.png` paths and any PS1-generated `agent24h_correlations.csv` remain **non-authoritative** for default manuscript or canonical scientific promotion until superseded by MATLAB `.fig` + `.png` from an approved run or the path is explicitly retired in writing. This audit does not change that posture.

## 9. Recommended next step

1. Materialize `tables/alpha_structure.csv`, `tables/phi2_structure_metrics.csv`, and `tables/kappa1_from_PT.csv` by running the documented upstream entrypoints (or a single orchestrated maintenance run approved by owners), respecting repository execution policy.  
2. Execute `tools/agent24h_render_figures_matlab_replacement.m` through the approved MATLAB wrapper when ready; compare outputs under `figures/infra_04_agent24h_replacement/` to legacy PNGs.  
3. If panel three must be evidence-grade, replace literals with values tied to a cited LOOCV or aging artifact, or document intentional sandbox-only status.

---

**Audit metadata:** No scientific rerun; no figure generation; no deletion; no staging, commit, or push; ASCII artifacts only.
