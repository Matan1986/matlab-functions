# F7N — Aging FM tau metadata verification readiness audit

Read-only governance artifact. **No** MATLAB execution, **no** code edits, **no** dataset rebuild, **no** writer runs, **no** staging / commit / push. Execution hygiene remains [`docs/repo_execution_rules.md`](../../docs/repo_execution_rules.md).

**HEAD at authoring:** `eff35e1` — *Close Aging dip tau metadata state* (preflight `git diff --cached` empty).

**Anchors:** `eff35e1`, `1eb47ff`, `fd79727`, `a3bdc10`, `29254e2`, `ddbe212`, `ced4798`.

---

## 1. Preflight summary

| Check | Result |
|-------|--------|
| `git diff --cached --name-only` | **Empty** |
| Scope | Static inspection + `Test-Path` on candidate files only |

---

## 2. What F7M closed

**F7M** closes the **dip-only** tau metadata story: real **`tau_vs_Tp.csv`** from **`aging_timescale_extraction.m`** was verified under explicit dataset pointers for **22-row** and **30-row** branches — **metadata verification only**; **not** physics, **not** `model_use_allowed` escalation, **no** canonical truth between branches.

---

## 3. Why FM tau differs from dip (cannot rely on env-only pointer)

| Dip (`aging_timescale_extraction`) | FM (`aging_fm_timescale_analysis`) |
|-----------------------------------|--------------------------------------|
| **`AGING_OBSERVABLE_DATASET_PATH`** can override the default dataset path when implemented in that script | **`AGING_OBSERVABLE_DATASET_PATH` is not referenced** — inputs are **`cfg.datasetPath`** etc. only |
| Single primary CSV input for extraction | **Three** asserted paths: **`datasetPath`**, **`dipTauPath`**, **`failedDipClockMetricsPath`** |
| No auxiliary legacy metric table | Requires **`fm_collapse_using_dip_tau_metrics.csv`** with **`baseline_all_fm`** row |

Therefore **explicit `cfg`** (or an outer harness that builds `cfg`) is mandatory for controlled FM runs.

---

## 4. Static code findings — `aging_fm_timescale_analysis.m`

| Topic | Finding |
|-------|---------|
| **Entry style** | **`function out = aging_fm_timescale_analysis(cfg)`** — function; optional `cfg` struct; empty calls **`cfg = struct()`**. |
| **`applyDefaults`** | Local nested function fills **`runLabel`**, **`datasetPath`**, **`dipTauPath`**, **`failedDipClockMetricsPath`**, figure positions, grid/count thresholds (`pairGridCount` … `minCurvesForStats`). |
| **Hard asserts** | **`exist(...,'file')==2`** for all three paths before any computation (lines 20–22). |
| **FM tau table source** | **`buildFmTauTable(loadObservableDataset(cfg.datasetPath))`** — **`FM_abs`** vs **`tw`** per **`Tp`**; dip tau **does not** enter the regression formulas. |
| **Dip tau role** | **`loadDipTauTable(cfg.dipTauPath)`** — used for **`compareTauStructures`**, **`makeTauComparisonFigure`**, and narrative/report text; **not** for computing **`tau_FM`** columns. |
| **Failed dip-clock role** | **`loadFailedDipClockMetrics`** — pulls **`baseline_all_fm`** row for report comparison vs FM-collapse metrics; **hard-coded** `failed.run_id` string in helper matches legacy run id. |
| **Output artifact** | **`save_run_table(..., 'tau_FM_vs_Tp.csv', runDir)`** after **`appendF7GTauRMetadataColumns`** with **`writer_family_id = 'WF_TAU_FM_CURVEFIT'`** (lines 45–58). |
| **F7G append** | **Yes** — **`appendF7GTauRMetadataColumns(fmTauTbl, f7gMeta)`** with FM-specific **`tau_domain`** / **`lineage_status`** (`REQUIRES_DATASET_PATH_AND_FM_CONVENTION_RESOLUTION`). |
| **Completion gate** | **`assert(numel(validCurves) >= 3, ...)`** — full script expects sufficient FM curves with finite **`tau_FM`**; metadata-only partial-save behavior is **not** a supported mode (failure may occur after table write — see F7O hygiene). |
| **Defaults (repoRoot-relative)** | **`datasetPath`** → `results/aging/runs/run_2026_03_12_211204_aging_dataset_build/tables/aging_observable_dataset.csv`; **`dipTauPath`** → `run_2026_03_12_223709_aging_timescale_extraction/.../tau_vs_Tp.csv`; **`failedDipClockMetricsPath`** → `run_2026_03_13_005134_aging_fm_using_dip_clock/.../fm_collapse_using_dip_tau_metrics.csv`. |

---

## 5. Candidate inputs — existence (this workspace)

| Path role | Exists |
|-----------|--------|
| **22-row dataset** `tables\aging\aging_observable_dataset.csv` | **YES** |
| **30-row archival dataset** `results_old\...\211204\...\aging_observable_dataset.csv` | **YES** |
| **F7H-resume dip tau Run A** `run_2026_05_01_231047_...\tau_vs_Tp.csv` | **YES** |
| **F7H-resume dip tau Run B** `run_2026_05_01_231444_...\tau_vs_Tp.csv` | **YES** |
| **Default `datasetPath` under `results\aging\runs\211204\...`** | **NO** |
| **Default `dipTauPath` under `223709\...`** | **NO** |
| **Default `failedDipClockMetricsPath` under `results\...\005134\...`** | **NO** |
| **Archival `failedDipClockMetricsPath`** `results_old\...\005134\...\fm_collapse_using_dip_tau_metrics.csv` | **YES** (contains **`baseline_all_fm`** row) |

Detail: `tables/aging/aging_F7N_candidate_input_paths.csv`.

---

## 6. Recommended FM metadata verification plan (F7O)

**No physics winner** — two optional **branch-aligned** passes (same labels as F7H-resume):

| Order | Dataset branch | `datasetPath` | Branch-aligned dip tau |
|-------|------------------|----------------|-------------------------|
| **1** | `current_tables_22row_consolidation` | `...\tables\aging\aging_observable_dataset.csv` | F7H-resume **Run A** `tau_vs_Tp.csv` |
| **2** | `archival_results_old_30row_snapshot` | `...\results_old\...\211204\...\aging_observable_dataset.csv` | F7H-resume **Run B** `tau_vs_Tp.csv` |

**Do not** pair a 22-row dataset with a 30-row dip tau (or reverse) without explicit science justification — **not** recommended for metadata hygiene.

**Third path (same for both runs unless regenerated):**  
`failedDipClockMetricsPath` = **`results_old\...\run_2026_03_13_005134_aging_fm_using_dip_clock\tables\fm_collapse_using_dip_tau_metrics.csv`**  
This satisfies the assert and **`baseline_all_fm`** lookup. **Lineage caveat:** file is from the **historical dip-clock run**, not from F7H-resume May 2026 dip tau — acceptable for **metadata smoke** if **`run_notes`** documents **cross-epoch auxiliary** use; stricter lineage would require rerunning **`aging_fm_using_dip_clock`** per branch (outside F7N scope).

Machine-readable plan: `tables/aging/aging_F7N_fm_run_plan.csv`.

---

## 7. MATLAB `cfg` shape — pseudocode only (do not execute here)

```matlab
% F7O placeholder — run only via approved repo MATLAB wrapper after F7O charter.
cfg = struct();
cfg.runLabel = 'aging_fm_metadata_verify_22row';  % or _30row for Run B

cfg.datasetPath = 'C:\Dev\matlab-functions\tables\aging\aging_observable_dataset.csv';
cfg.dipTauPath  = 'C:\Dev\matlab-functions\results\aging\runs\run_2026_05_01_231047_aging_timescale_extraction\tables\tau_vs_Tp.csv';
cfg.failedDipClockMetricsPath = 'C:\Dev\matlab-functions\results_old\aging\runs\run_2026_03_13_005134_aging_fm_using_dip_clock\tables\fm_collapse_using_dip_tau_metrics.csv';

% Run B substitution example:
% cfg.datasetPath = 'C:\Dev\matlab-functions\results_old\aging\runs\run_2026_03_12_211204_aging_dataset_build\tables\aging_observable_dataset.csv';
% cfg.dipTauPath  = 'C:\Dev\matlab-functions\results\aging\runs\run_2026_05_01_231444_aging_timescale_extraction\tables\tau_vs_Tp.csv';
% cfg.runLabel    = 'aging_fm_metadata_verify_30row';

% out = aging_fm_timescale_analysis(cfg);
```

**Harness note:** Callers typically need a one-line driver script or `-batch` entry that assigns **`cfg`** then invokes the function — **`AGING_OBSERVABLE_DATASET_PATH` alone is insufficient**.

---

## 8. Gate decision

| Gate | Value |
|------|--------|
| **`F7N_READY_TO_RUN_FM_METADATA`** | **YES_WITH_EXPLICIT_CFG_AND_ARCHIVAL_DIP_CLOCK_FILE** |
| **Blockers removed for planning** | Branch-aligned **dataset** + **dip tau** paths exist; **archival** dip-clock metrics exist. |
| **Residual risks (execution-time)** | (1) **`assert(numel(validCurves) >= 3)`** may fail if FM curves insufficient — separate from metadata columns. (2) **Cross-epoch** **`failedDipClockMetricsPath`** vs fresh dip tau — document in **`run_notes`**. |

**Next task label:** **F7O** — FM tau **real-output** metadata verification (explicit **`cfg`**, metadata-only claims, wrapper-only execution).

---

## 9. Allowed claims after F7N

- **Readiness** and **explicit cfg plan** exist.
- **Candidate inputs** identified with **existence** probes.
- **FM writer** statically mapped to **`WF_TAU_FM_CURVEFIT`** + **`appendF7GTauRMetadataColumns`**.
- **No FM output** has been **verified** on disk in this audit.

---

## 10. Forbidden claims

- Do **not** claim **`tau_FM_vs_Tp.csv`** metadata was **verified** in this audit.
- Do **not** claim **R_age** or **clock-ratio** verification.
- Do **not** claim **physics** or **model use**.
- Do **not** rank **dataset branches**.

---

## Deliverables

| File |
|------|
| `reports/aging/aging_F7N_fm_tau_metadata_readiness.md` (this file) |
| `tables/aging/aging_F7N_fm_cfg_field_inventory.csv` |
| `tables/aging/aging_F7N_candidate_input_paths.csv` |
| `tables/aging/aging_F7N_fm_run_plan.csv` |
| `tables/aging/aging_F7N_status.csv` |

---

## Confirmation

**No** code edits, **no** MATLAB, **no** dataset rebuild, **no** writer execution, **no** staging, **no** commit, **no** push. **No** Switching / Relaxation / MT changes.
