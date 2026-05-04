# SW-STATE-X — Canonical state audit runner semantic repair

**Date:** 2026-05-04  
**Scope:** `Switching/analysis/run_switching_canonical_state_audit.m` only (plus this audit record).  
**Mode:** Text edits in-repo; **MATLAB not run**; **not staged / not committed / not pushed**.

## Preflight

- `git diff --cached --name-only`: **empty** (safe to edit working tree only).

## Objectives (from SW-STATE-U)

1. Clarify that **`Aging/utils` on path** is **shared run infrastructure** (`createRunContext`) only — not Aging data or science, not Relaxation coupling.
2. Distinguish **live** behavior (e.g. `exist()` file probes in `buildCompletedTests`) from **static / editorial** table rows, especially **status verdicts**, so they are not mistaken for live gate values scraped from authoritative CSVs.

## Changes made

- **Header block:** Expanded to state Switching **governance** role, **no physics / inference**, **INFRA_ONLY** meaning of `Aging/utils`, and **verdict hygiene** (legacy key names; values are **STATIC_DECLARED** unless otherwise noted; live gates remain in source CSVs).
- **Line comment** on `addpath(..., 'Aging', 'utils')`: **`INFRA_ONLY`** one-liner.
- **Per-builder comments** at function entry:
  - `buildFamilyInventory` — **STATIC_EDITORIAL**; `missing_expected` uses `exist()` only for optional hints.
  - `buildClaimSafetyMatrix` — **STATIC_EDITORIAL** pointers.
  - `buildCompletedTests` — **LIVE_REPO_PROBE** via `exist()`.
  - `buildOpenTasks` — **STATIC_EDITORIAL / DECLARED_OPEN_WORK**.
  - `buildCrossModuleBlockers` — **STATIC_EDITORIAL** narrative.
  - `buildStatusVerdicts` — **STATIC_DECLARED**; schema keys unchanged; values not auto-read from gate CSVs.
  - `writeMarkdownReport` — **STATIC_EDITORIAL** prose + same status provenance as verdict table.

## Intentional non-changes (contract)

- **No** change to output **paths**, **filenames**, **table column names**, or **verdict_key** strings (stable schema for existing consumers).
- **No** change to numeric/string **payload** cells in tables (no scientific or policy text edits in emitted data).
- **No** new dependencies; **no** execution-path edits (comments only).

## Next step

Run MATLAB **once** in a controlled session to confirm the script still parses and outputs as before; then decide **track + commit** the runner when ready.

---

*End of report.*
