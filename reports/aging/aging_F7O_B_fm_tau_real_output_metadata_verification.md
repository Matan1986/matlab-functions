# F7O-B — Aging FM tau real-output metadata verification (30-row archival branch)

One MATLAB execution via **`tools/run_matlab_safe.bat`** plus verification artifacts only. Policy: [`docs/repo_execution_rules.md`](../../docs/repo_execution_rules.md).

**HEAD at authoring:** `935e45f` — *Verify Aging F7O-A FM tau metadata output* (preflight `git diff --cached` empty).

**Anchors:** `935e45f`, `d8916b9`, `eff35e1`, `1eb47ff`.

---

## 1. Preflight summary

| Check | Result |
|-------|--------|
| `git diff --cached --name-only` | **Empty** |
| Run A rerun | **No** |
| Cross-branch mixing | **No** — dataset + dip tau both **30-row / Run B** aligned |

---

## 2. Explicit `cfg` (semantic match to charter)

Harness (**untracked**, **not staged**): `tmp_f7o_b_UNTRACKED/run_F7O_B_fm_harness.m`

Forward slashes in strings to avoid MATLAB escape issues.

| Field | Value |
|-------|--------|
| `runLabel` | **`F7O_FM_METADATA_VERIFY_30ROW`** |
| `datasetPath` | `C:/Dev/matlab-functions/results_old/aging/runs/run_2026_03_12_211204_aging_dataset_build/tables/aging_observable_dataset.csv` |
| `dipTauPath` | `C:/Dev/matlab-functions/results/aging/runs/run_2026_05_01_231444_aging_timescale_extraction/tables/tau_vs_Tp.csv` |
| `failedDipClockMetricsPath` | `C:/Dev/matlab-functions/results_old/aging/runs/run_2026_03_13_005134_aging_fm_using_dip_clock/tables/fm_collapse_using_dip_tau_metrics.csv` |

---

## 3. MATLAB execution outcome

| Item | Value |
|------|--------|
| **Exit code** | **0** |
| **Wrapper** | `tools\run_matlab_safe.bat` with harness path |

---

## 4. Run directory

`C:\Dev\matlab-functions\results\aging\runs\run_2026_05_02_230740_F7O_FM_METADATA_VERIFY_30ROW`

---

## 5. `tau_FM_vs_Tp.csv` emitted

**Yes.**  
Path: `...\tables\tau_FM_vs_Tp.csv`

| Metric | Value |
|--------|--------|
| **Rows** | **8** (one per \(T_p\) in FM tau table, including rows with `has_fm = 0` carrying metadata) |
| **\(T_p\) coverage (unique)** | **6, 10, 14, 18, 22, 26, 30, 34** K |

---

## 6. Metadata verification

All **twelve** required columns **present** on emitted CSV (verified via `Import-Csv`; semantics match **F7O-A** and FM writer contract):

- **`writer_family_id`** = **`WF_TAU_FM_CURVEFIT`**
- **`tau_or_R_flag`** = **`TAU`**
- **`tau_domain`** = **`FM_ABS_CURVEFIT`**
- **`tau_input_observable_identities`** / **`tau_input_observable_family`** = FM_abs consolidation JSON / **`FM_abs_memory_curve`**
- **`source_writer_script`** = **`Aging/analysis/aging_fm_timescale_analysis.m`**
- **`source_artifact_basename`** = **`tau_FM_vs_Tp.csv`**
- **`canonical_status`** = **`non_canonical_pending_lineage`**
- **`model_use_allowed`** = **`NO_UNLESS_LINEAGE_RESOLVED`**
- **`semantic_status`** = **`tau_effective_seconds_is_legacy_alias_FM_ABS_CURVEFIT`**
- **`lineage_status`** = **`REQUIRES_DATASET_PATH_AND_FM_CONVENTION_RESOLUTION`**

Detail: `tables/aging/aging_F7O_B_fm_metadata_columns.csv`.

---

## 7. Failure / partial-output classification

**Not applicable** — exit **0**, **no** `validCurves` assert failure observed.

---

## 8. Metadata-only comparison to **F7O-A** (no physics, no ranking)

| Aspect | F7O-A (22-row) | F7O-B (30-row archival) |
|--------|----------------|---------------------------|
| **`tau_FM` row count** | 6 | 8 |
| **\(T_p\) coverage** | 14–34 (six stops) | 6–34 (eight stops) |
| **12 metadata columns** | Present | Present |
| **Semantic flags** | FM curve-fit contract | **Same** |
| **Run success** | Full | Full |

**Interpretation allowed:** coverage and row-count differences reflect **branch-aligned inputs** and temperature grid — **not** a statement that either branch is physically superior.

Machine-readable: `tables/aging/aging_F7O_B_vs_A_metadata_comparison.csv`.

---

## 9. Physics and branch ranking

**No physics claims.** **No branch ranking.** This task verifies **metadata posture** on real **`tau_FM_vs_Tp.csv`** outputs only.

---

## 10. F7O closure gate

Both **F7O-A** and **F7O-B** succeeded with **full** runs and **valid** FM metadata columns — **safe** to proceed with an **F7O-series closure** memo (**documentation only**, metadata/coverage comparison, no winner).

---

## 11. Constraints confirmation

| Constraint | Status |
|------------|--------|
| No edits to **`aging_fm_timescale_analysis.m`** / Aging utils | **Yes** |
| No dataset rebuild; no dip tau rerun; no Run A rerun | **Yes** |
| No staging / commit / push | **Yes** |

---

## Deliverables

| File |
|------|
| `reports/aging/aging_F7O_B_fm_tau_real_output_metadata_verification.md` (this file) |
| `tables/aging/aging_F7O_B_fm_real_output_verification.csv` |
| `tables/aging/aging_F7O_B_fm_metadata_columns.csv` |
| `tables/aging/aging_F7O_B_execution_outcome.csv` |
| `tables/aging/aging_F7O_B_vs_A_metadata_comparison.csv` |
| `tables/aging/aging_F7O_B_status.csv` |

Verdict table: `tables/aging/aging_F7O_B_status.csv`.
