# Artifact Directory Contract

This contract defines intended roles, ownership, write rules, and migration notes by path.

## docs/
- Intended role: durable policy, architecture, contracts, human-readable system documentation
- Allowed: governance docs, module contracts, architecture docs, durable references
- Forbidden: run outputs, ad hoc runtime logs, transient dumps
- Owner: shared governance
- Source of truth: policy layer
- Write policy: allowed for durable docs only
- Examples: `docs/repo_structure_governance_proposal.md`
- Migration notes: move root maintenance docs here only after link checks

## tools/
- Intended role: reusable execution/validation/maintenance infrastructure
- Allowed: shared utilities, wrappers, validators
- Forbidden: durable scientific outputs
- Owner: shared tooling
- Source of truth: reusable infra code
- Write policy: code-only except explicitly documented fixtures
- Examples: `tools/maintenance/*.ps1`
- Migration notes: move root maintenance scripts here in controlled phases

## scripts/
- Intended role: stable top-level orchestrators
- Allowed: approved entrypoint scripts
- Forbidden: output dumps, logs, durable reports/tables
- Owner: shared orchestration layer
- Source of truth: live orchestrator definitions
- Write policy: script additions allowed; artifact generation must target governed destinations
- Examples: `scripts/run_switching_*.ps1`
- Migration notes: re-home root `run_*.m` gradually with reference checks

## analysis/
- Intended role: shared analysis code
- Allowed: reusable/shared analysis logic
- Forbidden: long-term output storage and ad hoc artifact sinks
- Owner: shared analysis
- Source of truth: shared analytical code
- Write policy: code additions allowed, outputs must route to governed layers
- Examples: `analysis/helpers/`
- Migration notes: mixed-role cleanup requires phased policy enforcement

## results/
- Intended role: run lineage containers and raw run outputs
- Allowed: `results/<module>/runs/<run_id>/...`
- Forbidden: unindexed durable promotions intended as canonical references
- Owner: module + shared run contract
- Source of truth: run-scoped lineage evidence
- Write policy: default destination for new executions
- Examples: `results/switching/runs/...`
- Migration notes: keep historical runs in place until lineage indexing complete

## results/<module>/runs/<run_id>/
- Intended role: immutable run container
- Allowed: manifest/status/log/config snapshot/raw outputs/intermediate artifacts
- Forbidden: mutable shared source files
- Owner: producing module
- Source of truth: run lineage
- Write policy: append-only during run, immutable post-finalization
- Examples: `run_manifest.json`, `execution_status.csv`, `log.txt`
- Migration notes: no dedup/relocation without canonical pointer layer

## runs/
- Intended role: run-adjacent governance/utilities only
- Allowed: fingerprints/index utilities (if documented)
- Forbidden: uncontrolled module outputs
- Owner: shared run-governance
- Source of truth: supporting run metadata only
- Write policy: restricted; prefer `results/<module>/runs/...`
- Examples: `runs/fingerprints/`
- Migration notes: clarify and enforce narrow scope

## tables/
- Intended role: durable csv table layer
- Allowed: module durable tables and maintenance prefixed governance tables
- Forbidden: transient run-only working files without contract
- Owner: module + maintenance layer
- Source of truth: promoted durable structured outputs
- Write policy: allowed only for durable outputs
- Examples: `tables/aging/`, `tables/relaxation/`
- Migration notes: reduce root spillover and mixed code sidecars

## tables/<module>/
- Intended role: durable module csv outputs
- Allowed: canonical summaries, indexes, policy tables
- Forbidden: ad hoc script dumps without lineage tags
- Owner: module
- Source of truth: module durable structured outputs
- Write policy: allowed for promoted outputs only
- Examples: `tables/switching/*.csv`
- Migration notes: add module README/index before relocation

## reports/
- Intended role: durable markdown report layer
- Allowed: module reports + maintenance reports
- Forbidden: live scripts/log sinks
- Owner: module + maintenance
- Source of truth: promoted durable narrative outputs
- Write policy: durable report writes only
- Examples: `reports/maintenance/*.md`
- Migration notes: remove mixed-role script/log usage over phases

## reports/<module>/
- Intended role: durable module reports
- Allowed: audit reports, narrative outputs, policy-linked analysis reports
- Forbidden: transient runtime logs
- Owner: module
- Source of truth: module durable narratives
- Write policy: durable markdown only
- Examples: `reports/aging/aging_artifact_organization_audit.md`
- Migration notes: ensure index coverage and family separation references

## figures/
- Intended role: durable promoted figure layer
- Allowed: promoted figures with lineage references
- Forbidden: untracked transient figure dumps
- Owner: module
- Source of truth: promoted durable figures
- Write policy: promotion after lineage checks
- Examples: `figures/relaxation/`
- Migration notes: align split figure destinations with run lineage links

## figures/<module>/
- Intended role: module durable figure exports
- Allowed: png/pdf/fig with index metadata
- Forbidden: unlabeled transform/view mixtures
- Owner: module
- Source of truth: promoted module figure outputs
- Write policy: require metadata/index updates on write
- Examples: `figures/relaxation/RF4B_visualization_repair/...`
- Migration notes: Aging and Switching need explicit durable figure namespace normalization

## results_old/
- Intended role: write-closed historical runs/quarantine
- Allowed: historical artifacts and lineage evidence
- Forbidden: new writes
- Owner: legacy governance
- Source of truth: historical replay/reference only
- Write policy: read-only
- Examples: `results_old/switching/runs/...`
- Migration notes: consolidation only after lineage and consumer checks

## tables_old/
- Intended role: write-closed historical durable-table namespace
- Allowed: historical tables
- Forbidden: new writes
- Owner: legacy governance
- Source of truth: historical reference only
- Write policy: read-only
- Examples: `tables_old/*.csv`
- Migration notes: no bulk moves; pointer/index strategy first

## Switching/
- Intended role: switching module source
- Allowed: source, module utilities, tests/docs tied to source
- Forbidden: silent durable artifact accumulation
- Owner: Switching module
- Source of truth: switching source
- Write policy: source only
- Examples: `Switching/analysis/`, `Switching/utils/`
- Migration notes: preserve family separation (`legacy_old`, `canonical_residual_decomposition`, `canonical_geometric_decomposition`, `canonical_replay`)

## Aging/
- Intended role: aging module source
- Allowed: source/tests/diagnostics/docs tied to source
- Forbidden: cross-module bridge claims in Aging-only governance outputs
- Owner: Aging module
- Source of truth: aging source
- Write policy: source-only + indexed diagnostics
- Examples: `Aging/analysis/`, `Aging/diagnostics/`
- Migration notes: clean rerun is authoritative for Aging-only policy claims

## Relaxation ver3/
- Intended role: relaxation module source
- Allowed: source and diagnostics
- Forbidden: collapsing RF3R/RF3R2 families and mixed view families
- Owner: Relaxation module
- Source of truth: relaxation source
- Write policy: source-first
- Examples: `Relaxation ver3/diagnostics/`
- Migration notes: organization policy must not claim full canonical readiness

## MT/
- Intended role: target normalized module alias in artifact contracts
- Allowed: alias namespace for artifact routing only (policy stage)
- Forbidden: implied physical rename in this phase
- Owner: MT module governance
- Source of truth: alias map from `MT ver2/` to `mt`
- Write policy: policy-only in this phase
- Examples: `results/mt/`
- Migration notes: no folder rename until code references are audited

## Root folder
- Intended role: repository index/minimal control layer
- Allowed: top-level module roots, shared governed layers, repo metadata/bootstrap
- Forbidden: new ad hoc module scripts, logs, output dumps
- Owner: repository governance
- Source of truth: root contract + governance policy
- Write policy: strongly restricted
- Examples: `README.md`, `CONTRIBUTING.md`, `.gitignore`, `setup_repo.m`
- Migration notes: phase-1 declutter only for explicit low-lineage reviewed candidates
