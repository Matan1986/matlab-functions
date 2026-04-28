# Unified Artifact Policy Synthesis

## Executive Summary
This synthesis consolidates available repository artifact organization audits into one policy + migration-planning package.

This is a planning-only output:
- no files moved
- no files deleted
- no cleanup performed
- no scientific artifacts rewritten

The synthesis adopts the clean Aging rerun as authoritative Aging evidence and treats contaminated Aging material as superseded historical context.

## What Audits Were Used
Used evidence sources include:
- repo artifact atlas and risk inventory
- Switching artifact organization audit + family map/risk tables
- Aging clean rerun audit + excluded cross-module candidates
- Relaxation artifact organization audit + family/risk tables
- root folder declutter audit + relocation/blocker tables
- repository structure governance audit + proposal + transition/scatter/inconsistency maps

## Missing or Evidence-Limited Inputs
- No required input path was missing at synthesis time.
- Several large csv inputs were used in sampled/partial form due size limits in interactive reads; these are marked `PARTIAL_READ_LARGE` in `tables/maintenance_artifact_policy_input_coverage.csv`.
- `tables/aging/aging_artifact_cross_module_status_check.csv` was treated as superseded contamination-history context, not as authoritative Aging policy evidence.

## Global Disorder Patterns
- Root overload mixes scripts, logs, governance csv/md, and module outputs.
- Shared folders are mixed-role (`analysis/`, `scripts/`, `reports/`, `tables/`).
- Durable and run-scoped outputs are split inconsistently (especially figures and root tables/reports).
- Legacy namespaces are large and semantically overlapping.
- Consumer-path dependencies (including hard-coded run IDs) block naive relocation.

## Module-Specific Disorder Patterns
- Switching: family separation is critical; replay/legacy/canonical branches are distinct and cannot be merged.
- Aging: clean rerun confirms large module-local surface plus legacy/replay/cross-module-exclusion needs; root/shared exceptions need indexing before any movement.
- Relaxation: RF3R and RF3R2 must remain separated; figure/map families (raw/normalized/baseline/positive/log/linear) must remain explicit and indexed.

## Root-Folder Findings
- Root remains overpopulated and policy-ambiguous.
- No-reference exact-string results are insufficient for safe MATLAB script movement due bare-stem invocation risk.
- Any root script movement is blocked until ownership/caller mapping is explicit.

## Repo-Structure Findings
- Governance direction is clear: source-first modules, run-scoped results lineage, durable promoted tables/reports/figures, write-closed legacy namespaces.
- Immediate gains are policy + index coverage + new-write routing; not physical migration.

## Proposed Final Artifact Topology
- Source: module roots (`Aging/`, `Switching/`, `Relaxation ver3/`, `MT ver2/`)
- Run lineage: `results/<module>/runs/<run_id>/`
- Durable promotions: `tables/<module>/`, `reports/<module>/`, `figures/<module>/`
- Maintenance durable outputs: `reports/maintenance/`, `tables/maintenance_*.csv`
- Legacy write-closed: `results_old/`, `tables_old/`, `archive/`, `_legacy/`, `Aging old/`

## Directory Contract Summary
See `docs/artifact_directory_contract.md` for path-by-path contract covering:
- root
- shared layers (`docs/`, `tools/`, `scripts/`, `analysis/`, `results/`, `runs/`, `tables/`, `reports/`, `figures/`)
- module roots
- legacy namespaces
- source-of-truth and write policies

## Cleanup Phases
- Phase 0: policy/index creation only, no movement
- Phase 1: root declutter candidates with explicit review only; no MATLAB script movement while invocation risk unresolved
- Phase 2: durable governance artifact tracking and ignore-policy alignment
- Phase 3: module README/index completion before any relocation
- Phase 4: controlled low-risk relocation with reference + lineage checks
- Phase 5: legacy/quarantine consolidation without scientific deletion

## Blocked Actions
Blocked until explicit resolution:
- movement of root `run_*.m` scripts
- dedup/relocation of run families with hard-coded run dependencies
- switching family coalescing
- RF3R/RF3R2 collapsing
- cleanup automation over fixture-like `status/` trees
- any migration without module index coverage

## Safe First Cleanup Candidates, If Any
No broadly safe movement is authorized yet.
- Low-lineage root logs may be review candidates in Phase 1 only after explicit human review.
- `SAFE_TO_START_CLEANUP_PHASE_1=NO` remains the policy verdict.

## Durable Governance Artifact / .gitignore Handling
- Durable governance artifacts are allowed under `reports/maintenance/`, `tables/maintenance_*.csv`, and designated policy docs in `docs/`.
- Force-add is allowed only for explicitly approved durable governance outputs that satisfy ownership and retention criteria.
- Force-add is not allowed for transient logs/probes/local tooling state.

## Explicit Non-Modification Statements
- No files were moved.
- No files were deleted.
- No scientific artifacts were rewritten.
- No cleanup was performed.

## Status Block
- UNIFIED_ARTIFACT_POLICY_COMPLETE=YES
- DIRECTORY_CONTRACT_COMPLETE=YES
- MIGRATION_BACKLOG_WRITTEN=YES
- CLEANUP_BLOCKERS_WRITTEN=YES
- REQUIRED_INDEXES_WRITTEN=YES
- POLICY_INPUT_COVERAGE_WRITTEN=YES
- AGING_CLEAN_RERUN_USED=YES
- CONTAMINATED_AGING_AUDIT_SUPERSEDED=YES
- ROOT_AUDIT_INCLUDED=YES
- REPO_STRUCTURE_GOVERNANCE_INCLUDED=YES
- SWITCHING_FAMILY_SEPARATION_PRESERVED=YES
- RELAXATION_RF3R_RF3R2_SEPARATION_PRESERVED=YES
- FILES_MOVED=NO
- FILES_DELETED=NO
- SCIENTIFIC_ARTIFACTS_REWRITTEN=NO
- CLEANUP_PERFORMED=NO
- SAFE_TO_START_CLEANUP_PHASE_1=NO
- LINEAGE_PROTECTION_REQUIRED=YES
