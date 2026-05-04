# REPO-FIG-INFRA-04C — MATLAB replacement execution and CV07 technical closure

## 1. Executive summary

This maintenance run attempted to materialize the three traceable input CSVs (`tables/alpha_structure.csv`, `tables/phi2_structure_metrics.csv`, `tables/kappa1_from_PT.csv`), then execute `tools/agent24h_render_figures_matlab_replacement.m` via `tools/run_matlab_safe.bat`. None of the prerequisite scientific switching run artifacts referenced by the generators are present in this working tree (for example `results/switching/runs/run_2026_03_10_112659_alignment_audit/switching_alignment_core_data.mat` and the Agent 20A `PT_matrix.csv` path). Generator runs failed or degraded before writing valid target tables. The MATLAB replacement exited with an error because `tables/alpha_structure.csv` is missing. Legacy PNGs under `figures/` at their historical paths were not modified. CV07 cannot be closed technically in this environment until switching decomposition inputs are restored or paths are re-pointed in an approved scope.

## 2. Why CV07 requires MATLAB replacement

The legacy path `tools/agent24h_render_figures.ps1` uses System.Drawing (non-MATLAB) rendering. Repository figure policy (INFRA-01B / INFRA-03B) requires a MATLAB-native `.fig` plus `.png` replacement or documented retirement for scientific or canonical promotion. The approved candidate is `tools/agent24h_render_figures_matlab_replacement.m`, which writes non-destructive outputs under `figures/infra_04_agent24h_replacement/` and a separate correlations CSV, avoiding legacy PNG overwrite.

## 3. INFRA-04B input-lineage basis

INFRA-04B (`reports/maintenance/repo_agent24h_renderer_input_lineage_INFRA_04B.md`) classified the three CSVs as missing but traceable to named upstream writers: `analysis/run_alpha_structure_agent19f.m`, `Switching/analysis/run_phi2_shape_physics_test.m`, and `analysis/run_kappa1_from_pt_agent20a.m` (delegating to `tools/run_kappa1_from_pt_agent20a.ps1`). It noted that `tables/agent24h_correlations.csv` is renderer output, not an independent upstream dataset.

## 4. Generator audit

| Entrypoint | Expected primary targets | Other writes | Unrelated overwrite risk |
| --- | --- | --- | --- |
| `analysis/run_alpha_structure_agent19f.m` | `tables/alpha_structure.csv` | `figures/alpha_vs_T.png`, `reports/alpha_structure_report.md` | Rewrites those paths if re-run; depends on fixed `decCfg` run IDs under `results/switching/runs/`. |
| `Switching/analysis/run_phi2_shape_physics_test.m` | `tables/phi2_structure_metrics.csv` | `tables/phi2_kernel_comparison.csv`, `tables/phi2_regime_stability.csv`, `reports/run_phi2_shape_physics_test.md`; may append `matlab_error.log` | Extra CSVs are documented companions; not legacy agent24h PNGs. |
| `analysis/run_kappa1_from_pt_agent20a.m` | Invokes PS1 to write `tables/kappa1_from_PT.csv` | `reports/kappa1_from_PT_report.md` (via PS1) | PS1 reads fixed paths only; standard outputs go to repo-root `tables/` and `reports/`. |

No generator in this audit was observed targeting legacy CV07 PNG basenames at `figures/*.png`; the replacement script uses a dedicated subdirectory.

## 5. Input materialization result

| Input | Result | Notes |
| --- | --- | --- |
| `tables/alpha_structure.csv` | NOT created | `switching_residual_decomposition_analysis` failed: missing `switching_alignment_core_data.mat` for run `run_2026_03_10_112659_alignment_audit`. MATLAB wrapper exit code 1. |
| `tables/phi2_structure_metrics.csv` | INVALID placeholder | Script caught the same missing-map error; catch block wrote a one-row NaN table (nonzero file size, report `FAIL`). |
| `tables/kappa1_from_PT.csv` | NOT created | PowerShell could not import default `PT_matrix.csv` (directory for `run_2026_03_25_013849_pt_robust_minpts7` missing). MATLAB wrapper exit code 1. |

## 6. MATLAB replacement execution result

Command shape: `tools/run_matlab_safe.bat` with absolute path to `tools/agent24h_render_figures_matlab_replacement.m`.

Outcome: **FAILED** at input validation. Error: missing `tables/alpha_structure.csv`. Exit code from wrapper path: **1**.

No outputs were written under `figures/infra_04_agent24h_replacement/` and no `tables/infra_04_agent24h_replacement_correlations.csv` was created.

## 7. Output inventory

| Artifact | Created |
| --- | --- |
| `figures/infra_04_agent24h_replacement/*.fig` | NO |
| `figures/infra_04_agent24h_replacement/*.png` | NO |
| `tables/infra_04_agent24h_replacement_correlations.csv` | NO |

Legacy PNGs at `figures/latent_vs_observable_proxy_comparison.png`, `figures/phi1_phi2_in_experimental_language.png`, and `figures/observable_replacement_summary.png` remain on disk unchanged by this task.

## 8. Visual and parity assessment against legacy PNGs

No replacement `.png` files were produced; side-by-side visual parity was **not** executed. Legacy baseline files remain available at the historical `figures/` paths for a future run once inputs exist.

## 9. Remaining blockers

1. Missing canonical switching run outputs (`switching_alignment_core_data.mat` and related run folders referenced by `switching_residual_decomposition_analysis` configuration in Agents 19F and phi2 test).
2. Missing PT pipeline artifact at default `results/switching/runs/run_2026_03_25_013849_pt_robust_minpts7/tables/PT_matrix.csv` (and dependent `kappa_vs_T.csv` path used by the PS1 script).
3. Until the above exist, the MATLAB replacement cannot complete and CV07 cannot be verified against INFRA policy.

## 10. Decision

**BLOCKED** — CV07 is **not** technically closed in this workspace. Formal retirement of the figure path is **not** recommended here; the failure is missing upstream data and paths, not intrinsic replacement inadequacy.

## 11. Recommended next step

Restore or regenerate the referenced `results/switching/runs/**` artifacts (alignment audit MAT, full scaling parameters, PT matrix run, residual decomposition kappa export) on a machine that holds the full switching results tree, then re-run the three generators and the MATLAB replacement through `tools/run_matlab_safe.bat`. Re-run visual parity between `figures/infra_04_agent24h_replacement/` and the legacy `figures/*.png` trio.

---

**Run metadata:** No git stage, commit, or push. No edits to policy documents, legacy PNGs, or `tools/agent24h_render_figures.ps1`. ASCII artifacts only.
