# F7H-resume (dip only) — real-output metadata verification

**Date:** 2026-05-01 (run timestamps on artifacts)  
**Scope:** Aging only. **Dip** tau writer **`aging_timescale_extraction.m`** only, via **`tools/run_matlab_safe.bat`**, with session **`AGING_OBSERVABLE_DATASET_PATH`**.  
**No** FM writer, **no** clock-ratio chain, **no** physics ranking, **no** code edits, **no** git stage/commit/push in this task.

Execution policy reference: [`docs/repo_execution_rules.md`](../docs/repo_execution_rules.md).

**Anchors:** `fd79727` (F7L resume readiness), `a3bdc10` (branch router), `29254e2` (F7J), `ddbe212` (F7I), `ced4798` (F7G metadata).

---

## 1. Preflight summary

| Check | Result |
|-------|--------|
| `git diff --cached --name-only` | **Empty** (before MATLAB) |
| `git status` | Unrelated local backlog only |
| `HEAD` | **`fd79727`** |

---

## 2. Exact dataset paths and existence (before runs)

| Run | Label | Path | Exists |
|-----|--------|------|--------|
| **A** | `current_tables_22row_consolidation` | `C:\Dev\matlab-functions\tables\aging\aging_observable_dataset.csv` | **Yes** |
| **B** | `archival_results_old_30row_snapshot` | `C:\Dev\matlab-functions\results_old\aging\runs\run_2026_03_12_211204_aging_dataset_build\tables\aging_observable_dataset.csv` | **Yes** |

---

## 3. Invocation method

Each run used **CMD** with **session-scoped** env var **only for that command**:

```bat
set AGING_OBSERVABLE_DATASET_PATH=<absolute_path>
cd /d C:\Dev\matlab-functions
tools\run_matlab_safe.bat C:\Dev\matlab-functions\Aging\analysis\aging_timescale_extraction.m
```

Runs were **separate** processes; outputs landed in **distinct** `run_*_aging_timescale_extraction` directories (no overwrite).

---

## 4. Run A — current 22-row branch

| Item | Value |
|------|--------|
| **MATLAB exit code** | **0** (terminal log `exit_code: 0` after `AFTER_MATLAB_CALL`) |
| **`tau_vs_Tp.csv` emitted** | **Yes** |
| **Run directory** | `C:\Dev\matlab-functions\results\aging\runs\run_2026_05_01_231047_aging_timescale_extraction` |
| **Input dataset rows** | **22** |
| **Emitted tau table rows** | **6** (one per \(T_p\) group with usable curve in this input) |
| **\(T_p\) coverage (unique)** | **14, 18, 22, 26, 30, 34** K |
| **Console** | “Dataset override via AGING_OBSERVABLE_DATASET_PATH is active.” |

---

## 5. Run B — archival 30-row branch

| Item | Value |
|------|--------|
| **MATLAB exit code** | **0** (`EXITCODE=0` echoed after batch) |
| **`tau_vs_Tp.csv` emitted** | **Yes** |
| **Run directory** | `C:\Dev\matlab-functions\results\aging\runs\run_2026_05_01_231444_aging_timescale_extraction` |
| **Input dataset rows** | **30** |
| **Emitted tau table rows** | **8** |
| **\(T_p\) coverage (unique)** | **6, 10, 14, 18, 22, 26, 30, 34** K |
| **Console** | Env override active |

---

## 6. Required metadata columns (row-level on `tau_vs_Tp.csv`)

All **twelve** columns were **present** in **both** outputs (verified via `Import-Csv` on first row and column names):

`writer_family_id`, `tau_or_R_flag`, `tau_domain`, `tau_input_observable_identities`, `tau_input_observable_family`, `source_writer_script`, `source_artifact_basename`, `source_artifact_path`, `canonical_status`, `model_use_allowed`, `semantic_status`, `lineage_status`.

### Metadata value checks (first row; both runs agree except `source_artifact_path` root run id)

| Field | Observed |
|-------|----------|
| `writer_family_id` | **`WF_TAU_DIP_CURVEFIT`** |
| `tau_or_R_flag` | **`TAU`** |
| `tau_domain` | **`DIP_MEMORY_CURVEFIT`** |
| `tau_input_observable_identities` | **`{"Dip_depth":"consolidated_aging_observable_dataset_column"}`** |
| `tau_input_observable_family` | **`Dip_depth_memory_curve`** |
| `source_writer_script` | **`Aging/analysis/aging_timescale_extraction.m`** |
| `source_artifact_basename` | **`tau_vs_Tp.csv`** |
| `canonical_status` | **`non_canonical_pending_lineage`** |
| `model_use_allowed` | **`NO_UNLESS_LINEAGE_RESOLVED`** |
| `semantic_status` | **`tau_effective_seconds_is_legacy_alias_DIP_CURVEFIT`** |
| `lineage_status` | **`REQUIRES_DATASET_PATH_AND_DIP_BRANCH_RESOLUTION`** |

**Assessment:** Values match the **F7G-patched dip writer** semantics (conservative `model_use_allowed`, pending lineage flags).

---

## 7. Branch comparison (**metadata / coverage only** — **no physics winner**)

| Aspect | Run A | Run B |
|--------|-------|-------|
| Input rows | 22 | 30 |
| Tau CSV rows | 6 | 8 |
| Extra \(T_p\) in B | — | **6 K, 10 K** present in input → appear in tau table coverage |
| Metadata bundle | Full F7G columns | Same semantic values |
| Output collision | **No** — different `run_*` timestamps | — |

Detail: `tables/aging/aging_F7H_resume_dip_branch_comparison.csv`.

---

## 8. Remaining blockers (downstream, not executed here)

1. **FM tau writer:** still needs **explicit `cfg`** (dataset path, dip tau path, auxiliary artifacts) — **env-only** pointer is **not** sufficient for the full chain.
2. **Clock-ratio / R_age:** requires **paired** prior **`tau_vs_Tp`** / **`tau_FM_vs_Tp`** runs with locked lineage — **not** attempted.

---

## 9. Next safe step (pick one)

| Option | When |
|--------|------|
| **Commit** these verification tables + this report (optional user commit) | Archive F7H-resume dip evidence |
| **Extend** to **FM tau** metadata verification | After preparing explicit **`cfg`** overrides and inputs |
| **Docs only** | If teams only need narrative updates |
| **Fix blocker** | Only if a future run **fails** — **no code patch** applied in this session |

Recommended default: **commit artifacts** (optional) **or** proceed to **FM tau** with **explicit cfg** in a **separate** gated task.

---

## 10. Deliverables

| File |
|------|
| `tables/aging/aging_F7H_resume_dip_real_output_verification.csv` |
| `tables/aging/aging_F7H_resume_dip_branch_comparison.csv` |
| `tables/aging/aging_F7H_resume_dip_metadata_columns.csv` |
| `tables/aging/aging_F7H_resume_dip_status.csv` |
| `reports/aging/aging_F7H_resume_dip_real_output_metadata_verification.md` |

Machine-readable verdicts: `tables/aging/aging_F7H_resume_dip_status.csv`.

---

## Confirmation

- **No** repository code edits.  
- **No** dataset rebuild / consolidation rerun beyond using existing CSVs as inputs.  
- **No** FM or clock-ratio writers.  
- **No** physics interpretation or model analysis.  
- **No** `git add` / commit / push for this task.  
- MATLAB ran **only** through **`tools/run_matlab_safe.bat`** as required.
