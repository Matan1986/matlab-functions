# AGING-BASELINE-TAU-OUTPUT-SANITY-01

**Rules:** [`docs/repo_execution_rules.md`](../../docs/repo_execution_rules.md).  
**Agent:** Narrow Aging QA (read-only inspection of validated baseline outputs).  
**Preflight:** `git diff --cached --name-only` was **empty** at task start.

**Scope:** Sanity-check the four artifacts referenced from **`aging_baseline_tau_sidecar_emission_validation_01`** (`runs.csv`). No MATLAB/Python execution in this task; no ratio computation; no scientific interpretation.

---

## Resolved paths (from validation runs table)

| Role | Path |
|------|------|
| Dip main | `c:/Dev/matlab-functions/results/aging/runs/run_2026_05_04_134220_aging_timescale_extraction/tables/tau_vs_Tp.csv` |
| Dip sidecar | `c:/Dev/matlab-functions/results/aging/runs/run_2026_05_04_134220_aging_timescale_extraction/tables/tau_vs_Tp_sidecar.csv` |
| FM main | `c:/Dev/matlab-functions/results/aging/runs/run_2026_05_04_135134_aging_fm_timescale_analysis/tables/tau_FM_vs_Tp.csv` |
| FM sidecar | `c:/Dev/matlab-functions/results/aging/runs/run_2026_05_04_135134_aging_fm_timescale_analysis/tables/tau_FM_vs_Tp_sidecar.csv` |

---

## Findings (summary)

1. **All four files exist** and were read.
2. **Dip and FM** tables both include **`Tp`** and **`tau_effective_seconds`** (the field `aging_clock_ratio_analysis` loads for pairing). No ambiguity: `tau_effective_seconds` is the only headline effective-tau column in these outputs.
3. **Finite / positive:** For all **6** Tp rows in each table, **`tau_effective_seconds`** is finite and **> 0** (suitable for log-based ratio lane math when that script is run later).
4. **Tp overlap:** **6** common Tp values **{14, 18, 22, 26, 30, 34}**; **pairable count = 6** (see `aging_baseline_tau_output_sanity_01_pairing.csv`).
5. **Missing tw=3:** Both sidecars’ **`grid_disclosure`** reference **Tp 30/34** short-ladder **PARTIAL_GRID** (aligned with `aging_dip_fm_tw_inventory_01`).
6. **Sidecar domains:** **Dip** `tau_domain` = **`DIP_DEPTH_CURVEFIT`**; **FM** = **`FM_ABS_CURVEFIT`**. **FM** `sign_or_magnitude_disclosure` includes **`ABS_ONLY`**.
7. **source_dataset_id** is an explicit path to `tables/aging/aging_observable_dataset.csv`. **source_run** is a joined string of dataset lineages, not `UNRESOLVED`.
8. **No ratio products** in either run’s `tables/` directory (only the two tau files + two sidecars per run root).
9. **FM run wiring (emission validation):** Dip = `tools/run_matlab_safe.bat` + `AGING_OBSERVABLE_DATASET_PATH`. FM = **`matlab -batch`** with explicit **`cfg`** (wrapper cannot pass `dipTauPath` to match this Dip run). See `aging_baseline_tau_sidecar_emission_validation_01.md`.
10. **Not old Track A / not multipath:** Input consolidation is **Track B** `aging_observable_dataset.csv`; **dipTauPath** on the FM table points to this **same validation** Dip run’s `tau_vs_Tp.csv` (not a legacy Track A export).

---

## Machine-readable tables

| File | Role |
|------|------|
| `tables/aging/aging_baseline_tau_output_sanity_01_artifacts.csv` | Four artifacts |
| `tables/aging/aging_baseline_tau_output_sanity_01_tau_summary.csv` | Row/tau counts |
| `tables/aging/aging_baseline_tau_output_sanity_01_pairing.csv` | Per-Tp pairing |
| `tables/aging/aging_baseline_tau_output_sanity_01_status.csv` | Status keys |

---

## Cross-module

No Switching, Relaxation, Maintenance/INFRA, MT, or code edits.
