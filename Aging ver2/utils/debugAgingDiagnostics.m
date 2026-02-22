function dbg = debugAgingDiagnostics(cfg, Tp, T, dM_raw, dM_filt, windows, metrics, meta)
% debugAgingDiagnostics
% Diagnostics helper for aging + switching pipeline.
% Returns flags and a row struct for table export.

if nargin < 8
    meta = struct();
end

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

% Optional warnings (no exceptions)
if cfg.debug.boundsWarn
    if flags.dipWindowOutOfBounds || flags.baselineOutOfBounds || flags.noiseWindowOutOfBounds
        warning('Diagnostics: window out-of-bounds at Tp=%.3f K', Tp(1));
    end
end
if cfg.debug.overlapWarn
    if flags.baselineOverlapsDip || flags.fmPlateauOverlapsDip
        warning('Diagnostics: window overlap at Tp=%.3f K', Tp(1));
    end
end

row = struct();
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
