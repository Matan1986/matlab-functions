# Phase 4B — staging (no commit)

**Plan:** `tables/maintenance_phase4B_preflight_staging_plan.csv` (39 paths).  
**Method:** For each row, `git add -- "<path>"` from the `path` column (equivalent to the `git_add_command` column). **No** `-f`, **no** wildcards, **no** directory or `-A` adds.

## Pre-staging

- `git diff --cached --name-only` was **empty**.

## Post-staging

- **Staged path count:** 39  
- **Set equality:** Staged names **exactly** match the 39 `path` values in the preflight CSV (`Compare-Object` — no plan-only, no staged-only).
- **Force add:** **Not** required; all adds succeeded without `-f`.

## Policy checks

| Check | Result |
|--------|--------|
| Unplanned paths staged | **No** |
| Quarantine / MOVE paths (scripts from Phase 3 quarantine list) | **None** in plan or index |
| Relaxation / Aging / MT-only paths | **None** staged |
| Figure **binaries** (e.g. `.png`) | **None** staged (only `reports/switching_gauge_atlas_preview.md` markdown) |

## Notices

Git printed **LF will be replaced by CRLF** warnings for a few working-tree files (line-ending normalization). Staging still **succeeded**; not a force-add case.

## Verdict

See `tables/maintenance_phase4B_staging_status.csv`. **Commit not created** (per instruction).
