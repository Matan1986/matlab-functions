# Switching TASK_001 — Corrected-old finite-grid / interpolation closure audit

## Scope and constraints

- **Switching only.** No Relaxation or Aging cross-analysis.
- **Audit only:** tables and this report; no new physical reconstruction, no builder rerun, no figure regeneration, no edits to authoritative builder outputs.
- **Evidence:** authoritative corrected-old tables and status; clean canonical `switching_canonical_source_view.csv`; builder implementation read for definitions only (`run_switching_corrected_old_authoritative_builder.m`). Mixed canonical diagnostics and quarantined corrected-old artifacts were **not** used as evidence.

## Executive summary

The reported `fraction_finite_aligned_residual ≈ 0.47273`, `n_current_points = 6`, and exclusion of **50 mA** are **consistent with the implemented geometry of the aligned residual matrix**, not indicators of a silent numerical bug in the builder.

- **Low finite fraction:** A **common** `x_grid` of 220 points spans the **union** of all per-temperature aligned abscissas `x = (I - I_peak)/W`, while each row’s residual is interpolated with `interp1(..., 'linear', NaN)`, which **forbids extrapolation** outside that row’s convex hull in `x`. Many grid points lie outside a given row’s hull → NaN → global finite fraction near **0.47** (computed as **1456 / 3080**).
- **`n_current_points = 6`:** After dropping any current column that is not finite for **all** 14 temperatures, **50 mA** is removed because the clean source view has **non-finite `S_percent` at 50 mA for T = 28 K and 30 K**. Seven unique currents remain in the filtered window before that mask; six survive.
- **Phi1 / kappa1:** The SVD uses only columns where **all** temperatures are finite (`validCols`); there are **53** such columns (≫ 2 required). Leading-mode explained variance **0.90334** and RMSE improvement indicate a **stable** rank-1 extraction under the intended mask, not a compromised fit masked by NaNs.

Verdict: **not a downstream reconstruction blocker** on its own; treat the low global finite fraction as a **support / visualization statistic**, not as backbone failure on measured currents.

## Artifact index (this audit)

| Artifact | Role |
|----------|------|
| `tables/switching_corrected_old_finite_grid_interpolation_status.csv` | Required gate-style verdicts |
| `tables/switching_corrected_old_finite_grid_support_by_T.csv` | Per-temperature support on source and on common x_grid |
| `tables/switching_corrected_old_finite_grid_current_bin_audit.csv` | Per-current-bin inclusion and 50 mA rationale |
| `tables/switching_corrected_old_finite_grid_downstream_risk.csv` | Branch-level risk from current / aligned-grid masking |
| `tables/switching_corrected_old_finite_grid_x_support_audit.csv` | Optional joint hull / column counts |
| `tables/switching_corrected_old_finite_grid_recommended_actions.csv` | Optional narrow follow-ups (documentation-first) |

## Required questions (concise answers)

1. **Why is `fraction_finite_aligned_residual` ~0.47273?**  
   It is the fraction of `(T, x_grid)` cells where the row-wise aligned residual is finite. With `nT=14`, `nX=220`, and **NaN outside each row’s interpolated x interval**, the count of finite cells is **1456**, i.e. **1456/3080 ≈ 0.47273**. Warm temperatures widen the global `x_grid` extent; cooler rows cover a smaller fraction of that grid → many NaNs off hull.

2. **Why `n_current_points = 6`?**  
   Unique currents in the clean source view (for `T ≤ 30` and expected temperature list) include **15, 20, 25, 30, 35, 45, 50** mA (no 40 mA row). The builder keeps currents with finite `S_percent` at **every** temperature; **50 mA** fails → **six** currents.

3. **50 mA exclusion**  
   **Source-data / source-view limitation:** `S_percent` is **NaN** at **50 mA** for **T = 28 K** and **T = 30 K** in `switching_canonical_source_view.csv` (additional NaNs appear at higher T outside the builder window). The builder’s `currentFiniteMask = all(isfinite(SmapAll), 1)` removes that column.

4. **Root cause taxonomy**  
   Dominant: **common x-grid choice** + **alignment** `x = (I - I_peak)/W` + **linear interpolation with NaN outside support** + **union of per-T x ranges**. Contributing: **50 mA** removed due to **missing/non-finite** source values at high T. **Not** a PT_matrix support mismatch for the six retained currents (PT is interpolated onto `currents` with area normalization). **Not** classified as a builder bug given code–metric agreement.

5. **Adequate support per T for SVD?**  
   **Yes** for the **stated** procedure: each T has **six** finite currents, residual and backbone are finite on that grid, and **≥53** joint columns exist for SVD. Per-row **global-grid** finite fraction is **marginal** for cooler T (table) but that reflects **hull vs union grid**, not missing temperatures.

6. **Disproportionate finite-mask loss?**  
   **Cooler T** occupy a smaller fraction of the **global** `x_grid` because **warmer T** (especially **28–30 K**) extend `maxX` and **18 K** sets `minX`. Warm rows therefore show higher `fraction_finite_aligned_x_points` on the **same** 220-bin axis.

7. **Phi1 / kappa1 stability**  
   **Safe under the implemented mask:** SVD on `A = alignedResidual(:, validCols)` is well-posed; explained variance and RMSE metrics in `switching_corrected_old_authoritative_quality_metrics.csv` support stability. **Follow-up:** rank-2+ and claim-boundary work (`TASK_007`) should remain cautious about **sparse x sampling** (six points), not emergency-repair this grid statistic.

8. **Downstream branches**  
   **Not blocked** solely by this finite-grid behavior for **TASK_002** (parity bridge), **asymmetry/LR**, **T22** (with usual sparse-grid caution), or **gauge/atlas** (documentation of support). **Publication figures** remain under the program’s **PARTIAL** gate for **provenance and task closure**, not because `fraction_finite_aligned_residual` forces a new veto.

9. **Narrow repair**  
   **No mandatory code or physics repair** from this audit. **Recommended:** report-only clarification (this document + status table) and optional future **builder diagnostic export** for per-T hull metrics. **Optional upstream** review of NaN `S_percent` at 50 mA for 28–30 K if tail currents become scientifically central.

## Code anchors (read-only)

Aligned residual construction and finite fraction (global grid, NaN outside hull):

```367:400:c:\Dev\matlab-functions\Switching\analysis\run_switching_corrected_old_authoritative_builder.m
    minX = min(xRows(:));
    maxX = max(xRows(:));
    if ~(isfinite(minX) && isfinite(maxX) && maxX > minX)
        error('builder:InvalidXRange', 'Aligned x range is invalid.');
    end
    nX = 220;
    xGrid = linspace(minX, maxX, nX);

    alignedResidual = nan(nT, nX);
    for iT = 1:nT
        xv = xRows(iT, :);
        rv = residual(iT, :);
        ...
        alignedResidual(iT, :) = interp1(xu, rvU, xGrid, 'linear', NaN);
    end

    finiteFrac = sum(isfinite(alignedResidual), 'all') / numel(alignedResidual);
    validCols = all(isfinite(alignedResidual), 1);
    if sum(validCols) < 2
        error('builder:InsufficientFiniteCols', 'Insufficient fully finite aligned columns for SVD.');
    end

    A = alignedResidual(:, validCols);
```

Current-column gate and exclusion note:

```251:261:c:\Dev\matlab-functions\Switching\analysis\run_switching_corrected_old_authoritative_builder.m
    currentFiniteMask = all(isfinite(SmapAll), 1);
    if sum(currentFiniteMask) < 2
        error('builder:InsufficientFiniteCurrents', 'Not enough fully finite current bins across T=4:2:30.');
    end
    excludedCurrents = currentsAll(~currentFiniteMask);
    if ~isempty(excludedCurrents)
        notes(end+1,1) = "Excluded current bins with non-finite S_percent in window: " + strjoin(string(excludedCurrents), ','); %#ok<AGROW>
    end
    currents = currentsAll(currentFiniteMask);
```

## Relation to reconstruction program

- **TASK_001** in `tables/switching_missing_reconstruction_tasks.csv` is satisfied by this closure: finite support and interpolation behavior are explained and tabulated without changing physics.
- **TASK_002** dependency: safe to schedule **after** this audit from a finite-grid perspective (subject to existing program gates unchanged).

## Program status keys touched conceptually

No edits were made to `switching_corrected_canonical_reconstruction_program_status.csv` or authoritative builder outputs per task constraints.

---

*Audit completed as documentation-only Switching work aligned with `reports/switching_corrected_canonical_reconstruction_program.md` TASK_001 intent.*
