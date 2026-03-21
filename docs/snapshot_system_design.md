# Snapshot System Design

Last updated: 2026-03-21

## Design Goals
- full-root modular packaging
- dependency closure by module
- reproducibility-aware optional data bundles
- strict exclusion of local machine state

## Proposed ZIP Modules

### MODULE: core_infra
- Includes: `docs/`, `tools/`, `runs/`, `tests/`
- Required co-modules: none
- Priority: required
- Rationale: shared helpers, policy, launchers, and validation surface.

### MODULE: active_aging
- Includes: `Aging/`
- Required co-modules: `core_infra`
- Priority: required for aging workflows
- Rationale: canonical pipeline and active analyses.

### MODULE: active_switching
- Includes: `Switching/`
- Required co-modules: `core_infra`, `active_aging`
- Priority: required for switching workflows
- Rationale: switching analyses rely on aging run helper surface and shared tools.

### MODULE: active_relaxation
- Includes: `Relaxation ver3/`
- Required co-modules: `core_infra`, `active_aging`
- Priority: required for relaxation diagnostics stack
- Rationale: diagnostics depend on shared run helpers.

### MODULE: cross_experiment_analysis
- Includes: `analysis/`
- Required co-modules: `core_infra`, `active_aging`
- Optional co-modules: `active_switching`, `active_relaxation` (depending on script)
- Priority: optional but common
- Rationale: cross-experiment scripts are orchestration/bridge layer.

### MODULE: experimental_pipelines
- Includes: `AC HC MagLab ver8/`, `ARPES ver1/`, `FieldSweep ver3/`, `HC ver1/`, `MH ver1/`, `MT ver2/`, `PS ver4/`, `Resistivity MagLab ver1/`, `Resistivity ver6/`, `Susceptibility ver1/`, `zfAMR ver11/`
- Required co-modules: `core_infra`
- Priority: optional but first-class
- Rationale: independent experimental pipelines are actively used and scientifically relevant even when outside the unified Aging/Switching/Relaxation stack.

### MODULE: switching_legacy_runtime
- Includes: `Switching ver12/`
- Required co-modules: `active_switching`
- Priority: optional but required for `switching_alignment_audit.m`
- Rationale: active switching stack still imports this legacy runtime.

### MODULE: legacy_science_archive
- Includes: `Aging old/`, `Fitting ver1/`, `Tools ver1/`
- Required co-modules: none
- Priority: reproducibility-only
- Rationale: preserved historical/legacy modules outside the active and independent-pipeline modules.

### MODULE: visualization_stack
- Includes: `GUIs/`, `tools/figures/`, `tools/figure_repair/`, optionally `github_repo/ScientificColourMaps8/`, optionally `General ver2/appearanceControl/` + `General ver2/figureSaving/`
- Required co-modules: `core_infra`
- Priority: optional
- Rationale: figure/GUI system can be consumed independently.

### MODULE: metadata_review_layer
- Includes: `claims/`, `surveys/`, `reports/`, `tools/claims/`, `tools/run_review/`, `tools/survey_*`
- Required co-modules: `core_infra`
- Priority: optional
- Rationale: claim and survey workflows.

### MODULE: results_reference
- Includes: selected `results/<experiment>/runs/run_<id>/` only
- Required co-modules: whichever code modules consume those runs
- Priority: optional data bundle
- Rationale: reproducibility without shipping full local results tree.

## Master ZIP Structure

### Master package (recommended)
- `manifest/root_inventory.json`
- `manifest/modules.json`
- `manifest/dependency_graph.json`
- `zips/core_infra.zip`
- `zips/active_aging.zip`
- `zips/active_switching.zip`
- `zips/active_relaxation.zip`
- `zips/cross_experiment_analysis.zip`
- optional zips (`switching_legacy_runtime.zip`, `experimental_pipelines.zip`, `visualization_stack.zip`, `legacy_science_archive.zip`, `metadata_review_layer.zip`, `results_reference_<label>.zip`)

## Manifest Schema (minimum)

### modules.json
- module_name
- version
- included_paths
- required_modules
- optional_modules
- checksum
- created_at

### dependency_graph.json
- node: root module
- edges: `to`, `type` (`hard`|`optional`), `class` (`code`|`runtime`|`data`|`legacy`)

### root_inventory.json
- folder
- category
- status
- snapshot_recommendation
- evidence_refs

## Inclusion Rules
- Always include `core_infra`.
- Enforce required-module closure before export.
- Block unresolved hard dependencies (for example switching stack without `Switching ver12` when alignment audit is included).
- If `analysis/` is included, require selected results references or disable scripts that require missing runs.

## Exclusion Rules (default denylist)
- local/system state: `.appdata/`, `.codex_*`, `.localappdata/`, `.matlab_pref*`, `.mwhome/`, `.vscode/`, `.tmp_test/`, `tmp/`, `tmp_root_cleanup_quarantine/`, `MathWorks/`, `.git/`
- generated outputs by default: full `results/`
- include `results/` only through explicit `results_reference` selections

## Packaging Risks
- broad `addpath(genpath(...))` can create function-resolution drift across module boundaries
- active scripts with hardcoded run IDs require curated `results_reference` bundles
- residual non-canonical output conventions can break strict artifact expectations
- duplicate function names across modules can break isolated-module execution if path order changes

