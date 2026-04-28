# Repository Structure Governance Audit

## Executive Summary
This audit reviewed the repository structure as a governance problem rather than a cleanup task. The repo already contains useful top-level namespaces for `results/`, `tables/`, `reports/`, and `figures/`, but they coexist with a heavily overloaded root, mixed-role shared folders, inconsistent module conventions, and multiple competing legacy or quarantine areas.

The clearest path forward is not a bulk move. The immediate win is policy: freeze the meaning of each directory layer, define the run-container contract, declare the canonical durable destinations, and stop new writes to ambiguous locations. After that, future migration can happen in a lineage-preserving way.

No files were moved, renamed, deleted, or rewritten as part of this audit.

## Current Repo Topology
- Root is heavily overloaded: 139 root-level files, including 57 `run_*` entrypoints, 73 `.m` files, 14 `.md` files, 12 `.csv` files, and 11 `.log` files.
- Active source modules are present but not normalized:
  - `Switching/` is shallow and source-only.
  - `Aging/` is comparatively well-structured and source-only.
  - `Relaxation ver3/` is mostly flat plus `diagnostics/`.
  - `MT ver2/` is flat and does not match the requested `MT/` name.
- Shared durable artifact layers exist and are already valuable:
  - `results/` contains run trees.
  - `tables/` contains durable CSV-heavy outputs.
  - `reports/` contains durable markdown-heavy outputs.
  - `figures/` contains durable image exports.
- Legacy and quarantine material is large and fragmented:
  - `results_old/` alone holds 13,318 files across 3,232 directories.
  - `tables_old/`, `archive/`, `_legacy/`, `Aging old/`, and `tmp_root_cleanup_quarantine/` introduce multiple competing legacy semantics.

### Selected Tree Snapshot
```text
Aging/
  - analysis/
  - diagnostics/
  - docs/
  - models/
  - pipeline/
  - plots/
  - tests/
    - switching_stability/
  - utils/
  - verification/

Switching/
  - analysis/
  - utils/

Relaxation ver3/
  - diagnostics/

MT ver2/

analysis/
  - helpers/
  - knowledge/
  - query/
  - switching/
  - switching dynamics/

tools/
  - claims/
  - figure_repair/
  - figures/
  - maintenance/
  - run_review/
  - survey_audit/
  - survey_builder/
  - survey_registry/

docs/
  - analysis_notes/
  - internal/
  - model/
  - observables/
  - reports/
  - templates/

scripts/

results/
  - aging/
    - debug_runs/
    - decomposition/
    - figures/
    - runs/
  - analysis/
    - runs/
  - cross_experiment/
    - runs/
  - mt/
    - runs/
  - relaxation/
    - runs/
  - relaxation_canonical/
    - runs/
  - relaxation_post_field_off_canonical/
    - runs/
  - relaxation_post_field_off_RF3R_canonical/
    - runs/
  - switching/
    - figures/
    - runs/
  - xx_relaxation/
    - runs/

reports/
  - aging/
  - maintenance/
  - relaxation/
  - relaxation_perturbation/

tables/
  - aging/
  - relaxation/

figures/
  - aging/
  - parameter_robustness_stage1_canonical/
  - relaxation/
  - switching_parameter_robustness/
  - xx_relaxation_validation/
  - xx_slope_diagnostics_35mA/
  - xx_slope_diagnostics_35mA_aligned/
  - xx_slope_generalization_diagnostics/

results_old/
  - aging/
    - debug_runs/
    - runs/
  - cross_analysis/
    - runs/
  - cross_experiment/
    - runs/
  - legacy_root/
    - runs/
  - phaseC/
    - runs/
  - relaxation/
    - runs/
  - relaxation_canonical/
    - runs/
  - repository_audit/
    - runs/
  - repository_cleanup/
  - review/
    - runs/
  - switching/
    - observable_summary/
    - runs/
  - system/
    - runs/
  - tests/
    - figure_repair_validation_tmp/
    - matlab_prefdir/

runs/
  - fingerprints/
```

## Current Directory Roles
- `MODULE_SOURCE`: `Aging/`, `Switching/`, `Relaxation ver3/`, `MT ver2/`.
- `SHARED_CODE` or `TOOLING`: `analysis/`, `tools/`, `scripts/`, `tests/`, `templates/`, `General ver2/`, `Tools ver1/`.
- `RUN_OUTPUTS`: `results/`, `runs/`, `logs/`, `tmp/`, `probe_outputs/`, and parts of `status/`.
- `DURABLE_TABLES`, `DURABLE_REPORTS`, `DURABLE_FIGURES`: `tables/`, `reports/`, `figures/`.
- `DOCUMENTATION`: `docs/`, `canonical/`, `surveys/`, much of `claims/`, plus scattered module and root markdown.
- `LEGACY_QUARANTINE`: `results_old/`, `tables_old/`, `archive/`, `_legacy/`, `Aging old/`, `tmp_root_cleanup_quarantine/`, `junk/`.

## Mixed-Role Directories
High-risk mixed-role directories identified in this audit:
- `.`: root mixes live source, maintenance docs, CSV audits, logs, and transient probes.
- `analysis/`: shared code mixed with logs, text notes, and knowledge CSVs.
- `scripts/`: live orchestrators mixed with CSVs, logs, and ad hoc markdown.
- `reports/`: durable markdown reports mixed with `.m`, `.ps1`, `.csv`, `.json`, and `.log` files.
- `tables/aging/`: durable tables mixed with JSON sidecars, text sidecars, and an `.m` file.
- `runs/`: small run-output area that also contains `.m` files.
- `status/`: maintenance/status content blended with fixture-like trees and CSVs.
- `results/aging/figures/`: figure exports mixed with CSV and markdown sidecars inside a run or output layer.

## Same-Type Scatter Patterns
- Live MATLAB entrypoints are split across the root, `scripts/`, module roots, and run-output folders.
- Markdown is split across root docs, `docs/`, `reports/`, module roots, `surveys/`, and legacy areas.
- CSV tables are split across `tables/`, root audit files, `results/*/runs/*`, `status/`, `analysis/knowledge/`, and legacy zones.
- Figure exports are split across `figures/`, `results/aging/figures/`, `results_old/` run trees, `tmp/`, and tool validation areas.
- Logs and probe text are split across root, `logs/`, `tmp/`, `probe_outputs/`, `analysis/`, and run folders.
- JSON manifests and catalogs are split across run folders, `claims/`, `snapshot_scientific_v3/`, `docs/model/`, `tables/`, and tooling folders.

## Module Convention Inconsistencies
- `Aging/` is the closest thing to a module convention today: it has `analysis/`, `diagnostics/`, `models/`, `pipeline/`, `plots/`, `tests/`, `utils/`, and module-local docs.
- `Switching/` uses only `analysis/` and `utils/`, so concepts such as diagnostics, tests, reports, and figures are not represented locally the same way.
- `Relaxation ver3/` keeps most source flat at the module root and adds only `diagnostics/`.
- `MT ver2/` is entirely flat and also diverges in naming from `results/mt/`.
- Module artifact conventions also differ:
  - Aging has `reports/aging/`, `tables/aging/`, and populated `results/aging/figures/`, but `figures/aging/` is empty.
  - Relaxation has `reports/relaxation/`, `tables/relaxation/`, and `figures/relaxation/`.
  - Switching has `results/switching/` and switching-related figures under `figures/switching_parameter_robustness/`, not a clearly named `figures/switching/` tree.

## Root-Level Structure Issues
- The root behaves like an execution workspace rather than a controlled repository index.
- Root-level maintenance outputs already duplicate the intended governed destinations (`reports/maintenance/` and `tables/`).
- Root-level `run_*.m` files hide module ownership and make discovery path-dependent.
- Root-level logs and probe text make transient state look durable.
- Root-level markdown blends policy, scientific notes, and operation status.

## Proposed Target Architecture
- `docs/`
  - Durable repository policy, contracts, architecture docs, and human-readable module references.
- `tools/`
  - Shared execution, validation, maintenance, and infrastructure utilities.
- `scripts/`
  - Stable human-invoked orchestrators only, ideally organized by module for discoverability.
- `<Module>/`
  - Module-owned source code, tests, and tightly coupled local docs only.
  - No silent accumulation of generated artifacts.
- `results/<module>/runs/<run_id>/`
  - Run-scoped outputs, manifests, logs, raw execution products, and immutable entrypoint snapshots.
- `tables/<module>/`
  - Durable canonical CSV summaries, inventories, and structured exports.
- `reports/<module>/`
  - Durable markdown reports.
- `figures/<module>/`
  - Durable exported figures promoted from run outputs after lineage checks.
- `results_old/`, `tables_old/`, `archive/`, `_legacy/`, `Aging old/`
  - Write-closed legacy or quarantine only; no new writes.
- `reports/maintenance/`, `tables/maintenance_*.csv`
  - Repository-health and maintenance outputs.

## Migration Phases
1. Phase 0: publish the directory policy, module alias map, and write-freeze rules for legacy and root output locations.
2. Phase 1: formalize contracts for `results/<module>/runs/<run_id>/` and for promotion into `tables/`, `reports/`, and `figures/`.
3. Phase 2: redirect all new maintenance outputs, logs, probes, and transient text into governed destinations without moving history.
4. Phase 3: clean up mixed-role boundaries for future writes, especially `analysis/`, `scripts/`, `reports/`, and `tables/`.
5. Phase 4: inventory and reassign root-level entrypoints and root-level audit files only after ownership and reference checks.
6. Phase 5: consider physical source-folder normalization or vendor isolation only after lineage and path-reference audits are complete.

## What Must Not Be Moved Yet
- Do not bulk-move historical scientific run trees under `results/` or `results_old/` without lineage and consumer checks.
- Do not rename `MT ver2/`, `Relaxation ver3/`, or versioned historical module roots until path references are audited.
- Do not collapse distinct `Switching` canonical families into a single undifferentiated folder.
- Do not relocate run-folder `.m` snapshots until the repo declares whether they are immutable lineage evidence or live source.
- Do not move vendor-like third-party content under `github_repo/` until license and reference expectations are documented.

## What Should Be Documented Immediately
Items that can be solved by documentation immediately:
- Publish a role glossary for `source`, `run outputs`, `durable tables`, `durable reports`, `durable figures`, and `legacy/quarantine`.
- Publish a module alias table, especially `MT ver2` -> `mt`.
- Declare `results_old/`, `tables_old/`, `archive/`, `_legacy/`, and similar zones as write-closed.
- Declare `reports/maintenance/` and `tables/maintenance_*.csv` as the canonical maintenance output locations.
- Define whether `.m` files inside run folders are immutable snapshots.

Items that require future migration rather than documentation alone:
- Reassigning root-level `run_*.m` files.
- Splitting `analysis/` and `scripts/` mixed outputs from reusable code.
- Cleaning code out of `reports/` and `tables/` where the files are live helpers rather than immutable evidence.
- Normalizing figure destinations for Aging and Switching.
- Any physical rename of module folders or vendor areas.

## Status
```text
REPO_STRUCTURE_GOVERNANCE_AUDIT_COMPLETE: YES
CURRENT_STRUCTURE_MAPPED: YES
MIXED_ROLE_DIRECTORIES_IDENTIFIED: YES
SAME_TYPE_SCATTER_IDENTIFIED: YES
TARGET_STRUCTURE_PROPOSED: YES
TRANSITION_BACKLOG_WRITTEN: YES
FILES_MOVED: NO
FILES_DELETED: NO
SAFE_TO_RESTRUCTURE_NOW: POLICY_ONLY_AND_NEW_WRITE_REDIRECTION
```
