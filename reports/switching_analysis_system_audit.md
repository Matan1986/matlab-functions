# Switching analysis system consolidation audit

Read-only consolidation pass (2026-04-04). Scope: `tables/` (files matching `*switch*`), `reports/` (`*switch*`), `Switching/analysis/` (all `.m` files), `results/switching/runs/` (all files). No analysis reruns; no edits to pre-existing repository files; classifications below are filesystem and registry checks only, not a reinterpretation of science.

## What was found

| Category | Count | Description |
|----------|------:|-------------|
| MATLAB under `Switching/analysis/` | 103 | Includes runners (`run_*.m`, `analyze_*.m`), `switching_*.m` studies, and shared helpers (correlation, `ensureDir`, `phi*_helpers`, etc.). |
| Tables under `tables/` (`*switch*`) | 61 | Registry, canonicalization, inventory, robustness, collapse, and related CSV artifacts. |
| Reports under `reports/` (`*switch*`) | 47 | Paired markdown with many of the above tables; migration pilots; audits. |
| All files under `results/switching/runs/` | 185 | Per-run `execution_status.csv`, manifests, logs, `tables/`, `reports/`, bundled canonical science copies inside L3 canonicalization runs. |
| **Total entities in unified map** | **396** | One row per file; see `tables/switching_analysis_system_map.csv`. |

### Canonical connectivity (no survey reliance)

`tables/switching_canonical_analysis_map.csv` lists `connectivity_status=TRUE_CANONICAL` for ten logical analyses and explicit `artifact_paths`. Any file path appearing in that column is assigned **CANONICAL_CONFIRMED** in the system map (37 file rows). This is the only automatic **CANONICAL_CONFIRMED** rule used; it does not depend on `tables/switching_analysis_full_classification.csv` (which can disagree with that map for the same logical ids).

### Registry and noncanonical scripts

- **CANONICAL_CANDIDATE (4 rows):** `Switching/analysis/run_switching_canonical.m` (listed as canonical entry in `tables/switching_canonical_entrypoint.csv`) and the three entrypoint companion tables `switching_canonical_entrypoint.csv`, `switching_canonical_entrypoint_status.csv`, `switching_canonical_entrypoint_candidates.csv`.
- **NONCANONICAL_LEGACY (3 rows):** `Switching/analysis/experimental/run_switching_physical_baseline_model.m`, `Switching/analysis/experimental/run_switching_raw_baseline_correction_and_comparison.m`, and `Switching/analysis/run_minimal_canonical.m` (also named as noncanonical / misleading in `tables/switching_noncanonical_scripts.csv`).

### Execution signaling vs runs

- Nineteen run directories exist under `results/switching/runs/`. All but one have `execution_status.csv` at run root: `run_2026_04_02_213408_phi_kappa_canonical_space_analysis` does not (consistent with `tables/switching_run_trust_classification.csv` for that run id).
- The `has_artifacts` column in the system map uses **YES** only for helper-exempt scripts when at least one run directory exists with `execution_status.csv` and a name consistent with that script (e.g. `*_switching_canonical` for `run_switching_canonical.m`). Helper modules are marked **NO** (libraries, not standalone run producers).

## Where duplication exists

Distinct **duplicate_group_id** values in `tables/switching_analysis_system_map.csv` (7 groups). Provenance: `tables/switching_analysis_duplicates.csv` (DG1–DG4) plus consolidation groups DG5–DG7 below.

| ID | Nature | Entities (representative) |
|----|--------|---------------------------|
| DG1 | Same script, multiple `run_*_switching_canonical` ids | `Switching/analysis/run_switching_canonical.m`; multiple run directories; see also `tables/switching_collapse_verification.csv` (SHA claims). |
| DG2 | Phi1 definition carried in more than one artifact family | `tables/switching_canonical_definition_extraction.csv`; `results/switching/runs/run_2026_04_03_000147_switching_canonical/tables/switching_canonical_phi1.csv`. |
| DG3 | Collapse topic split across verification table and interpretation | `tables/switching_collapse_verification.csv`, `reports/switching_collapse_verification.md`, `tables/switching_collapse_status.csv`, `reports/switching_collapse_interpretation.md`. |
| DG4 | Layer1 robustness reconciliation vs audit bundles | Reconciliation and audit tables/reports listed under DG4 in the map. |
| DG5 | Same closure test, two script versions | `run_width_interaction_closure_test.m`, `run_width_interaction_closure_test_v2.m`. |
| DG6 | Overlapping survey / inventory artifacts | `switching_analysis_inventory*`, `switching_analysis_progress_survey*` (tables and reports). |
| DG7 | Repo-root `tables/*.csv` filenames that can mirror run-scoped canonicalization outputs | Several `tables/switching_*.csv` rows carry notes; compare to `results/switching/runs/run_*_canonicalization_l3_*/tables/` before treating repo-root copies as authoritative. |

## Where ambiguity exists

1. **Survey vs connectivity map:** `tables/switching_analysis_full_classification.csv` assigns classes such as `FAILED_CANONICAL` or `LEGACY` to logical ids that `tables/switching_canonical_analysis_map.csv` marks `TRUE_CANONICAL` with run-backed paths. This audit does not resolve that conflict; it surfaces both sources.
2. **Bundled copies inside L3 runs:** Canonicalization runs under `results/switching/runs/run_*_canonicalization_l3_*/` copy many `switching_canonical_*.csv` files. Only paths listed in `switching_canonical_analysis_map.csv` artifact lists are marked **CANONICAL_CONFIRMED**; sibling copies in the same run folder may remain **UNKNOWN** in the map unless listed.
3. **Large UNKNOWN count (352):** Most `Switching/analysis` runners have no matching run directory under `results/switching/runs/` with signaling (or no run at all), so they stay **UNKNOWN** without rerunning or deeper linkage work.

## Is the system clean enough for a new survey?

**No.** Reasons: high **UNKNOWN** surface area, deliberate duplicate groups (DG1–DG7), repo vs run-scoped filename overlap (DG7), and conflicting classification sources (full classification vs canonical analysis map). A new canonical survey should treat `tables/switching_analysis_system_map.csv` as the file-level index, then reconcile logical ids and duplicate groups explicitly.

## Artifacts produced by this audit (new files only)

- `tables/switching_analysis_system_map.csv`
- `tables/switching_analysis_system_status.csv`
- `reports/switching_analysis_system_audit.md` (this file)
