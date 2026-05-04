# SW-LEFTOVER-R — Untracked / dirty Switching-related path audit

**Date:** 2026-05-04  
**Mode:** Audit-only (no file edits, no `git add`/`commit`/`push`, no MATLAB/Python/Node).  
**Git preamble:** `git diff --cached --name-only` was **empty** at audit time (safe to proceed).

## Scope (explicit)

Included paths matching:

- `Switching/**`
- Root `run_switching_*.m`
- `scripts/run_switching_*.{m,ps1}`
- `scripts/run_sw_*.{m,...}`
- `scripts/run_cross_module_switching_relaxation_*`
- `scripts/run_CM_SW_RLX_AX_*` (Switching–Relaxation AX audit bridge; not Relaxation-prefixed)
- `docs/cross_module_switching_relaxation_*.md`
- `reports/maintenance/phase5C_switching_leftover_review.md`
- `tables/maintenance_phase5C_switching_*.csv`

**Excluded from inspection** (per request): Relaxation-prefixed trees, Aging, generic maintenance, `reports/maintenance/governor_summary_latest.md`, `tables/maintenance_findings_latest.csv`, CV07 paths, `figures/switching/` (Phase4B QA figures were restored and are **not** dirty).

## Anchor context (committed work)

- Switching reader hub: present on `main` (e.g. `ffe6b4b` lineage).
- Phase4B figure hygiene (K audit) and N2 canonical paper export interaction audits: committed per user context.
- Restored `figures/switching/phase4B_*` QA assets: **no commit required** for restore; working tree shows those paths clean relative to deletion.

## Inventory summary

| Metric | Value |
|--------|------:|
| Switching-scoped paths inventoried | **37** |
| All untracked (`??`) | **37** |
| Modified (`M`) in scope | **0** |

**Classification counts (primary label per path):**

| Classification | Count |
|----------------|------:|
| CURRENT_SWITCHING_WORK_CANDIDATE | 14 |
| SWITCHING_MAINTENANCE_EVIDENCE | 3 |
| CROSS_MODULE_SWITCHING_RELAXATION_CANDIDATE | 17 |
| STALE_OR_DEBUG_CANDIDATE | 2 |
| GENERATED_OUTPUT_CANDIDATE | 0 |
| NEEDS_SEPARATE_REVIEW | 1 |
| EXCLUDE_UNRELATED | 0 |

`NEEDS_SEPARATE_REVIEW` is applied to **`scripts/run_sw_old_inv_phi1_viz.m`** (legacy viz; supersession unclear from filename alone).

*Note: Several paths could wear a second tag (e.g. cross-module **and** paper-figure adjacent); the CSV uses one primary classification for sorting.*

## Connection to reader hub / K (Phase4B) / N2 (canonical paper figures)

| Topic | Relationship |
|-------|----------------|
| **Reader hub** | None of these paths *are* the hub; they are **adjacent** runners, audits, or draft docs. The two `Switching/**` runners emit **governance tables/reports** under `tables/switching/` and `reports/switching/` when executed — complementary to the hub, not a replacement. |
| **K audit (Phase4B QA figures)** | Indirect only: some `scripts/run_switching_*` names reference **X-panel orientation / baseline style** — same *theme* as panel QA, but these files were **not** part of the committed Phase4B hygiene narrative unless separately promoted. |
| **N2 / canonical paper exports (`3295c26`)** | **`scripts/tmp_run_switching_canonical_paper_figures.m`** is explicitly a **canonical paper** replay harness (hardcoded paths, `tmp_` prefix) → treat as **high-touch / separate review**, not automatic staging. **`run_switching_fixed_T_current_cuts_canonical_replay.m`** writes under `figures/switching/canonical/` — paper-adjacent **only if** you intend those outputs for the manuscript; otherwise a governed replay tool. |
| **Cross-module AX / CM-SW-RLX** | **`run_CM_SW_RLX_AX_*`** and **`run_cross_module_switching_relaxation_*`** tie Switching tables to Relaxation tables — **by design outside pure Switching module boundaries**; coordinate with Relaxation ownership before commit. |

## Recommended handling policy (conservative)

- **Default:** `KEEP_UNTRACKED_FOR_NOW` + `NO_STAGE_NOW` until an owner groups commits by theme (Switching-only vs cross-module).
- **Maintenance evidence (`phase5C_*`):** `MOVE_TO_MAINTENANCE_REVIEW` / optional future commit with maintenance bundle — **not** urgent Switching science.
- **`tmp_run_switching_canonical_paper_figures.m`:** `REVIEW_FOR_COMMIT_LATER` or `ARCHIVE_OR_DELETE_LATER_WITH_EXPLICIT_APPROVAL` after deciding whether `tmp_` scripts belong in-repo long term (do **not** delete in this audit).
- **Cross-module scripts/docs:** `REVIEW_FOR_COMMIT_LATER` with explicit Relaxation + naming-contract checklist.

## Safe staging posture

**Nothing in this inventory is endorsed for immediate staging** without case-by-case review. Prefer **`SAFE_TO_STAGE_ANYTHING_NOW = NO`**.

## Paths to exclude from a *pure* Switching chat

- All **`run_CM_SW_RLX_AX_*`** and **`run_cross_module_switching_relaxation_*`** (and **`docs/cross_module_switching_relaxation_*.md`**) — require **cross-module** or **Relaxation** context.
- **`Switching/diagnostics/run_switching_cdf_backbone_repair_aggressiveness_audit.m`** if the discussion excludes “corrected canonical old” CDF repair internals.

## Stale / debug candidates (filename / header signals only)

1. **`scripts/tmp_run_switching_canonical_paper_figures.m`** — `tmp_` prefix; hardcoded absolute `repoRoot`-style paths in header; canonical paper output directory.
2. **`scripts/run_switching_oldX_functional_replay_audit.ps1`** — “old” replay lineage; likely one-off or forensic (still potentially valuable — **no deletion decision**).

## Machine-readable tables

See:

- `tables/switching_leftover_R_path_inventory.csv`
- `tables/switching_leftover_R_classification.csv`
- `tables/switching_leftover_R_status.csv`

## Next step

Pick **one** commit slice (e.g. only `Switching/analysis/run_switching_canonical_state_audit.m` + generated outputs policy), or schedule a **cross-module** review session for `CM_SW_RLX` / `run_cross_module_switching_relaxation_*` before any staging.

---

*End of report.*
