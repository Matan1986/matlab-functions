# AGING-BASELINE-TAU-SIDECAR-EMISSION-VALIDATION-01

**Rules:** [`docs/repo_execution_rules.md`](../../docs/repo_execution_rules.md).  
**Scope:** One execution each of the baseline Dip and FM tau writers; verify main tau CSVs and **sidecar** CSVs on disk. No scientific interpretation of tau values; no `aging_clock_ratio_analysis.m`.

**Preflight:** `git diff --cached --name-only` was **empty** at task start.

---

## Execution summary

| Run | Script | How launched | Exit |
|-----|--------|--------------|------|
| Dip | `Aging/analysis/aging_timescale_extraction.m` | `tools/run_matlab_safe.bat` with `AGING_OBSERVABLE_DATASET_PATH` = `c:/Dev/matlab-functions/tables/aging/aging_observable_dataset.csv` | 0 |
| FM | `Aging/analysis/aging_fm_timescale_analysis.m` | `matlab -batch` with explicit `cfg` (dataset path, **fresh** `dipTauPath` from Dip run, existing `failedDipClockMetricsPath` under `results/aging/runs/run_2026_04_26_094446_aging_fm_using_dip_clock/...`) | 0 |

**Note:** The canonical wrapper only supports `run('script.m')` with **no** arguments. FM requires a `cfg` struct; **`run_matlab_safe.bat` alone cannot wire `dipTauPath` to the new Dip run**, so FM was run via **`matlab -batch`** with the same path setup as the script (`addpath` on `Aging`, `tools`, `tools/figures`). Dip used the approved wrapper.

---

## Run roots (this validation)

- **Dip:** `results/aging/runs/run_2026_05_04_134220_aging_timescale_extraction/`
- **FM:** `results/aging/runs/run_2026_05_04_135134_aging_fm_timescale_analysis/`

## Verified outputs

- **Dip:** `tables/tau_vs_Tp.csv` and **`tables/tau_vs_Tp_sidecar.csv`** present.
- **FM:** `tables/tau_FM_vs_Tp.csv` and **`tables/tau_FM_vs_Tp_sidecar.csv`** present.
- **Sidecars:** All **17** required `metadata_field` keys present in both files; `tau_domain` = **`DIP_DEPTH_CURVEFIT`** / **`FM_ABS_CURVEFIT`**; FM **`ABS_ONLY`** disclosure in `sign_or_magnitude_disclosure`.
- **`source_dataset_id`:** Explicit filesystem path to the consolidation CSV (not guessed). **`source_run`:** Pipe-joined unique values from data (not `UNRESOLVED`).
- **Main tau tables:** Legacy column set retained (`tau_effective_seconds`, etc.); **no column rename** performed by this validation task.
- **Ratio:** No `table_clock_ratio.csv` (or similar) in either run `tables/` folder; **`aging_clock_ratio_analysis.m` not run.**

---

## Machine-readable outputs

| File | Role |
|------|------|
| `tables/aging/aging_baseline_tau_sidecar_emission_validation_01_runs.csv` | Runs |
| `tables/aging/aging_baseline_tau_sidecar_emission_validation_01_outputs.csv` | Artifacts |
| `tables/aging/aging_baseline_tau_sidecar_emission_validation_01_sidecar_fields.csv` | Field-by-field checks |
| `tables/aging/aging_baseline_tau_sidecar_emission_validation_01_status.csv` | Status keys |

---

## Cross-module

No edits to Switching, Relaxation, Maintenance/INFRA, MT, or Aging source scripts.
