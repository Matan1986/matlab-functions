# Switching leakage cleanup (surgical)

## Summary

Infrastructure helpers **`tools/load_run.m`** and **`tools/run_artifact_path.m`** were added so scripts can load CSVs strictly from **`results/switching/runs/<RUN_ID>/...`** without referencing repository-root **`tables/`** or **`reports/`**.

**Fixed (representative):** parameter robustness (trust table + removed duplicate writes to repo `tables/`), phi/kappa canonical-space analysis, phi1/phi2 driver and closure scripts, O2 debug pipeline, phi2 deformation/extended/shape/kappa2 residual scripts, kappa2 operational signature defaults, width interaction closure v2 (CSV scan + outputs), kappa2 opening test, experimental baseline scripts (outputs only under `run_dir`).

**Environment overrides (optional):** `SWITCHING_TRUST_TABLE_RUN_ID`, `SWITCHING_PHI_KAPPA_INPUT_RUN_ID`, `SWITCHING_PHI1_PHI2_DRIVER_INPUT_RUN_ID`, `SWITCHING_CLOSURE_FIXED_INPUT_RUN_ID`, `SWITCHING_CLOSURE_TEST_INPUT_RUN_ID`, `SWITCHING_KAPPA_TABLE_RUN_ID`, `SWITCHING_PHI2_BASELINE_FIT_RUN_ID`, `SWITCHING_WIDTH_CLOSURE_INPUT_RUN_ID`, `SWITCHING_KAPPA2_TABLE_RUN_ID`. Defaults point at historical run ids used previously in-repo; **artifacts must exist under those run directories** (copy from legacy `tables/` where needed).

## Ignored (why)

- **Relaxation / Alpha / Aging named scripts** under `Switching/analysis/` (e.g. `run_relaxation_*`, `run_alpha_*`, `run_aging_*`, `run_PT_*`, `locate_relaxation_*`, …): task excluded cross-pipeline work; they still use repo-root `tables/` or hardcoded paths.
- **Dead / unused:** not systematically classified; no deletes performed.

## Remaining risks

- **`LEAKAGE_PRESENT=YES`** in `tables/leakage_cleanup_status.csv`: many Switching files still reference **`fullfile(repoRoot,'tables',...)`** or hardcoded `C:/Dev/...` (see `tables/preflight_leakage_report_after.csv`).
- **Cross-run dependencies** remain by design wherever analyses compare to a **selected canonical run** (e.g. robustness, decomposition configs); only repo-aggregate **reads** were targeted.
- **`run_parameter_robustness_switching_canonical.m`** still writes **`execution_status.csv`** at **repository root** (`baseFolder/execution_status.csv`) as before; not migrated in this pass.
- Operators must place required CSVs (trust classification, closure metrics, etc.) under the referenced **`results/switching/runs/<RUN_ID>/tables/`** paths or set env vars accordingly.

## Artifacts

| File | Purpose |
| --- | --- |
| `tables/preflight_leakage_report_after.csv` | Post-change leakage notes |
| `tables/leakage_cleanup_status.csv` | Aggregate status row |
