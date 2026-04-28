# Maintenance .gitignore Alignment Phase 2B (Proposal Only)

## Scope and constraints
- Read-only proposal; no `.gitignore` changes applied.
- No movement, deletion, rename, regeneration, or commit performed.
- Scope reviewed:
  - `.gitignore`
  - `reports/maintenance/README.md`
  - `tables/maintenance_README.md`
  - Phase 2 retention outputs
  - `reports/maintenance/agent_outputs/`
  - `reports/maintenance/logs/`
  - `reports/maintenance/status_pack_latest.md`

## Current .gitignore diagnosis
Current behavior is dominated by this sequence:
1. `reports/**` ignores all reports.
2. `!reports/maintenance/` reopens maintenance folder.
3. `!reports/maintenance/**` reopens everything under maintenance.

Effect:
- transient outputs under `reports/maintenance/logs/` and `reports/maintenance/agent_outputs/` are visible as untracked noise.
- rolling generated `reports/maintenance/status_pack_latest.md` is also visible.
- this conflicts with maintenance README guidance that logs/agent outputs are non-automatic-durable and require explicit retention decisions.

Tables behavior:
- `tables/**` plus broad wildcard guards (`tables/*status*`, `tables/*audit*`, etc.) can hide governance maintenance tables unless force-added.
- this increases risk of accidentally omitting intended durable maintenance tables.

## Why transient paths appear in git status
They appear because `!reports/maintenance/**` unignores the entire maintenance subtree, overriding the broad `reports/**` ignore.

## Proposed minimal rule set
Design goals:
- keep durable maintenance governance markdown trackable by default,
- suppress transient maintenance noise by default,
- keep durable maintenance governance tables trackable without broadening table noise.

Proposed strategy:
1. Replace broad maintenance subtree unignore with targeted unignore for top-level maintenance markdown.
2. Explicitly ignore transient maintenance zones:
   - `reports/maintenance/agent_outputs/**`
   - `reports/maintenance/logs/**`
   - `reports/maintenance/status_pack_latest.md`
3. Explicitly unignore `tables/maintenance_*.csv` to protect durable maintenance tables from wildcard over-ignore.

## Risks and controls
- **Risk:** accidentally hiding future durable artifacts placed inside `reports/maintenance/agent_outputs/` or `reports/maintenance/logs/`.
  - **Control:** those zones are documented as non-automatic-durable; promotion should use explicit copy/promotion into durable maintenance report/table paths.
- **Risk:** over-broad unignore under `reports/maintenance/` reintroducing transient noise.
  - **Control:** keep unignore narrow (`!reports/maintenance/*.md`) and avoid `!reports/maintenance/**`.
- **Risk:** maintenance table status/policy files still hidden by wildcard table rules.
  - **Control:** explicit `!tables/maintenance_*.csv` override late in `.gitignore`.

## Durable artifact protection
This proposal preserves trackability for:
- durable maintenance governance reports in `reports/maintenance/*.md` (policy/audit/review narratives),
- durable maintenance governance tables in `tables/maintenance_*.csv` (review/status/policy tables).

It does not propose deletion or cleanup of existing transient files; it only proposes future status-noise control.

## Exact patch block to apply later (do not apply now)
```diff
--- a/.gitignore
+++ b/.gitignore
@@
 reports/**
 !reports/
 !reports/README.md
 !reports/maintenance/
-!reports/maintenance/**
+!reports/maintenance/*.md
+reports/maintenance/agent_outputs/**
+reports/maintenance/logs/**
+reports/maintenance/status_pack_latest.md
@@
 tables/**
 !tables/
 !tables/README.md
+!tables/maintenance_*.csv
```

## Proposal verdict
- Transient noise rules proposed: **YES**
- Durable maintenance artifacts protected: **YES**
- Safe to apply patch now: **YES** (policy-aligned and minimal), subject to normal review/approval.
