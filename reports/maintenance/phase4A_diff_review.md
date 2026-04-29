# Maintenance Phase 4A — path-scoped manual diff review

**Mode:** read-only. Only `git diff -- "<path>"` plus file reads; no restore/stage/commit/MATLAB.  
**Source of truth:** `tables/maintenance_phase3_human_review_refinement.csv` rows with `phase3_decision = NEEDS_MANUAL_DIFF_REVIEW` (**29** paths).  
**Detailed table:** `tables/maintenance_phase4A_diff_review.csv`.

## Summary by risk level

| risk_level | Count |
|------------|------:|
| HIGH | 4 |
| MEDIUM | 25 |

## Summary by change classification

| change_classification | Count |
|------------------------|------:|
| HEADER_OR_GOVERNANCE_CHANGE | 25 |
| DOC_CHANGE | 3 |
| MIXED_OR_UNCLEAR | 1 |

## HIGH risk paths (explicit)

1. **`Switching/analysis/run_switching_canonical.m`** — Comment-only diff, but file is the **canonical producer**; namespace block documents mixed output classes (CANON_GEN vs EXPERIMENTAL_PTCDF vs DIAGNOSTIC_MODE). **Recommendation:** `KEEP_FOR_FUTURE_COMMIT` after human confirms column-map references match current contracts (no executable drift in diff).

2. **`Switching/analysis/switching_residual_decomposition_analysis.m`** — Comment-only on **legacy decomposition** entrypoint (`OLD_RESIDUAL_DECOMP`); governs how residual/phi outputs may be cited. **Recommendation:** `KEEP_FOR_FUTURE_COMMIT` (same rationale: provenance header, no body change in hunk).

3. **`docs/switching_governance_persistence_manifest.md`** — **Substantive** governance text: bullets now assert authoritative corrected-old tables exist and supersede earlier “none exist / build blocked” language. **Recommendation:** `REQUIRES_DEEP_REVIEW` against on-disk indexes and `reports/switching_stale_governance_supersession.md`.

4. **`.gitignore`** — Adds three `tables/maintenance_*.csv` ignore lines **after** `!tables/maintenance_*.csv`; risk of **re-ignoring** paths the negated glob had exposed. **Recommendation:** `REQUIRES_DEEP_REVIEW` for ignore precedence and maintenance visibility.

## Recommended action counts (29 paths)

| recommended_action | Count |
|--------------------|------:|
| KEEP_FOR_FUTURE_COMMIT | 27 |
| REQUIRES_DEEP_REVIEW | 2 |
| RESTORE_TO_HEAD | 0 |
| MOVE_TO_QUARANTINE | 0 |

## Paths recommended for restore

**None** from this review: no diff was classified as spurious noise or accidental-only; `.gitignore` and manifest need **intent verification**, not blind restore.

## Paths recommended for keep (summary)

All **25** `Switching/analysis/*.m` paths with comment-only (or comment-only plus minor comment-line edits) headers: see CSV column `recommended_action = KEEP_FOR_FUTURE_COMMIT`.  
Additionally **`reports/switching_gauge_atlas_preview.md`** and **`docs/decisions/switching_main_narrative_namespace_decision.md`** (untracked; reviewed via file read where `git diff` was empty).

## Paths recommended for quarantine

**None** among the 29 paths (quarantine/replay scripts are **outside** this NEEDS_MANUAL set in Phase 3).

## Critical path notes (outside the 29-path loop, read-only spot-check)

The following were **not** in the Phase 3 NEEDS_MANUAL list; headers were read for governance context only:

| Path | Role |
|------|------|
| `scripts/run_sw_corr_old_replay_auth.m` | `QUARANTINED_MISLEADING` / `NOT_AUTHORITATIVE` banner; forensic replay, not canonical producer. |
| `scripts/run_sw_old_inv_phi1_viz.m` | `EXPERIMENTAL_PTCDF_DIAGNOSTIC` + quarantine class; diagnostic / hazard viz, not authoritative corrected-old tables. |
| `scripts/run_switching_corrected_old_replay_inventory_and_phi1_visual_sanity.m` | `QUARANTINED_MISLEADING` inventory + visual sanity; diagnostic-only `cfg.runLabel`. |

**Old figure / stabilized scripts** (e.g. `run_switching_old_fig_forensic_and_canonical_replot.m`, stabilized gauge replays) remain Phase 3 **`MOVE_TO_QUARANTINE_LATER`** — not re-reviewed here.

## Systemic pattern

- **Repeated pattern:** A consistent **`% SWITCHING NAMESPACE / EVIDENCE WARNING`** block was prepended (or inserted) across the canonical analysis tree, plus `CURRENT_STATE_ENTRYPOINT: reports/switching_corrected_canonical_current_state.md` — **comment-only governance drift**, not algorithm edits in the observed hunks.
- **Secondary pattern:** Two scripts (`run_switching_canonical_observable_dictionary_audit.m`, `run_switching_mode_hierarchy_synthesis_audit.m`, `run_switching_phi2_replacement_audit.m`) also **soften** leading “Canonical …” phrasing in existing comments—still within documentation layer.
- **Isolation:** Executable MATLAB bodies in diffs reviewed are unchanged in hunks except documentation/comment layers; **exception** none for computation—**governance manifest** and **`.gitignore`** are the only items flagged for **deep review** because they change **policy or ignore semantics**, not just banners.

## Phase 4B gate

`SAFE_TO_PROCEED_PHASE4B = NO` in `tables/maintenance_phase4A_diff_review_status.csv` until **`.gitignore`** ignore-order intent and **`docs/switching_governance_persistence_manifest.md`** factual bullets are human-signed-off (path-specific follow-up, not broad commands).
