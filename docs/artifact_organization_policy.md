# Artifact Organization Policy

## Purpose and Scope
This policy defines repository-wide artifact organization rules for outputs, lineage containers, durable exports, diagnostics, and legacy material. It is governance and migration-planning only.

Non-goals for this policy cycle:
- no file movement
- no renames
- no deletions
- no scientific artifact rewrites
- no code refactoring
- no module science synthesis

## Current Disorder Summary
Evidence across artifact atlas, module audits, root declutter, and governance audits shows:
- root-level overload (scripts, logs, csv/md outputs mixed with source)
- mixed-role shared folders (`analysis/`, `scripts/`, `reports/`, `tables/`)
- split run-vs-durable destinations for figures/tables/reports
- large write-active legacy/quarantine surfaces (`results_old/`, `tables_old/`, `archive/`)
- module convention mismatch (Aging structured; Switching shallow; Relaxation mostly flat)

## Artifact Taxonomy
- `MODULE_SOURCE`: live scientific code and tightly coupled helpers/docs
- `RUN_OUTPUTS`: run-scoped lineage artifacts under run containers
- `DURABLE_TABLES`: long-lived canonical csv inventories/summaries
- `DURABLE_REPORTS`: long-lived markdown analyses/audits
- `DURABLE_FIGURES`: promoted figure exports intended for durable reference
- `MAINTENANCE_GOVERNANCE`: repository health and governance outputs
- `DIAGNOSTICS`: troubleshooting/probe outputs; run-scoped unless promoted
- `LEGACY_QUARANTINE`: historical or invalid/stale artifacts, write-closed

## Canonical Directory Layout
- `results/<module>/runs/<run_id>/` is the default run lineage container.
- `tables/<module>/`, `reports/<module>/`, `figures/<module>/` are durable promoted layers.
- `reports/maintenance/` and `tables/maintenance_*.csv` are durable maintenance/governance destinations.
- `results_old/` and `tables_old/` remain write-closed legacy namespaces.

## Module Directory Conventions
- `Aging/`, `Switching/`, `Relaxation ver3/`, `MT ver2/` are source-first.
- Module folders may contain source-coupled docs/tests/utilities.
- Module folders must not silently accumulate generated artifacts.
- Module aliasing is policy-only for now (for artifact routing), no physical rename.

## Run Directory Conventions
Each new run directory must contain, at minimum:
- run identifier and timestamped folder name
- run manifest (`run_manifest.json` or equivalent)
- execution status (`execution_status.csv` or equivalent)
- log material (`log.txt` or structured log)
- config/entrypoint snapshot (immutable lineage capture)
- raw run products and intermediate outputs

Run folders are lineage containers, not cleanup staging.

## Figure Conventions
- Ephemeral run figures: `results/<module>/runs/<run_id>/figures/`
- Durable promoted figures: `figures/<module>/`
- Promotion requires lineage backlink to run container and writer script.
- Relaxation must preserve separate figure/map families (raw, normalized, baseline-centered, positive-display, log-time, linear-time), with metadata index fields for transform, units, source, inclusion/exclusion rules.

## Table Conventions
- Run-scoped working tables remain in run containers.
- Durable canonical tables belong in `tables/<module>/`.
- Maintenance/governance tables use `tables/maintenance_*.csv` naming.
- No new durable tables at root.

## Report Conventions
- Durable module reports belong in `reports/<module>/`.
- Durable maintenance/governance reports belong in `reports/maintenance/`.
- No new durable reports at root.

## Status / Manifest / Log Conventions
- Runtime status/logs are run-scoped (`results/<module>/runs/<run_id>/...`).
- Maintenance execution logs use `results/maintenance/runs/<run_id>/` (future rule).
- `status/` fixture trees must be explicitly labeled as fixture/test evidence and excluded from cleanup automation by default.

## Legacy / Archive / Old Conventions
- `results_old/`, `tables_old/`, `archive/`, `_legacy/`, `Aging old/`, `tmp_root_cleanup_quarantine/` are write-closed.
- No new writes to legacy namespaces.
- No scientific deletion policy is authorized by this document.

## Diagnostic Artifact Conventions
- Diagnostics are non-canonical by default.
- Diagnostics must declare module ownership and lineage link.
- Diagnostics can be promoted only when indexed, referenced, and policy-approved.

## Root Folder Policy
Root must stay minimal:
- allowed: repository metadata, governed top-level layers, module roots, minimal bootstrap files
- forbidden: new ad hoc logs, new run products, new root-level module scripts, new one-off diagnostics outputs

No root cleanup execution is authorized in this phase.

## Module Source Folder Policy
- source-first, artifact-light
- no silent generated artifact accumulation
- diagnostic scripts allowed if explicitly module-owned and indexed

## Shared Folder Policy
- `docs/`: durable policy/contracts/architecture
- `tools/`: reusable shared infrastructure/utilities
- `scripts/`: stable orchestrators only
- `analysis/`: shared analysis code; no long-term output dumping
- `results/`: run lineage
- `tables/`,`reports/`,`figures/`: durable promoted outputs
- `runs/`: reserved for governed run-adjacent utilities/fingerprints only

## Naming Rules
- Run IDs must remain stable and parseable (`run_<timestamp>_<label>` or module standard).
- Artifact names must include family and purpose context where applicable.
- Switching geocanon forbidden names are disallowed for new canonical semantics (`X_canon`, `collapse_canon`, `Phi_geo`, `kappa_geo`, `mode_geo`, `width_canon`, `reactivity_canon`, `A_active`).
- Relaxation RF3R and RF3R2 names remain distinct.

## Source-of-Truth Rules
Priority order:
1. lineage-bearing run containers (`results/<module>/runs/<run_id>/`)
2. module durable promoted layers (`tables/<module>/`, `reports/<module>/`, `figures/<module>/`)
3. governance policy docs (`docs/`, `reports/maintenance/`, `tables/maintenance_*.csv`)
4. legacy namespaces for historical replay/reference only

## Minimum Artifact Contract for New Artifact-Producing Scripts
Every new artifact-producing script must define:
- owner module
- output class (run-scoped vs durable promoted)
- destination path contract
- run ID / lineage link
- manifest/status outputs
- whether output is canonical, diagnostic, replay, failed/partial, or legacy
- consumer references (if known)
- migration-safety classification

## README / Index Requirements
Minimum required indexes:
- `results/<module>/README.md`
- `tables/<module>/README.md`
- `reports/<module>/README.md`
- `figures/<module>/README.md` (or explicit absence rationale)
- module artifact index documents for family separation and lineage
- maintenance layer indexes for governance tables/reports

## .gitignore and Force-Add Policy
- Durable governance artifacts may be force-added only when:
  - explicitly in approved governance destinations (`reports/maintenance/`, `tables/maintenance_*.csv`, selected `docs/` policy docs)
  - not transient probe/log spillover
  - linked to a declared maintenance/audit contract
- Force-add is forbidden for ad hoc transient outputs and local tooling state.

## Forbidden Patterns
- bulk movement based only on no-reference exact-string scans
- cleanup based solely on path name intuition
- deletion of scientific artifacts
- collapsing Switching families (`legacy_old`, `canonical_residual_decomposition`, `canonical_geometric_decomposition`, `canonical_replay`)
- collapsing Relaxation RF3R/RF3R2 families
- claiming full Relaxation canonical readiness in organization policy
- using contaminated Aging evidence for Aging-only claims

## Cleanup Phase Policy
- Phase 0: policy/index creation only; no movement
- Phase 1: root declutter candidates only after explicit review; no MATLAB script movement while bare-stem invocation risk is unresolved
- Phase 2: durable governance artifact tracking and ignore-policy alignment
- Phase 3: module README/index completion; no movement before index coverage
- Phase 4: controlled low-risk relocation by module with lineage+reference checks
- Phase 5: legacy/quarantine consolidation without scientific deletion

## Lineage Protection Rules
- No relocation without lineage checks and consumer checks.
- No deduplication of run trees without canonical pointer/index layer.
- Run manifests and execution status are immutable lineage evidence.
- Failed/partial runs are retained and labeled; not discarded silently.

## Module-Specific Preservation Constraints
- Switching: preserve family separation and geocanon naming constraints.
- Relaxation: preserve RF3R/RF3R2 split and map/view-family distinctions.
- Aging: use clean rerun only for Aging-only claims; keep cross-module bridges excluded from Aging-only inventories.
