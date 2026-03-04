# Review of `Relaxation ver3` MATLAB analysis pipeline

This document summarizes how the current code works and proposes **targeted** improvements without rewriting the project.

## 1) Current pipeline (as implemented)

1. `main_relexation.m` sets global toggles/thresholds, resolves folder mode (TRM/IRM), loads file names, imports data, optionally converts units to `\mu_B/Co`, plots raw curves, fits each relaxation, and shows summary plots/tables.
2. `getFileList_relaxation.m` scans `*.dat`, parses nominal `T`, nominal field, TRM/IRM type, and (optionally) mass from filename.
3. `importFiles_relaxation.m` scans each file header for `SAMPLE_MASS`, reads the full table, finds relevant columns by fuzzy name matching, normalizes time, and optionally normalizes moment by mass.
4. `pickRelaxWindow.m` chooses the fit interval primarily where `|H| < Hthresh` (smoothed field), with fallback to a derivative-based window if that fails.
5. `fitAllRelaxations.m` applies windowing, optional extra trimming, no-relaxation detection (`deltaM` / mean slope thresholds), then calls `fitStretchedExp.m` and stores scalarized fit outputs into a table.
6. `fitStretchedExp.m` fits:
   \[
   M(t)=M_{\infty}+\Delta M\exp\left(-\left(\frac{t}{\tau}\right)^\beta\right)
   \]
   on normalized time via `lsqcurvefit`, with optional early-time weighting and optional anchoring.

## 2) Most important weaknesses identified

### A) Data/metadata flow fragility

- `fitAllRelaxations.m` attempts to read `fileList` using `evalin('base',...)` to get temperature from filename. This makes behavior depend on base-workspace state and breaks function purity/reproducibility.
- `getFileList_relaxation.m` sorts by parsed temperature, but files with missing `T` (`NaN`) can reorder unpredictably relative to acquisition order.
- `getFileList_relaxation.m` only captures one field pattern (`(?<=FC)...T`), which is likely to miss alternative filename conventions.

### B) Windowing and fit-range assumptions

- `pickRelaxWindow.m` smooths field with fixed window length (`11`) regardless of sampling interval; this can blur short field transitions in sparse data and be too weak in dense data.
- Derivative fallback uses a fixed 20% tail (`t_end = t_start + 0.2*span`), which may be too short or too long depending on curve time constant.
- In `fitAllRelaxations.m`, the post-window trim is percentage-based over selected window but has no quality guard (e.g., minimum decades in time, minimum dynamic range retained).

### C) Fitting robustness and parameter identifiability

- `fitStretchedExp.m` uses a single initial guess for `tau_n`/`beta`; this can converge to local minima in flat/noisy curves.
- Bounds allow `beta` up to 1.3. This is mathematically valid but physically unusual for many glassy relaxation models; when `beta>1`, interpretation should be explicit.
- Weighted fit (`timeWeight`) can overemphasize early points without accounting for heteroscedastic noise estimates.
- R² is reported, but no residual diagnostics (e.g., weighted RMSE, autocorrelation) and no fit status/exit flag are propagated to output table.

### D) Numerical/analysis edge cases

- No-relaxation logic sets `R2=1`, `tau=Inf`, `n=1` by construction. This can bias downstream “good fit” filtering and plots.
- In overlay plotting, model uses `t_start/t_end` and fit parameters but does not expose confidence intervals, so visual agreement may hide parameter uncertainty.

### E) Code structure / duplication

- TRM/IRM title/legend/color logic is duplicated in `Plots_relaxation.m` and `overlayRelaxationFits.m`.
- `getScalar.m` and `scalarOrNaN.m` overlap conceptually but use inconsistent reduction rules (`first element` vs `mean`).

---

## 3) Targeted improvements (scientific + code)

## 3.1 Make metadata flow explicit (remove base-workspace dependency)

### Why
Improves reproducibility, testability, and prevents hidden temperature parsing failures.

### Suggested interface change (targeted)

```matlab
% fitAllRelaxations.m
function allFits = fitAllRelaxations(Time_table, Moment_table, Temp_table, Field_table, ...
    debug, Hthresh, fitParams, fitWindow_extraStart_percent, fitWindow_extraEnd_percent, ...
    absThreshold, slopeThreshold, fileList)

if nargin < 12
    fileList = {};
end

% ... inside loop:
Tnom = NaN;
if ~isempty(fileList) && i <= numel(fileList)
    Tmatch = regexp(string(fileList{i}), '([0-9]+\.?[0-9]*)\s*[Kk]', 'tokens', 'once');
    if ~isempty(Tmatch)
        Tnom = str2double(Tmatch{1});
    end
end
if isnan(Tnom) && i <= numel(Temp_table) && ~isempty(Temp_table{i})
    Tnom = mean(Temp_table{i}, 'omitnan');
end
```

And in `main_relexation.m`:

```matlab
allFits = fitAllRelaxations(Time_table, Moment_table, Temp_table, Field_table, ...
    debugMode, Hthresh_align, fitParams, fitWindow_extraStart_percent, ...
    fitWindow_extraEnd_percent, absThreshold, slopeThreshold, fileList);
```

## 3.2 Add multi-start fitting in stretched exponential

### Why
Reduces local-minimum sensitivity; especially important when `tau` and `beta` are strongly correlated.

### Suggested change (drop-in pattern)

```matlab
% fitStretchedExp.m (replace single-start section)
starts = [
    0.20, 0.45;
    0.35, 0.60;
    0.60, 0.85
];

best = struct('x',[],'resnorm',Inf,'exitflag',-1);
for s = 1:size(starts,1)
    x0 = [Minf0, dM0, starts(s,1), starts(s,2)];
    try
        [xTry, resnorm, ~, exitflag] = lsqcurvefit(model, x0, tn, ydata, lb, ub, opts);
        if isfinite(resnorm) && (resnorm < best.resnorm)
            best.x = xTry;
            best.resnorm = resnorm;
            best.exitflag = exitflag;
        end
    catch
    end
end

if isempty(best.x)
    pars = emptyPars(); R2 = NaN; stats = struct('exitflag',-999);
    return;
end
x = best.x;
```

## 3.3 Add fit quality flags + uncertainty estimates

### Why
R² alone is insufficient; parameter uncertainty and fit status are essential for scientific interpretation.

### Suggested additions
- Add columns in `allFits`: `fit_ok`, `fit_status`, `RMSE`, `Npts`, `CI_tau`, `CI_n` (if available).
- Use Jacobian from `lsqcurvefit` with `nlparci` (when Statistics Toolbox is available), else set CI to `NaN` and keep status text.

Minimal pattern in `fitStretchedExp.m`:

```matlab
[x, resnorm, residual, exitflag, output, ~, J] = lsqcurvefit(...);
RMSE = sqrt(mean(residual.^2,'omitnan'));
try
    ci = nlparci(x, residual, 'jacobian', J);
catch
    ci = NaN(numel(x),2);
end
stats = struct('exitflag',exitflag,'output',output,'RMSE',RMSE,'ci',ci);
```

## 3.4 Make no-relaxation handling statistically honest

### Why
Setting `R2=1` for no-relaxation cases can contaminate filtering (e.g., “R² >= 0.97”).

### Suggested change
- Set `R2 = NaN` and `fit_status = "no_relaxation"`.
- Keep `tau = Inf` if desired for semantics, but ensure downstream filters exclude non-fits.

```matlab
R2_safe = NaN;
fit_status = "no_relaxation";
fit_ok = false;
```

## 3.5 Improve window selection adaptivity

### Why
Fixed smoothing and fixed 20% fallback window are sensitive to sampling rate and protocol duration.

### Suggested logic
- Choose smoothing span from data length (`round(0.01*N)` clamped to odd [5,51]).
- Fallback window should enforce min/max duration and (optionally) minimum log-time coverage.

```matlab
N = numel(H);
span = max(5, min(51, 2*floor(0.01*N)+1));
Hsmooth = smooth(H, span, 'moving');

fallbackDur = max(60, min(0.4*(t(end)-t(1)), 1200)); % 1–20 min clamp
t_end = min(t(end), t_start + fallbackDur);
```

## 3.6 Weighted fitting: make bias explicit and tunable

### Why
Early-time upweighting can be scientifically valid, but should be documented and tested against unweighted results.

### Suggested practice
- Run both weighted and unweighted fits; keep both parameter sets and compare.
- Add diagnostic plot of residuals vs time (or log time).

```matlab
% Example strategy:
fit_unw = fitStretchedExp(t_fit, M_fit, Tnom, false, setfield(fitParams,'timeWeight',false));
fit_w   = fitStretchedExp(t_fit, M_fit, Tnom, false, setfield(fitParams,'timeWeight',true));
% choose by AIC/BIC or RMSE with penalty
```

## 3.7 De-duplicate display utilities

### Why
Single source of truth for TRM/IRM labeling and color policy reduces maintenance errors.

### Suggested target
Create a helper:

```matlab
function [modeType,isComparison,legendLabels,colors] = buildRelaxationDisplayMeta(...)
```

and call it from both `Plots_relaxation.m` and `overlayRelaxationFits.m`.

## 3.8 Improve plotting diagnostics

### Why
Visual QC is critical for failed/biased fits.

### Suggested additions
- On overlay figure, annotate each fit with `R²`, `tau`, `n`, and status for quick screening.
- Add optional residual subplot per curve for debug mode.

---

## 4) Quick “high-impact first” checklist

1. Remove `evalin` dependency in `fitAllRelaxations`.
2. Add fit status columns (`fit_ok`, `fit_status`, `RMSE`, `Npts`) and stop assigning `R2=1` to no-relaxation.
3. Add multi-start in `fitStretchedExp`.
4. Make field smoothing span adaptive in `pickRelaxWindow`.
5. Add uncertainty estimates (`CI_tau`, `CI_n`) where available.

These five changes keep the existing architecture but materially improve robustness and scientific defensibility.
