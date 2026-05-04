# SW-LEFTOVER-AC — Review `scripts/run_sw_old_inv_phi1_viz.m`

**Date:** 2026-05-04  
**Mode:** Static text review only — script **not** executed; no git writes.

## Preflight

- `git diff --cached --name-only`: **empty** at audit time (safe to proceed).
- `scripts/run_sw_old_inv_phi1_viz.m`: **untracked** (`??`).

## Purpose

MATLAB utility that selects the **latest** `results/switching/runs/run_*_switching_canonical` containing `switching_canonical_S_long.csv` + `switching_canonical_observables.csv`, builds **PT/CDF diagnostic backbone / residual / rank‑1 mode** visuals on **`S_model_pt_percent`** vs **`S_percent`**, runs **SVD on residual stacks**, and emits:

- inventory + visual sanity **CSV** tables,
- a **markdown report** stating **QUARANTINED / EXPERIMENTAL_PTCDF_DIAGNOSTIC** posture,
- multiple **PNG maps** under `figures/switching/canonical/`.

Header explicitly forbids treating outputs as **CORRECTED_CANONICAL_OLD_ANALYSIS** manuscript backbone and cites **`tables/switching_misleading_or_dangerous_artifacts.csv`** namespace hazard.

## Inputs (representative)

| Kind | Paths / behavior |
|------|------------------|
| **Run discovery** | Scans `results/switching/runs/run_*_switching_canonical/**/tables/` for paired `switching_canonical_S_long.csv` and `switching_canonical_observables.csv`; picks **latest by file date**. |
| **Tables** | Optional `tables/switching_P0_effective_observables_values.csv`; optional `tables/switching_canonical_primary_collapse_colored_values.csv`; companion `switching_canonical_phi1.csv` beside selected run. |
| **Docs** | Reads `docs/switching_analysis_map.md` only as survey reference (loaded into report text). |
| **Infrastructure** | `addpath` **Aging/utils** for `createRunContext` (same pattern as other Switching runners). |

**Hardcoded `repoRoot`:** `C:/Dev/matlab-functions` with fallback `pwd` — **not portable** across clones/machines.

## Outputs

| Kind | Paths |
|------|--------|
| **Figures** | Nine PNG paths under `figures/switching/canonical/` named `switching_diagnostic_ptcdf_corrected_old_*.png` (raw map, backbone, residuals, Phi1, kappa1, mode‑1, cuts, etc.). |
| **Tables** | `tables/switching_diagnostic_ptcdf_corrected_old_replay_inventory.csv`, `tables/switching_diagnostic_ptcdf_corrected_old_visual_sanity_status.csv`. |
| **Report** | `reports/switching_diagnostic_ptcdf_quarantine_replay_inventory_and_phi1_visual_sanity.md`. |
| **Run sidecars** | `createRunContext('switching',...)`, `run_dir_pointer.txt`, execution probes, `execution_status.csv` under run dir; repo-root probe files. |

## Governance / terminology

- Declares **`EXPERIMENTAL_PTCDF_DIAGNOSTIC`**, **QUARANTINED_MISLEADING**, **`NOT_MAIN_MANUSCRIPT_EVIDENCE`**.
- Uses **Phi1**, **kappa1**, **Phi2** language and **`X_eff`** only as **inventory row label** text — not cross-module data loads.
- Overlaps conceptually with **`scripts/run_switching_corrected_old_replay_inventory_and_phi1_visual_sanity.m`** (same `cfg.runLabel` string); risk of **duplicate entrypoints** if both are kept without consolidation.

## References from tracked / maintenance artifacts (text search)

Hits in **`reports/maintenance/`** and **`tables/maintenance*.csv`** tie this path to **ARCHIVE_OR_QUARANTINE_LATER** / **MOVE_TO_QUARANTINE_LATER** policy — **no** hits under **`docs/`** or **`Switching/`** subtree in search performed.

## Primary classification

**`QUARANTINE_CANDIDATE`** — matches script header, misleading-artifact framing, and maintenance retention tables.

## Flags

| Flag | Value | Note |
|------|-------|------|
| SAFE_TO_RUN_NOW | **NO** | Requires local canonical run outputs + hardcoded path; not validated here. |
| SAFE_TO_STAGE_NOW | **NO** | Untracked; align with quarantine registry / duplicate naming before track. |
| SAFE_TO_DELETE_NOW | **NO** | Referenced in governance retention CSVs; needs owner decision. |
| CANONICAL_EVIDENCE_ALLOWED | **NO** | Script explicitly denies manuscript authority. |
| NEEDS_OWNER_DECISION | **YES** | Consolidate vs `run_switching_corrected_old_replay_inventory_and_phi1_visual_sanity.m`, fix `repoRoot`, update quarantine index if staged. |

---

*End of report.*
