function dbg = debugAgingDiagnostics(cfg, Tp, T, dM_raw, dM_filt, windows, metrics, meta)
% debugAgingDiagnostics
% Diagnostics helper for aging + switching pipeline.
% Returns flags and a row struct for table export.

if nargin < 8
    meta = struct();
end

% --- Initialize row template with all possible fields (consistent struct shape) ---
rowTemplate = struct();
rowTemplate.Tp = NaN;
rowTemplate.dipDepth_raw = NaN;
rowTemplate.dipArea_raw = NaN;
rowTemplate.dipDepth_filt = NaN;
rowTemplate.dipArea_filt = NaN;
rowTemplate.SNR_depth_raw = NaN;
rowTemplate.SNR_depth_filt = NaN;
rowTemplate.noise_std = NaN;
rowTemplate.window_dip_lo = NaN;
rowTemplate.window_dip_hi = NaN;
rowTemplate.window_baseL_lo = NaN;
rowTemplate.window_baseL_hi = NaN;
rowTemplate.window_baseR_lo = NaN;
rowTemplate.window_baseR_hi = NaN;
rowTemplate.window_noise_lo = NaN;
rowTemplate.window_noise_hi = NaN;
rowTemplate.window_fmL_lo = NaN;
rowTemplate.window_fmL_hi = NaN;
rowTemplate.window_fmR_lo = NaN;
rowTemplate.window_fmR_hi = NaN;
rowTemplate.baselineL_mean = NaN;
rowTemplate.baselineR_mean = NaN;
rowTemplate.fmStep = NaN;
rowTemplate.dipSigma = NaN;
rowTemplate.dipFitArea = NaN;
rowTemplate.flag_dipWindowOutOfBounds = false;
rowTemplate.flag_baselineOutOfBounds = false;
rowTemplate.flag_noiseWindowOutOfBounds = false;
rowTemplate.flag_baselineOverlapsDip = false;
rowTemplate.flag_fmPlateauOverlapsDip = false;
rowTemplate.flag_filterImpactLarge = false;
rowTemplate.flag_lowSNR = false;
rowTemplate.flag_suspiciousSpike = false;
rowTemplate.flag_dipMinOutsideWindow = false;
rowTemplate.flag_dipMinTooCloseToBoundary = false;
rowTemplate.flag_plateauSlopeExcessive = false;
rowTemplate.Tmin_dip = NaN;
rowTemplate.plateau_slope_L = NaN;
rowTemplate.plateau_R2_L = NaN;
rowTemplate.plateau_slope_R = NaN;
rowTemplate.plateau_R2_R = NaN;
rowTemplate.plateau_N_L = 0;
rowTemplate.plateau_N_R = 0;
rowTemplate.plateau_std_L = NaN;
rowTemplate.plateau_std_R = NaN;
rowTemplate.sampleName = '';
rowTemplate.pauseLabel = '';
rowTemplate.sourceFile = '';

Tp = Tp(:);
T = T(:);
dM_raw = dM_raw(:);
dM_filt = dM_filt(:);

if isempty(dM_filt)
    dM_filt = dM_raw;
end

finiteT = isfinite(T);
if any(finiteT)
    Tmin = min(T(finiteT));
    Tmax = max(T(finiteT));
else
    Tmin = -inf;
    Tmax = inf;
end

flags = struct();
flags.dipWindowOutOfBounds = ~isWindowInBounds(windows.dip, Tmin, Tmax);
flags.baselineOutOfBounds = ~isWindowInBounds(windows.baseL, Tmin, Tmax) || ...
                            ~isWindowInBounds(windows.baseR, Tmin, Tmax);
flags.noiseWindowOutOfBounds = ~isWindowInBounds(windows.noise, Tmin, Tmax);

flags.baselineOverlapsDip = windowsOverlap(windows.baseL, windows.dip) || ...
                            windowsOverlap(windows.baseR, windows.dip);
flags.fmPlateauOverlapsDip = windowsOverlap(windows.fmPlateauL, windows.dip) || ...
                             windowsOverlap(windows.fmPlateauR, windows.dip);

[noise_std, noiseMask] = windowStd(T, dM_filt, windows.noise);

if isfinite(metrics.dipDepth_raw) && noise_std > 0
    SNR_depth_raw = metrics.dipDepth_raw / noise_std;
else
    SNR_depth_raw = NaN;
end

if isfinite(metrics.dipDepth_filt) && noise_std > 0
    SNR_depth_filt = metrics.dipDepth_filt / noise_std;
else
    SNR_depth_filt = NaN;
end

filterImpactLarge = false;
if isfinite(metrics.dipDepth_raw) && metrics.dipDepth_raw ~= 0
    pctDepth = 100 * (metrics.dipDepth_filt - metrics.dipDepth_raw) / metrics.dipDepth_raw;
    if abs(pctDepth) > cfg.debug.filterImpactWarnPct
        filterImpactLarge = true;
    end
end
if isfinite(metrics.dipArea_raw) && metrics.dipArea_raw ~= 0
    pctArea = 100 * (metrics.dipArea_filt - metrics.dipArea_raw) / metrics.dipArea_raw;
    if abs(pctArea) > cfg.debug.filterImpactWarnPct
        filterImpactLarge = true;
    end
end
flags.filterImpactLarge = filterImpactLarge;

flags.lowSNR = isfinite(SNR_depth_filt) && SNR_depth_filt < 2;
flags.suspiciousSpike = detectSpike(T, dM_filt, cfg.debug.noiseWindowHighT, 5);

% --- NEW: Dip minimum position check ---
[flags.dipMinOutsideWindow, flags.dipMinTooCloseToBoundary, Tmin_dip] = ...
    checkDipMinimumPosition(T, dM_filt, windows.dip, cfg.debug.dipMinMarginFraction);

% --- NEW: Plateau linearity check ---
[flags.plateauSlopeExcessive, plateau_slope_L, plateau_R2_L, plateau_slope_R, plateau_R2_R, plateau_N_L, plateau_N_R, plateau_std_L, plateau_std_R] = ...
    checkPlateauLinearity(T, dM_filt, windows.fmPlateauL, windows.fmPlateauR, cfg.debug.plateauMaxSlope);

% Optional warnings (no exceptions)
if cfg.debug.boundsWarn
    if flags.dipWindowOutOfBounds || flags.baselineOutOfBounds || flags.noiseWindowOutOfBounds
        warning('Diagnostics: window out-of-bounds at Tp=%.1f K\nData range: [%.2f, %.2f]\nDip window: [%.2f, %.2f]\nPlateau window: [%.2f, %.2f]\nNum points: %d', ...
            Tp(1), Tmin, Tmax, windows.dip(1), windows.dip(2), ...
            windows.fmPlateauL(1), windows.fmPlateauR(2), numel(T));
    end
end
if cfg.debug.overlapWarn
    if flags.baselineOverlapsDip || flags.fmPlateauOverlapsDip
        warning('Diagnostics: window overlap at Tp=%.3f K', Tp(1));
    end
end

% Start with template (ensures consistent struct shape)
row = rowTemplate;

% Overwrite computed fields
row.Tp = Tp(1);
row.dipDepth_raw = metrics.dipDepth_raw;
row.dipArea_raw = metrics.dipArea_raw;
row.dipDepth_filt = metrics.dipDepth_filt;
row.dipArea_filt = metrics.dipArea_filt;
row.SNR_depth_raw = SNR_depth_raw;
row.SNR_depth_filt = SNR_depth_filt;
row.noise_std = noise_std;

row.window_dip_lo = windows.dip(1);
row.window_dip_hi = windows.dip(2);
row.window_baseL_lo = windows.baseL(1);
row.window_baseL_hi = windows.baseL(2);
row.window_baseR_lo = windows.baseR(1);
row.window_baseR_hi = windows.baseR(2);
row.window_noise_lo = windows.noise(1);
row.window_noise_hi = windows.noise(2);
row.window_fmL_lo = windows.fmPlateauL(1);
row.window_fmL_hi = windows.fmPlateauL(2);
row.window_fmR_lo = windows.fmPlateauR(1);
row.window_fmR_hi = windows.fmPlateauR(2);

row.baselineL_mean = meanInWindow(T, dM_filt, windows.baseL);
row.baselineR_mean = meanInWindow(T, dM_filt, windows.baseR);
row.fmStep = metrics.fmStep;
row.dipSigma = metrics.dipSigma;
row.dipFitArea = metrics.dipFitArea;

row.flag_dipWindowOutOfBounds = logical(flags.dipWindowOutOfBounds);
row.flag_baselineOutOfBounds = logical(flags.baselineOutOfBounds);
row.flag_noiseWindowOutOfBounds = logical(flags.noiseWindowOutOfBounds);
row.flag_baselineOverlapsDip = logical(flags.baselineOverlapsDip);
row.flag_fmPlateauOverlapsDip = logical(flags.fmPlateauOverlapsDip);
row.flag_filterImpactLarge = logical(flags.filterImpactLarge);
row.flag_lowSNR = logical(flags.lowSNR);
row.flag_suspiciousSpike = logical(flags.suspiciousSpike);
row.flag_dipMinOutsideWindow = logical(flags.dipMinOutsideWindow);
row.flag_dipMinTooCloseToBoundary = logical(flags.dipMinTooCloseToBoundary);
row.flag_plateauSlopeExcessive = logical(flags.plateauSlopeExcessive);

row.Tmin_dip = Tmin_dip;
row.plateau_slope_L = plateau_slope_L;
row.plateau_R2_L = plateau_R2_L;
row.plateau_slope_R = plateau_slope_R;
row.plateau_R2_R = plateau_R2_R;
row.plateau_N_L = plateau_N_L;
row.plateau_N_R = plateau_N_R;
row.plateau_std_L = plateau_std_L;
row.plateau_std_R = plateau_std_R;

% Overwrite optional metadata fields if present
if isfield(meta, 'sampleName')
    row.sampleName = meta.sampleName;
end
if isfield(meta, 'pauseLabel')
    row.pauseLabel = meta.pauseLabel;
end
if isfield(meta, 'sourceFile')
    row.sourceFile = meta.sourceFile;
end

if isempty(noiseMask)
    noiseMask = false(size(T));
end

% Output
DBG = struct();
DBG.row = row;
DBG.flags = flags;
DBG.noise_std = noise_std;
DBG.SNR_depth_raw = SNR_depth_raw;
DBG.SNR_depth_filt = SNR_depth_filt;
DBG.noiseMask = noiseMask;

% Assign to output
dbg = DBG;

end

% ====================== Helper functions ======================
function tf = isWindowInBounds(win, Tmin, Tmax)
if isempty(win) || numel(win) ~= 2 || any(~isfinite(win))
    tf = false;
    return;
end
lo = min(win);
hi = max(win);
if lo < Tmin || hi > Tmax
    tf = false;
else
    tf = true;
end
end

function tf = windowsOverlap(a, b)
if isempty(a) || isempty(b) || numel(a) ~= 2 || numel(b) ~= 2
    tf = false;
    return;
end
loA = min(a); hiA = max(a);
loB = min(b); hiB = max(b);
if hiA < loB || hiB < loA
    tf = false;
else
    tf = true;
end
end

function [s, mask] = windowStd(T, y, win)
mask = false(size(T));
if isempty(win) || numel(win) ~= 2
    s = NaN;
    return;
end
lo = min(win); hi = max(win);
mask = isfinite(T) & isfinite(y) & (T >= lo) & (T <= hi);
vals = y(mask);
if numel(vals) < 3
    s = NaN;
else
    s = std(vals, 0, 'omitnan');
end
end

function m = meanInWindow(T, y, win)
if isempty(win) || numel(win) ~= 2
    m = NaN;
    return;
end
lo = min(win); hi = max(win);
mask = isfinite(T) & isfinite(y) & (T >= lo) & (T <= hi);
vals = y(mask);
if isempty(vals)
    m = NaN;
else
    m = mean(vals, 'omitnan');
end
end

function tf = detectSpike(T, y, band, nSigma)
if numel(band) ~= 2
    tf = false;
    return;
end
lo = min(band); hi = max(band);
mask = isfinite(T) & isfinite(y) & (T >= lo) & (T <= hi);
vals = y(mask);
if numel(vals) < 5
    tf = false;
    return;
end
mu = mean(vals, 'omitnan');
sd = std(vals, 0, 'omitnan');
if sd <= 0
    tf = false;
    return;
end
z = abs(vals - mu) / sd;
tf = any(z > nSigma);
end

function [outsideFlag, tooCloseFlag, Tmin_dip] = checkDipMinimumPosition(T, dM, dipWindow, marginFraction)
% Check if the dip minimum lies inside the dip window and not too close to edges.
T = T(:);
dM = dM(:);
dipMask = T >= dipWindow(1) & T <= dipWindow(2);

if nnz(dipMask) < 2
    outsideFlag = true;
    tooCloseFlag = false;
    Tmin_dip = NaN;
    return;
end

T_dip = T(dipMask);
dM_dip = dM(dipMask);
[~, minIdx] = min(dM_dip);
Tmin_dip = T_dip(minIdx);

outsideFlag = (Tmin_dip < dipWindow(1)) || (Tmin_dip > dipWindow(2));

windowWidth = dipWindow(2) - dipWindow(1);
margin = marginFraction * windowWidth;
leftBoundary = dipWindow(1) + margin;
rightBoundary = dipWindow(2) - margin;

tooCloseFlag = (Tmin_dip < leftBoundary) || (Tmin_dip > rightBoundary);
end

function [slopeExcessiveFlag, slope_L, R2_L, slope_R, R2_R, N_L, N_R, std_L, std_R] = checkPlateauLinearity(T, dM, plateauL, plateauR, maxSlope)
% Perform linear fit on left and right plateau windows; flag if slope exceeds threshold.
T = T(:);
dM = dM(:);

% Left plateau
maskL = T >= plateauL(1) & T <= plateauL(2);
N_L = nnz(maskL);
if N_L >= 2
    T_L = T(maskL);
    dM_L = dM(maskL);
    std_L = std(dM_L, 0, 'omitnan');
    
    if N_L >= 3
        p_L = polyfit(T_L, dM_L, 1);
        slope_L = p_L(1);
        dM_L_fit = polyval(p_L, T_L);
        SS_res_L = sum((dM_L - dM_L_fit).^2);
        SS_tot_L = sum((dM_L - mean(dM_L)).^2);
        if SS_tot_L > 0
            R2_L = 1 - SS_res_L / SS_tot_L;
        else
            R2_L = NaN;
        end
    else
        % N_L < 3: compute slope only, set R2 = NaN
        p_L = polyfit(T_L, dM_L, 1);
        slope_L = p_L(1);
        R2_L = NaN;
    end
else
    slope_L = NaN;
    R2_L = NaN;
    std_L = NaN;
end

% Right plateau
maskR = T >= plateauR(1) & T <= plateauR(2);
N_R = nnz(maskR);
if N_R >= 2
    T_R = T(maskR);
    dM_R = dM(maskR);
    std_R = std(dM_R, 0, 'omitnan');
    
    if N_R >= 3
        p_R = polyfit(T_R, dM_R, 1);
        slope_R = p_R(1);
        dM_R_fit = polyval(p_R, T_R);
        SS_res_R = sum((dM_R - dM_R_fit).^2);
        SS_tot_R = sum((dM_R - mean(dM_R)).^2);
        if SS_tot_R > 0
            R2_R = 1 - SS_res_R / SS_tot_R;
        else
            R2_R = NaN;
        end
    else
        % N_R < 3: compute slope only, set R2 = NaN
        p_R = polyfit(T_R, dM_R, 1);
        slope_R = p_R(1);
        R2_R = NaN;
    end
else
    slope_R = NaN;
    R2_R = NaN;
    std_R = NaN;
end

slopeExcessiveFlag = (isfinite(slope_L) && abs(slope_L) > maxSlope) || ...
                     (isfinite(slope_R) && abs(slope_R) > maxSlope);
end
