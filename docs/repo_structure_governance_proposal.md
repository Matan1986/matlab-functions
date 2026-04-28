# Repository Structure Governance Proposal

## Purpose
This document proposes a controlled future directory architecture for the repository. It is intentionally governance-first: it defines where new files should go, what each layer means, and which migrations should wait for lineage checks.

## Design Principles
- Preserve scientific lineage before improving aesthetics.
- Keep active module source trees source-first.
- Treat `results/<module>/runs/<run_id>/` as the run lineage layer.
- Treat `tables/`, `reports/`, and `figures/` as promoted durable outputs.
- Keep maintenance outputs in governed maintenance destinations.
- Freeze legacy and quarantine areas rather than reusing them.
- Avoid new root-level clutter.

## Target Directory Layers
### Root
- Keep only repository metadata, module roots, and governed shared folders.
- Do not add new ad hoc logs, csvs, or maintenance markdown at the root.

### Module Source Layer
- Active module trees remain the source-of-truth for live scientific code.
- Module-local docs are acceptable only when tightly coupled to the source internals.
- Generated artifacts should not accumulate silently in module folders.

### Shared Execution and Tooling Layer
- `tools/` is for reusable infrastructure.
- `scripts/` is for stable human-invoked orchestrators only.
- If a helper is not reusable, it should not drift into `tools/`.

### Run Output Layer
- Standard pattern: `results/<module>/runs/<run_id>/`.
- Required semantics:
  - immutable manifest
  - immutable entrypoint snapshot or explicit reference
  - runtime logs and status
  - raw run outputs
  - optional ephemeral figures or intermediate tables
- This layer preserves lineage and should remain module-scoped.

### Durable Artifact Layer
- `tables/<module>/`: durable canonical CSV and structured tables.
- `reports/<module>/`: durable markdown narratives.
- `figures/<module>/`: durable promoted figures.
- Promotion from a run folder into a durable layer should be explicit and documented.

### Maintenance Layer
- `reports/maintenance/`: durable maintenance narratives.
- `tables/maintenance_*.csv`: durable maintenance tables.
- `results/maintenance/runs/<run_id>/`: transient maintenance execution evidence.

### Legacy and Quarantine Layer
- `results_old/`, `tables_old/`, `archive/`, `_legacy/`, `Aging old/`, and `tmp_root_cleanup_quarantine/` should be treated as write-closed legacy namespaces.
- No new outputs should be routed there.

## Immediate Governance Rules
1. No new root-level run logs, csvs, or maintenance markdown.
2. No new writes to `results_old/`, `tables_old/`, `archive/`, `_legacy/`, `Aging old/`, or `tmp_root_cleanup_quarantine/`.
3. All new maintenance audits write to `reports/maintenance/` and `tables/maintenance_*.csv`.
4. All new run executions write to `results/<module>/runs/<run_id>/`.
5. Every module must use a documented alias for its artifact namespace if the source folder name differs.
6. Any `.m` file inside an artifact folder must be documented as either a live entrypoint or an immutable lineage snapshot.

## Transition Strategy
### Phase 0
- Publish policy, alias table, and write-freeze rules.

### Phase 1
- Define the run container contract and promotion rules.

### Phase 2
- Redirect all new writes to governed destinations without moving history.

### Phase 3
- Resolve mixed-role boundaries for future writes, then selectively migrate low-risk files.

### Phase 4
- Inventory root-level files and reassign them deliberately.

### Phase 5
- Consider physical renames or vendor isolation only after reference and lineage checks.

## Explicit Non-Goals for the Transition
- No bulk movement of historical scientific artifacts.
- No deletion of scientific outputs.
- No collapsing of distinct `Switching` canonical families.
- No source-folder renames before path-reference audits.
- No scientific refactoring hidden inside directory cleanup.
