# Maintenance Table Exposure Phase 2C Review (Read-Only)

## Diagnosis
The recent Phase 2B alignment added:
- `!tables/maintenance_*.csv`

That rule successfully protects durable maintenance governance tables, but it also unignores every maintenance-prefixed table, including large operational evidence tables that are not durable by default.

Why these appeared now:
- `.gitignore` still has broad ignore rules for `tables/**` and wildcard guards.
- the explicit unignore `!tables/maintenance_*.csv` is broad and currently re-exposes all `maintenance_*.csv` files.

## Table-by-table recommendation
- `tables/maintenance_artifact_atlas_locations.csv`
  - Recommendation: **force-add only when explicitly needed** (otherwise keep ignored/transient).
  - Rationale: very large raw atlas evidence; high input value, low durable signal density.

- `tables/maintenance_artifact_writer_patterns.csv`
  - Recommendation: **force-add only when explicitly needed** (otherwise keep ignored/transient).
  - Rationale: large raw writer scan evidence; referenced by committed atlas report but still an operational evidence dump.

- `tables/maintenance_findings_events.csv`
  - Recommendation: **keep ignored/transient**.
  - Rationale: event-log style operational table, low governance durability today.

- `tables/maintenance_repo_structure_inconsistencies.csv`
  - Recommendation: **commit as durable governance artifact**.
  - Rationale: concise curated inconsistency registry directly aligned with governance outcomes.

- `tables/maintenance_repo_structure_transition_backlog.csv`
  - Recommendation: **commit as durable governance artifact**.
  - Rationale: concise phased backlog table with governance planning value.

- `tables/maintenance_repo_target_structure_proposal.csv`
  - Recommendation: **commit as durable governance artifact**.
  - Rationale: curated target-structure proposal table, policy-facing.

- `tables/maintenance_root_folder_cleanup_blockers.csv`
  - Recommendation: **commit as durable governance artifact**.
  - Rationale: explicitly referenced by committed root declutter report.

- `tables/maintenance_root_folder_relocation_backlog.csv`
  - Recommendation: **commit as durable governance artifact**.
  - Rationale: explicitly referenced by committed root declutter report.

## Is `!tables/maintenance_*.csv` too broad?
Yes.  
It is effective for durable protection, but broad enough to expose raw/noisy maintenance evidence tables that the maintenance README classifies as non-durable by default unless explicitly curated.

## Proposed .gitignore adjustment (do not apply now)
Use a narrow subtractive guard while keeping current durable protection:

```diff
--- a/.gitignore
+++ b/.gitignore
@@
 !tables/maintenance_*.csv
+tables/maintenance_artifact_atlas_locations.csv
+tables/maintenance_artifact_writer_patterns.csv
+tables/maintenance_findings_events.csv
```

Why this is minimal:
- preserves durable maintenance table visibility generally,
- suppresses the three known high-noise operational tables,
- avoids broad new wildcard patterns that could accidentally hide future durable governance tables.

## Commit plan (proposal only)
No commit performed here.

Recommended durable-governance commit set:
- `tables/maintenance_repo_structure_inconsistencies.csv`
- `tables/maintenance_repo_structure_transition_backlog.csv`
- `tables/maintenance_repo_target_structure_proposal.csv`
- `tables/maintenance_root_folder_cleanup_blockers.csv`
- `tables/maintenance_root_folder_relocation_backlog.csv`

Keep ignored/transient by default (or force-add only when explicitly required by a report update):
- `tables/maintenance_artifact_atlas_locations.csv`
- `tables/maintenance_artifact_writer_patterns.csv`
- `tables/maintenance_findings_events.csv`
