# F7B2 — Refresh F7B0 companion artifacts after visualization update

**Scope:** Aging planning artifacts only. **Source of truth:** committed `docs/aging/aging_old_analysis_canonical_reconstruction_plan.md` (sections 1–11, including §10 visualization).

## Files inspected

- `docs/aging/aging_old_analysis_canonical_reconstruction_plan.md` (read-only; no edits — no contradiction found)
- `reports/aging/aging_F7B0_old_analysis_canonical_reconstruction_plan.md`
- `tables/aging/aging_F7B0_reconstruction_execution_order.csv`
- `tables/aging/aging_F7B0_stop_conditions.csv`
- `tables/aging/aging_F7B0_status.csv`
- `tables/aging/aging_F7B0_old_analysis_reconstruction_scope.csv`
- `tables/aging/aging_F7B0_reconstruction_target_classes.csv`

## Files updated

| Path | Change |
|------|--------|
| `reports/aging/aging_F7B0_old_analysis_canonical_reconstruction_plan.md` | Rewritten: sections **1–11**, §10 visualization summary, PNG+FIG, diagnostic figures, no science-for-cosmetics, three visualization doc links |
| `tables/aging/aging_F7B0_reconstruction_execution_order.csv` | Added step **10** review-stage visualization checkpoint; renumbered model analysis to step **11** |
| `tables/aging/aging_F7B0_stop_conditions.csv` | Added **STOP_VIS_SHORTCUT** row |
| `tables/aging/aging_F7B0_status.csv` | Added visualization verdict rows through **F7B0_COMPANION_ARTIFACTS_REFRESHED_AFTER_VIS_UPDATE** |
| `tables/aging/aging_F7B2_refresh_status.csv` | **Created** |
| `reports/aging/aging_F7B2_refresh_F7B0_companion_artifacts.md` | **Created** (this file) |

## Files not changed

- `docs/aging/aging_old_analysis_canonical_reconstruction_plan.md` — unchanged (committed baseline).
- `tables/aging/aging_F7B0_old_analysis_reconstruction_scope.csv` — unchanged (still aligned with committed plan; no contradiction).
- `tables/aging/aging_F7B0_reconstruction_target_classes.csv` — unchanged (same).

## Staleness

- **F7B0 summary report:** **No longer stale** relative to committed plan (section count, visualization rules, PNG/FIG, evidence role).
- **Execution order:** Includes explicit **visual review** checkpoint (step 10) before gated model analysis (step 11); figures are **not** implied canonical.
- **Stop conditions:** Include **STOP_VIS_SHORTCUT** covering missing PNG+FIG, figure-as-canonical proof, and cosmetic science changes.
- **Status CSV:** Includes PNG/FIG and diagnostic-until-promoted verdicts.

## Confirmation

- No MATLAB code, writers, model analysis, tau/R reconstruction runs, or scientific output regeneration.
- No edits to Switching, Relaxation, or MT.
- **No** `git add`, commit, or push in F7B2.

## Recommended `git add -f` (later, if approved)

Artifacts live under ignored `tables/**` and `reports/**`:

```text
git add -f -- reports/aging/aging_F7B0_old_analysis_canonical_reconstruction_plan.md
git add -f -- tables/aging/aging_F7B0_reconstruction_execution_order.csv
git add -f -- tables/aging/aging_F7B0_stop_conditions.csv
git add -f -- tables/aging/aging_F7B0_status.csv
git add -f -- tables/aging/aging_F7B2_refresh_status.csv
git add -f -- reports/aging/aging_F7B2_refresh_F7B0_companion_artifacts.md
```

Optional: include unchanged scope/target CSVs in the same commit batch if archiving full F7B0 companion set.
