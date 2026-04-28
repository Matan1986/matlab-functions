# Root Folder Declutter Audit

## Executive summary
This audit inspected only the repository root first-level files and first-level directories, then performed a conservative exact-filename reference scan for root-level files across source and documentation areas of the repository.

The audit classified 140 root-level files and 60 root-level directories. The documented root contract from `README.md` and `docs/repository_structure.md` supports keeping experiment-module folders plus shared layers such as `analysis/`, `docs/`, `results/`, `runs/`, `tools/`, `tests/`, `reports/`, `tables/`, and `figures/` in root. Most other root-level files are status artifacts, audit tables, logs, one-off MATLAB scripts, repair runners, or local environment state that do not fit that contract.

The authoritative detailed lists are written to:

- `tables/maintenance_root_folder_inventory.csv`
- `tables/maintenance_root_folder_reference_check.csv`
- `tables/maintenance_root_folder_relocation_backlog.csv`
- `tables/maintenance_root_folder_cleanup_blockers.csv`

No files were moved, renamed, deleted, or refactored in this task.

## Root folder topology
Root inventory summary:

- Root-level files: 140
- Root-level directories: 60
- Detailed per-item listing: `tables/maintenance_root_folder_inventory.csv`

Root areas that clearly belong in root under the current documented structure:

- Experiment/module folders such as `Aging/`, `Relaxation ver3/`, `Switching/`, `PS ver4/`, `MT ver2/`, `HC ver1/`, `MH ver1/`, `zfAMR ver11/`, and similar versioned analysis folders.
- Shared repository layers such as `analysis/`, `docs/`, `results/`, `runs/`, `tools/`, `tests/`, `reports/`, `tables/`, and `figures/`.
- Repository control files such as `README.md`, `CONTRIBUTING.md`, `.gitignore`, `.gitattributes`, and `matlab-functions.code-workspace`.

Root areas that visibly increase clutter pressure:

- Legacy or duplicate directories such as `analysis_new/`, `archive/`, `results_old/`, `tables_old/`, `Aging old/`, `Switching ver12/`, and `tmp_root_cleanup_quarantine/`.
- Local environment state and temp directories such as `.codex_matlab_prefs/`, `.codex_tmp/`, `.matlab_prefs/`, `.mwhome/`, `MathWorks/`, `matlab_prefs_agent/`, `temp/`, and `tmp/`.
- Loose root files for reports, CSVs, logs, probes, wrappers, and module-specific MATLAB diagnostics.

## What belongs in root
- Versioned experiment/module directories and the current active/shared repository zones documented in `README.md` and `docs/repository_structure.md`.
- Minimal bootstrap/config files that are intentionally root-oriented, notably `setup_repo.m` and `load_local.m`.
- Repository-facing documentation files such as `README.md` and `CONTRIBUTING.md`.

## What appears misplaced
- Root MATLAB scripts for experiment diagnostics, replays, audits, tests, wrappers, and repair runners that should live in a module diagnostics area, `runs/`, or a maintenance/tools area.
- Root CSV and markdown audit artifacts that belong under `tables/maintenance/` and `reports/maintenance/`.
- Root logs, probe outputs, and status text files that look like generated execution artifacts rather than source.
- Local environment state directories such as MATLAB preference/cache folders and temporary probe directories.
- Legacy, duplicate, or quarantine-style directories such as `analysis_new/`, `archive/`, `results_old/`, `tables_old/`, `Aging old/`, `Switching ver12/`, and `tmp_root_cleanup_quarantine/`.

## Root-level MATLAB script classification
Root-level MATLAB scripts were classified with filename-role heuristics and repository-structure context:

- `canonical entrypoint`: 1
- `diagnostic script`: 29
- `legacy script`: 22
- `maintenance script`: 4
- `one-off repair script`: 4
- `unknown`: 14

Key patterns:

- Root `run_aging_*`, `run_relaxation_*`, `run_switching_*`, `run_kappa*`, and similar scripts look module-specific, not root-canonical.
- Files containing `audit`, `diagnostic`, `validation`, `probe`, `test`, or `minimal` read like diagnostics rather than canonical entrypoints.
- Files containing `repair`, `rescue`, `recovery`, or `bridge` look like one-off repair or replay workflows that should not stay loose in root.
- Wrapper scripts such as `run_*_wrapper.m` appear legacy and are especially strong declutter candidates.

## Generated artifact clutter patterns
Generated root-level artifact counts identified by extension/type:

- CSV: 12
- MAT: 1
- PNG/JPG/PDF/SVG/FIG: 0
- MD reports/status docs: 9
- TXT/log/output/json/exit files: 30

Observed clutter patterns:

- Module-specific files in root: many root `run_*.m` files are clearly Aging, Relaxation, or Switching scoped.
- Generated outputs mixed with source scripts: root contains CSVs, logs, MAT files, and status text alongside runnable MATLAB code.
- Old repair scripts: multiple `repair`, `replay`, `rescue`, `bridge`, and `recovery` runners sit directly in root.
- Unindexed diagnostics: temporary probes and wrapper logs exist as loose root files without a run folder.
- Duplicate reports/tables: repeated cleanup, drift-check, canonical-state, and audit outputs are stored flat in root.
- Files with unclear ownership: items such as `tatus`, root probes, and one-off temp scripts have weak provenance.

## Reference-risk summary
The reference check written to `tables/maintenance_root_folder_reference_check.csv` used a conservative exact-filename text scan across root files plus source and documentation areas such as module folders, `runs/`, `scripts/`, `tests/`, `tools/`, `docs/`, and selected root text files.

Reference summary:

- Reference rows with at least one match: 1166
- Root files with no exact-filename match found: 58

Interpretation:

- Any file with an exact-filename match is blocked from relocation until the referencing paths are updated.
- A `no_reference_found` result is not sufficient proof for MATLAB scripts, because bare-stem invocation and interactive use are still possible.
- Directory moves are blocked by default in this audit because only root files received the exact-filename reference scan.

## Safe relocation candidates, if any
The audit found a small set of low-lineage root log/text artifacts with no exact-filename references in the scanned source/doc set:

- `diag_probe_once.log`
- `final_wrapper_output.log`
- `probe_full_output.log`
- `probe_wrapper_log.txt`
- `probe_wrapper_log2.txt`
- `run2_full.log`
- `wrapper_diag.log`

These were still classified conservatively as `DELETE_CANDIDATE_BLOCKED` in the backlog. They were not moved or deleted in this task, and the overall repository status remains `SAFE_TO_CLEAN_ROOT_NOW=NO`.

## Blocked relocation candidates
Examples of blocked items:

- Local state or temp directories: `.codex_matlab_prefs/`, `.codex_tmp/`, `.matlab_prefs/`, `.mwhome/`, `.tmp_test/`
- Legacy or duplicate directories: `_legacy/`, `Aging old/`, `analysis_new/`, `archive/`, `results_old/`, `tables_old/`, `Switching ver12/`
- Root maintenance artifacts with references: `aging_cleanup_log.csv`, `artifact_cleanup_list.csv`, `canonical_state_freeze.csv`, `cleanup_execution.md`, `cleanup_execution_log.csv`
- Documentation/status directories needing owner review: `canonical/`, `status/`, `snapshot_scientific_v3/`
- Root scientific or module-specific MATLAB scripts that require lineage review before any move

See `tables/maintenance_root_folder_cleanup_blockers.csv` for the full blocker register and `tables/maintenance_root_folder_relocation_backlog.csv` for the per-item relocation plan.

## Recommended root folder policy
1. Keep only documented root layers, module folders, and a minimal set of repo bootstrap/config files in root.
2. Put repository maintenance tables in `tables/maintenance/` and maintenance reports in `reports/maintenance/`.
3. Put module-specific diagnostics, audits, and replay scripts inside the owning module's `diagnostics/` or `analysis/` area, not in root.
4. Put generated logs, review bundles, figures, and run byproducts under `results/<experiment>/runs/...` or repository-maintenance results storage.
5. Quarantine duplicate, historical, or uncertain content before any deletion decision.
6. Treat any root MATLAB script without a clearly documented owner as blocked until lineage and call-path review is complete.

## Explicit non-cleanup statement
No files were moved.
No files were deleted.
No script paths were changed.
No source files were refactored.

## Status block
- ROOT_FOLDER_DECLUTTER_AUDIT_COMPLETE=YES
- ROOT_FILES_CLASSIFIED=YES
- ROOT_REFERENCES_CHECKED=YES
- RELOCATION_BACKLOG_WRITTEN=YES
- CLEANUP_BLOCKERS_WRITTEN=YES
- FILES_MOVED=NO
- FILES_DELETED=NO
- SAFE_TO_CLEAN_ROOT_NOW=NO
