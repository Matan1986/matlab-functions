# F7O-A — Aging FM tau real-output metadata verification (22-row branch)

Read-only verification memo plus **one** executed MATLAB run via **`tools/run_matlab_safe.bat`**. Execution policy: [`docs/repo_execution_rules.md`](../../docs/repo_execution_rules.md).

**HEAD at report authoring:** `d8916b9` — *Add Aging F7N FM tau metadata readiness audit* (preflight `git diff --cached` empty).

**Anchors:** `d8916b9`, `eff35e1`, `1eb47ff`.

---

## 1. Preflight summary

| Check | Result |
|-------|--------|
| `git diff --cached --name-only` | **Empty** |
| Scope | **Run A / 22-row only** — **no Run B** |

---

## 2. Explicit `cfg` used (semantic match to F7N charter)

Harness script (**untracked**, **not staged**): `tmp_f7o_a_UNTRACKED/run_F7O_A_fm_harness.m`

Forward slashes used in path strings to avoid MATLAB `\t` escape hazards; paths resolve to the same locations as:

| Field | Value |
|-------|--------|
| `runLabel` | **`F7O_FM_METADATA_VERIFY_22ROW`** |
| `datasetPath` | `C:/Dev/matlab-functions/tables/aging/aging_observable_dataset.csv` |
| `dipTauPath` | `C:/Dev/matlab-functions/results/aging/runs/run_2026_05_01_231047_aging_timescale_extraction/tables/tau_vs_Tp.csv` |
| `failedDipClockMetricsPath` | `C:/Dev/matlab-functions/results_old/aging/runs/run_2026_03_13_005134_aging_fm_using_dip_clock/tables/fm_collapse_using_dip_tau_metrics.csv` |

Invocation:

```bat
tools\run_matlab_safe.bat C:\Dev\matlab-functions\tmp_f7o_a_UNTRACKED\run_F7O_A_fm_harness.m
```

---

## 3. MATLAB execution outcome

| Item | Value |
|------|--------|
| **Exit code** | **0** (wrapper completed after `AFTER_MATLAB_CALL`) |
| **Harness entry** | Pure script; calls **`aging_fm_timescale_analysis(cfg)`** — **no** edits to **`Aging/analysis/aging_fm_timescale_analysis.m`** |

---

## 4. Run directory

`C:\Dev\matlab-functions\results\aging\runs\run_2026_05_02_225424_F7O_FM_METADATA_VERIFY_22ROW`

---

## 5. `tau_FM_vs_Tp.csv` emitted

**Yes.**  
Full path:  
`...\run_2026_05_02_225424_F7O_FM_METADATA_VERIFY_22ROW\tables\tau_FM_vs_Tp.csv`

| Metric | Value |
|--------|--------|
| **Rows** | **6** (one per \(T_p\) group with FM extraction in this run) |
| **\(T_p\) coverage (unique)** | **14, 18, 22, 26, 30, 34** K |

---

## 6. Metadata column / value verification

All **twelve** required columns **present** on row-level CSV output (verified via PowerShell `Import-Csv`, first data row):

| Column | Row-0 observation |
|--------|-------------------|
| `writer_family_id` | **`WF_TAU_FM_CURVEFIT`** |
| `tau_or_R_flag` | **`TAU`** |
| `tau_domain` | **`FM_ABS_CURVEFIT`** |
| `tau_input_observable_identities` | **`{"FM_abs":"consolidated_aging_observable_dataset_column"}`** |
| `tau_input_observable_family` | **`FM_abs_memory_curve`** |
| `source_writer_script` | **`Aging/analysis/aging_fm_timescale_analysis.m`** |
| `source_artifact_basename` | **`tau_FM_vs_Tp.csv`** |
| `source_artifact_path` | Absolute path under this run **`...\tables\tau_FM_vs_Tp.csv`** |
| `canonical_status` | **`non_canonical_pending_lineage`** |
| `model_use_allowed` | **`NO_UNLESS_LINEAGE_RESOLVED`** (conservative) |
| `semantic_status` | **`tau_effective_seconds_is_legacy_alias_FM_ABS_CURVEFIT`** |
| `lineage_status` | **`REQUIRES_DATASET_PATH_AND_FM_CONVENTION_RESOLUTION`** |

Detail: `tables/aging/aging_F7O_A_fm_metadata_columns.csv`.

---

## 7. Failure / partial-output classification

**Not applicable** — run **completed successfully** (`exit code 0`).  
**No** `assert(numel(validCurves) >= 3)` failure observed.

---

## 8. Physics / model claims

**None.** This verification attests **metadata columns and conservative lineage flags** on a real **`tau_FM_vs_Tp.csv`** only — **not** physical FM tau truth, **not** collapse quality ranking, **not** superiority vs dip tau.

---

## 9. Run B gate (30-row branch)

**F7O-A supports proceeding to Run B** when chartered: F7N branch-aligned **30-row** **`datasetPath`**, **F7H-resume Run B** **`dipTauPath`**, same **explicit** **`failedDipClockMetricsPath`** policy (document auxiliary lineage in **`run_notes`**). **No** branch physics ranking implied.

---

## 10. Constraints confirmation

| Constraint | Status |
|------------|--------|
| No edits to **`aging_fm_timescale_analysis.m`** or Aging utils | **Yes** |
| No dataset rebuild; no dip tau rerun | **Yes** |
| No Run B executed | **Yes** |
| No clock-ratio writer | **Yes** |
| No staging / commit / push | **Yes** |
| Verification artifacts only added under `reports/aging/`, `tables/aging/` | **Yes** |

---

## Deliverables

| File |
|------|
| `reports/aging/aging_F7O_A_fm_tau_real_output_metadata_verification.md` (this file) |
| `tables/aging/aging_F7O_A_fm_real_output_verification.csv` |
| `tables/aging/aging_F7O_A_fm_metadata_columns.csv` |
| `tables/aging/aging_F7O_A_execution_outcome.csv` |
| `tables/aging/aging_F7O_A_status.csv` |

Machine-readable verdicts: `tables/aging/aging_F7O_A_status.csv`.
