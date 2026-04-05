# Canonical Switching analysis survey (clean layer)

Read-only inventory from a **single** canonical run directory. No repo-root tables, no prior survey CSVs, and no MATLAB re-execution were used. Paths are relative to the repository root.

## Canonical source

| Item | Value |
|------|--------|
| `run_id` | `run_2026_04_03_000147_switching_canonical` |
| Root | `results/switching/runs/run_2026_04_03_000147_switching_canonical/` |

## Stage 1 — Artifacts extracted

### `execution_status.csv` (run root)

Present: `results/switching/runs/run_2026_04_03_000147_switching_canonical/execution_status.csv`.

### `tables/` (5 files)

| File |
|------|
| `switching_canonical_S_long.csv` |
| `switching_canonical_observables.csv` |
| `switching_canonical_phi1.csv` |
| `switching_canonical_validation.csv` |
| `run_switching_canonical_implementation_status.csv` |

### `reports/` (2 files)

| File |
|------|
| `run_switching_canonical_report.md` |
| `run_switching_canonical_implementation.md` |

### Not clustered into analyses (outside `tables/` / `reports/`)

The run directory also contains `execution_probe.csv`, `execution_probe_status.csv`, `log.txt`, `config_snapshot.m`, `run_manifest.json`, and `run_status.csv`. These were **not** listed under `tables/` or `reports/` and are excluded from the analysis groupings below (isolation from ad-hoc clustering of non-table/non-report artifacts).

## Stage 2 — Grouping logic

An **analysis** (working definition for this survey) is a cluster that includes **at least one** file under `tables/` and **at least one** file under `reports/`, with **`execution_status.csv`** at run root shared by the run (one status file for the whole run).

Clusters:

1. **`switching_canonical_*` science tables** share the prefix `switching_canonical_`. They pair with the primary narrative report **`run_switching_canonical_report.md`** (shared `run_switching_canonical` stem with the script-oriented naming of the run outputs).

2. **`run_switching_canonical_implementation_*`** shares a prefix between **`run_switching_canonical_implementation_status.csv`** and **`run_switching_canonical_implementation.md`**, forming a distinct implementation companion bundle.

No other `tables/` × `reports/` pairings exist without splitting a report across two analyses, so **two** analyses are the minimal partition that respects prefix alignment and one-report-per-bundle readability.

## Stage 3 — Ambiguity

- **Single script vs multiple analyses:** The run almost certainly corresponds to one driver script, but the **output** layout naturally splits into **main science tables + main report** vs **implementation status + implementation report**. The survey records **two** `analysis_id` rows to mirror that structure; it does not assert two separate MATLAB entrypoints.
- **Type labels:** `analysis_type` is inferred **only** from filenames (see CSV). The core bundle mixes name tokens (`phi1`, `validation`, etc.); it is labeled **`other`** to avoid picking one filename over others without external rules.

## Stage 4 — Isolation from legacy

- **YES:** Only paths under `results/switching/runs/run_2026_04_03_000147_switching_canonical/` appear in `artifact_paths`. No `tables/` at repo root and no other runs are inputs to this survey.

## Machine-readable outputs

- `tables/switching_canonical_analysis_clean.csv`
- `tables/switching_canonical_analysis_clean_status.csv`

---

## Analyses (summary)

| `analysis_id` | `analysis_type` | Tables | Reports |
|---------------|-----------------|--------|---------|
| `switching_canonical_core_outputs` | other (name tokens mixed) | 4 × `switching_canonical_*.csv` | `run_switching_canonical_report.md` |
| `switching_canonical_implementation` | validation (from `*_implementation_status*`) | `run_switching_canonical_implementation_status.csv` | `run_switching_canonical_implementation.md` |

Both rows: `has_execution_status` = YES (run root file present).

## Full-artifact rule used for counts

For each analysis row: at least one table path, at least one report path, and the run has `execution_status.csv`. **HAS_FULL_ARTIFACTS_COUNT** = 2; **MISSING_ARTIFACTS_COUNT** = 0.
