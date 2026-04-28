# Root Declutter Phase 1 Review (No Movement)

## Scope and constraints
- Scope: repository root files only (`C:\Dev\matlab-functions`), review gate only.
- No movement, deletion, rename, execution, or commit was performed.
- Governing references applied:
  - `docs/artifact_organization_policy.md`
  - `docs/artifact_directory_contract.md`
  - `docs/root_artifact_contract.md`
  - `reports/maintenance/root_folder_declutter_audit.md`
  - `tables/maintenance_artifact_migration_backlog.csv`
  - `tables/maintenance_artifact_cleanup_blockers.csv`

## Root composition summary
Heuristic root file composition (current first-level files):
- Total root files: 141
- `script`: 80
- `log/probe/debug/status text`: 30
- `report` (`.md`): 14
- `artifact` (`.csv`, `.mat`, etc.): 13
- `other`: 4

Interpretation:
- Root is still script-heavy.
- Most non-script files are maintenance outputs, diagnostics, or generated runtime byproducts.
- This is consistent with prior root clutter findings and existing cleanup blockers.

## Count by category (reviewed candidate set)
Reviewed in `tables/maintenance_root_declutter_phase1_review.csv`:
- `log/probe/debug/status`: 25
- `script`: 1
- `artifact`: 1

Risk outcomes in reviewed set:
- `SAFE`: 0
- `CONDITIONAL`: 8
- `BLOCKED`: 19

## SAFE candidate result
No truly safe root-level move candidates were approved in this gate.

Reasons:
1. Many low-lineage logs/text are explicitly referenced in maintenance reports, scripts, or ignore policy.
2. Some temp/debug outputs are currently unreferenced, but still lack explicit ownership and lineage contract, so they remain only conditional.
3. Root MATLAB scripts are policy-blocked regardless of exact-string reference results.
4. Scientific artifacts remain blocked by lineage-protection policy.

## Why most files are blocked
- Root MATLAB scripts: blocked by contract and migration blockers (`BLK-A01`) until invocation/caller ownership is resolved.
- Scientific artifacts: blocked by scientific artifact protection and unresolved dependency/lineage guarantees.
- Referenced logs/status text: blocked when any dependency chain exists (reports, scripts, tools, or governance docs).
- Unclear lineage: blocked or conditional only; no forced cleanup is allowed in this phase.

## MATLAB invocation risk (explicit)
`docs/root_artifact_contract.md` states that root `.m` files may be invoked by bare stem name or path-dependent workflows.  
Therefore:
- A no-reference scan is not proof of safety for `.m` files.
- Root script relocation is blocked in Phase 1 unless invocation ownership and call paths are fully mapped and approved.
- This review treated MATLAB movement risk as a hard blocker.

## Why logs/text may be safer in principle (but not yet approved here)
Low-lineage logs and probe text can be lower-risk than scripts because they are not executable entrypoints and usually do not participate in MATLAB name resolution.  
However, they are only safe when all are true:
- clear generated lineage,
- no direct or indirect references,
- declared maintenance ownership,
- approved governed destination path.

In this review, those conditions were not met strongly enough to approve any `SAFE` root move candidate.

## Gate conclusion
- `SAFE_ROOT_MOVE_CANDIDATES_APPROVED=NO`
- This remains a review gate only; no cleanup was performed.
