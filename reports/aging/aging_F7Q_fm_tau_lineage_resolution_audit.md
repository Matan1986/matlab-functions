# F7Q — Aging FM tau lineage-resolution audit (execution/audit, not physics)

Read-only audit artifact. **No** MATLAB, **no** output regeneration, **no** R_age / clock-ratio writer, **no** branch ranking, **no** canonical branch selection, **no** physics interpretation of tau numerics. Evidence: committed F7N/F7O/F7P artifacts, **text inspection** of `Aging/analysis/aging_fm_timescale_analysis.m` and `Aging/utils/appendF7GTauRMetadataColumns.m`, and **existing** F7O-A/F7O-B run directories (`tau_FM_vs_Tp.csv`, `log.txt`, `config_snapshot.m`). Policy reference: [`docs/repo_execution_rules.md`](../../docs/repo_execution_rules.md).

**Anchor:** `2d48de1` — *Plan Aging F7P FM tau lineage resolution* (F7P plan informs gates; F7Q does not upgrade flags by fiat).

---

## 1. Preflight summary

Executed per charter: `git log`, `git diff --cached` (empty), `git status --short` at task end.

---

## 2. Core answers (executive)

### 1) FM_abs lineage

| Question | Finding |
|----------|---------|
| Input table for `FM_abs` | **`cfg.datasetPath`** CSV read by `loadObservableDataset` — required columns include **`FM_abs`** (see `aging_fm_timescale_analysis.m`, `loadObservableDataset` / `normalizeDatasetTable`). |
| Path explicit? | **Yes** at execution time via **`cfg.datasetPath`** (defaults exist but F7O used explicit cfg). |
| Column name stable A vs B? | **Yes** — both branches use the same header token **`FM_abs`**; writer metadata JSON literal matches (`tau_input_observable_identities`). |
| Trace rows back to source? | **Per-Tp** via **`Tp`** join to dataset rows; **`source_run`** on `tau_FM_vs_Tp` carries first source_run from Tp-group (`analyzeFmTpGroup`). **Not** a row-for-row key for every `tw` sample in the emitted tau table (tau table is **one row per Tp**). |

### 2) FM convention

| Question | Finding |
|----------|---------|
| Meaning of `FM_abs` | **Column name + numeric values as read** — `buildFmTauTable` / `analyzeFmTpGroup` use **`y = sub.FM_abs(:)`** with **no** `abs()` call. Convention is **not** enforced as “absolute value” inside this writer. |
| Sign discarded before fitting? | **No explicit sign stripping** — fits use `y` as stored. |
| Signed vs absolute ambiguity | **Remains** if a dataset ever stored signed FM in `FM_abs`; **not disambiguated** by code. F7G **`semantic_status`** flags legacy alias semantics only. |
| Strong enough for model use? | **Not proven** by this audit — **PARTIAL / NEEDS_POLICY** (dataset contract + governance). |

### 3) Valid-row / has_fm policy

| Question | Finding |
|----------|---------|
| How valid FM curves decided | **`buildCollapseCurves`**: curve **`has_fm`** if finite `tw>0` and finite **`FM_abs`**. **`has_tau_fm`** only if tau row **`has_fm`**, finite **`tau_effective_seconds > 0`**, and curve **`has_fm`**. **`validCurves`** for collapse uses **`curves.has_tau_fm`**. **`assert(numel(validCurves) >= 3)`** gates full script completion after tau CSV write. |
| `has_fm = 0` at Tp=6 (30-row) | **No rows** in dataset sub after filter `isfinite(FM_abs)` / positive `tw` for that Tp — **`analyzeFmTpGroup`** returns empty **`sub`** → **`has_fm = false`**, metrics NaN; row **still emitted** in `tau_FM_vs_Tp` with F7G columns (verified on disk). |
| Rows to exclude from model use | **Rows with `has_fm = 0`** carry **no** finite tau extraction; **`model_use_allowed`** column still repeats global **`NO_UNLESS_LINEAGE_RESOLVED`** — **no row-specific inclusion flag** beyond **`has_fm`** / finite **`tau_effective_seconds`**. |
| Required inclusion flag for future use | **Recommend** consumers gate on **`has_fm`** and finite **`tau_effective_seconds`**; metadata does not add a dedicated **`row_eligible_for_model`** column. |

### 4) Branch provenance (lineage streams)

| Branch | datasetPath | dipTauPath | failedDipClockMetricsPath |
|--------|-------------|------------|-----------------------------|
| **22-row (F7O-A)** | `.../tables/aging/aging_observable_dataset.csv` | `run_2026_05_01_231047_.../tau_vs_Tp.csv` | `results_old/.../005134_.../fm_collapse_using_dip_tau_metrics.csv` |
| **30-row (F7O-B)** | `results_old/.../211204_.../aging_observable_dataset.csv` | `run_2026_05_01_231444_.../tau_vs_Tp.csv` | **same** archival `005134` path |

Recorded in **`log.txt`** under each run_dir; **`config_snapshot.m`** records dataset + dip (JSON snippet in file — verify full triple if extending automation). **`tau_FM_vs_Tp.csv`** rows include **`source_artifact_path`** (run-local) and JSON identity for **`FM_abs`** — **do not** embed `datasetPath`/dip/auxiliary paths **inside** the tau CSV columns.

### 5) dipTauPath compatibility

| Question | Finding |
|----------|---------|
| Role in FM tau numerics | **`dipTauPath` loaded after `tau_FM_vs_Tp` is saved** — **`buildFmTauTable`** uses **only** `dataTbl` from dataset. Dip used for **`compareTauStructures`**, **`makeTauComparisonFigure`**, report text — **not** for **`tau_effective_seconds`** computation. |
| Branch pairing | **F7O** paired correctly per F7N plan (evidence: F7O reports + `log.txt`). |
| Mis-pairing prevention | **Not** enforced in metadata columns — **operator discipline + harness**; code does not validate dataset/dip branch labels match. |

### 6) failedDipClockMetricsPath

| Question | Finding |
|----------|---------|
| Role | **`loadFailedDipClockMetrics`** reads **`baseline_all_fm`** row for **report comparison** text vs FM-collapse metrics — **not** used in **`buildFmTauTable`**. |
| Shared archival file | **Used for both F7O-A and F7O-B** — **cross-epoch** vs May 2026 dip tau per F7N/F7O notes. |
| Classification | **NEEDS_POLICY** for strict auxiliary lineage; **acceptable for smoke** per prior governance — **not** automatically **CLOSED** for model-use lineage without explicit policy sign-off. |
| Code note | **`loadFailedDipClockMetrics`** sets **`failed.run_id`** to a **hard-coded** legacy string — lineage coupling in code (**OPEN** hygiene concern). |

### 7) Model-use decision

**Do not upgrade** `model_use_allowed` from **`NO_UNLESS_LINEAGE_RESOLVED`** based on F7Q alone. Lineage **evidence improved** (source trace, dip independence, branch paths documented on disk); **governance closure** for model use requires **F7R-class** policy/metadata work or explicit scoped charter.

### 8) R_age / clock-ratio readiness

**Not** safe to treat as unconstrained **go** — **same blockers as F7P**: unresolved canonical lineage flags on tau rows, dual-branch streams, auxiliary policy. **Scoped per-branch** ratio work remains theoretically possible only with explicit manifests (**not executed here**).

---

## 3. Explicit constraints confirmed

| Constraint | Status |
|------------|--------|
| No MATLAB | **Yes** |
| No branch ranking / no canonical pick | **Yes** |
| No tau numeric physics interpretation | **Yes** |
| No Switching / Relaxation / MT | **Yes** |
| No stage / commit / push | **Yes** |

---

## Deliverables

| File |
|------|
| `reports/aging/aging_F7Q_fm_tau_lineage_resolution_audit.md` (this file) |
| `tables/aging/aging_F7Q_source_path_trace.csv` |
| `tables/aging/aging_F7Q_fm_abs_convention_audit.csv` |
| `tables/aging/aging_F7Q_branch_alignment_matrix.csv` |
| `tables/aging/aging_F7Q_valid_row_policy_audit.csv` |
| `tables/aging/aging_F7Q_dip_and_failed_clock_dependency_audit.csv` |
| `tables/aging/aging_F7Q_model_use_decision.csv` |
| `tables/aging/aging_F7Q_R_age_readiness_decision.csv` |
| `tables/aging/aging_F7Q_remaining_actions.csv` |
| `tables/aging/aging_F7Q_status.csv` |

Machine-readable verdicts: `tables/aging/aging_F7Q_status.csv`.
