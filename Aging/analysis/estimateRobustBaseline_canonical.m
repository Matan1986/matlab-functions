function out = estimateRobustBaseline_canonical(T, Y, Tmin, cfg, masks_optional)
% ESTIMATEROBUSTBASELINE_CANONICAL  Canonical robust baseline estimation for dip metrics

if nargin < 5
    masks_optional = [];
end

% Ensure column vectors
T = T(:);
Y = Y(:);
n = numel(T);

% Set defaults
if ~isfield(cfg, 'dip_margin_K');           cfg.dip_margin_K = 2; end
if ~isfield(cfg, 'plateau_nPoints');        cfg.plateau_nPoints = 6; end
if ~isfield(cfg, 'plateau_minWidth_K');     cfg.plateau_minWidth_K = 0; end
if ~isfield(cfg, 'plateau_minPoints');      cfg.plateau_minPoints = cfg.plateau_nPoints; end
if ~isfield(cfg, 'plateau_maxAllowedSlope'); cfg.plateau_maxAllowedSlope = inf; end
if ~isfield(cfg, 'plateau_allowNarrowFallback'); cfg.plateau_allowNarrowFallback = true; end
if ~isfield(cfg, 'dropLowestN');            cfg.dropLowestN = 1; end
if ~isfield(cfg, 'dropHighestN');           cfg.dropHighestN = 0; end
if ~isfield(cfg, 'plateau_agg');            cfg.plateau_agg = 'median'; end
if ~isfield(cfg, 'baseline_mode');          cfg.baseline_mode = 'linear'; end
if ~isfield(cfg, 'diagnosticsVerbose');     cfg.diagnosticsVerbose = false; end

% Initialize output
out = struct();
out.status = 'ok';
out.idxL = [];
out.idxR = [];
out.idxDip = [];
out.TL = NaN;
out.TR = NaN;
out.baseL = NaN;
out.baseR = NaN;
out.baseline = NaN(n, 1);
out.slope = NaN;
out.plateauL_mask = false(n, 1);
out.plateauR_mask = false(n, 1);
out.dip_mask = false(n, 1);
out.plateauL_width_K = NaN;
out.plateauR_width_K = NaN;
out.plateauL_slope = NaN;
out.plateauR_slope = NaN;
out.plateauCriteriaSatisfied = false;
out.narrowFallback = false;

% Define dip window
dipL = Tmin - cfg.dip_halfwidth_K;
dipR = Tmin + cfg.dip_halfwidth_K;
out.dip_mask = (T >= dipL) & (T <= dipR);
out.idxDip = find(out.dip_mask);

% If explicit masks were provided, use them
if ~isempty(masks_optional) && isstruct(masks_optional)
    if isfield(masks_optional, 'plateauL_mask') && numel(masks_optional.plateauL_mask) == n
        out.plateauL_mask = logical(masks_optional.plateauL_mask(:));
    end
    if isfield(masks_optional, 'plateauR_mask') && numel(masks_optional.plateauR_mask) == n
        out.plateauR_mask = logical(masks_optional.plateauR_mask(:));
    end
    if isfield(masks_optional, 'dip_mask') && numel(masks_optional.dip_mask) == n
        out.dip_mask = logical(masks_optional.dip_mask(:));
        out.idxDip = find(out.dip_mask);
    end
end

% Define plateau regions (with margin), enforce >=3 points by gradual expansion
minPlateauPts = 3;
maxExpandK = max(cfg.dip_margin_K, 6);
expandStepK = 0.5;
usedExpandK = 0;

idxL_all = [];
idxR_all = [];

for expandK = 0:expandStepK:maxExpandK
    marginEff = max(cfg.dip_margin_K - expandK, 0);

    out.plateauL_mask = T <= (dipL - marginEff);
    out.plateauR_mask = T >= (dipR + marginEff);

    idxL_all = find(out.plateauL_mask);
    if numel(idxL_all) > cfg.dropLowestN
        idxL_all = idxL_all(cfg.dropLowestN+1:end);
    else
        idxL_all = [];
    end

    idxR_all = find(out.plateauR_mask);
    if numel(idxR_all) > cfg.dropHighestN
        idxR_all = idxR_all(1:end-cfg.dropHighestN);
    else
        idxR_all = [];
    end

    if numel(idxL_all) >= minPlateauPts && numel(idxR_all) >= minPlateauPts
        usedExpandK = expandK;
        break;
    end
end

% Select plateau windows: enforce flatness/size criteria, with narrow fallback.
[out.idxL, statsL] = choosePlateauIndices(T, Y, idxL_all, 'left', cfg);
[out.idxR, statsR] = choosePlateauIndices(T, Y, idxR_all, 'right', cfg);
out.plateauL_width_K = statsL.width_K;
out.plateauR_width_K = statsR.width_K;
out.plateauL_slope = statsL.slope;
out.plateauR_slope = statsR.slope;
out.plateauCriteriaSatisfied = logical(statsL.criteriaSatisfied && statsR.criteriaSatisfied);
out.narrowFallback = logical(statsL.narrowFallback || statsR.narrowFallback);

% Safety checks
if numel(out.idxL) < minPlateauPts
    if cfg.diagnosticsVerbose
        fprintf('Warning: plateau_L has <3 points at Tmin=%.4g K (n=%d, expand=%.2g K)\n', Tmin, numel(out.idxL), usedExpandK);
    end
    out.status = 'insufficient_left_points';
    return;
end
if numel(out.idxR) < minPlateauPts
    if cfg.diagnosticsVerbose
        fprintf('Warning: plateau_R has <3 points at Tmin=%.4g K (n=%d, expand=%.2g K)\n', Tmin, numel(out.idxR), usedExpandK);
    end
    out.status = 'insufficient_right_points';
    return;
end

% Check for overlap with dip window
if any(out.plateauL_mask & out.dip_mask) || any(out.plateauR_mask & out.dip_mask)
    out.status = 'plateau_overlap_dip';
    return;
end

% Aggregate plateau levels robustly
YL = Y(out.idxL);
YR = Y(out.idxR);

if strcmpi(cfg.plateau_agg, 'trimmed')
    out.baseL = trimmean(YL, 20);
    out.baseR = trimmean(YR, 20);
else
    out.baseL = median(YL);
    out.baseR = median(YR);
end

% Compute plateau temperature positions
out.TL = median(T(out.idxL));
out.TR = median(T(out.idxR));

if out.TR <= out.TL
    out.status = 'invalid_plateau_order';
    return;
end

% Compute baseline (linear interpolation)
out.slope = (out.baseR - out.baseL) / (out.TR - out.TL);
out.baseline = out.baseL + out.slope * (T - out.TL);

% Mark as successful
out.status = 'ok';

end
function [idxSelected, stats] = choosePlateauIndices(T, Y, idxPool, side, cfg)
stats = struct();
stats.width_K = NaN;
stats.slope = NaN;
stats.criteriaSatisfied = false;
stats.narrowFallback = false;
idxSelected = [];

if isempty(idxPool)
    return;
end

nPool = numel(idxPool);
nBase = min(max(3, round(cfg.plateau_nPoints)), nPool);
nMin = max(3, round(cfg.plateau_minPoints));
minWidth = max(0, cfg.plateau_minWidth_K);
maxSlope = abs(cfg.plateau_maxAllowedSlope);
if ~isfinite(maxSlope) || maxSlope <= 0
    maxSlope = inf;
end

bestIdx = [];
bestSlope = inf;
bestWidth = -inf;
bestN = -inf;

for n = nBase:nPool
    if strcmpi(side, 'left')
        idxCandidate = idxPool(1:n);
    else
        idxCandidate = idxPool(end-n+1:end);
    end

    [widthK, slopeK, ok] = computeWindowStats(T, Y, idxCandidate);
    if ~ok
        continue;
    end

    isValid = (n >= nMin) && (widthK >= minWidth) && (abs(slopeK) <= maxSlope);
    if ~isValid
        continue;
    end

    slopeAbs = abs(slopeK);
    if slopeAbs < bestSlope || ...
       (slopeAbs == bestSlope && widthK > bestWidth) || ...
       (slopeAbs == bestSlope && widthK == bestWidth && n > bestN)
        bestIdx = idxCandidate;
        bestSlope = slopeAbs;
        bestWidth = widthK;
        bestN = n;
    end
end

if ~isempty(bestIdx)
    idxSelected = bestIdx;
    stats.criteriaSatisfied = true;
    [stats.width_K, stats.slope, ~] = computeWindowStats(T, Y, idxSelected);
    return;
end

if logical(cfg.plateau_allowNarrowFallback)
    if strcmpi(side, 'left')
        idxSelected = idxPool(1:nBase);
    else
        idxSelected = idxPool(end-nBase+1:end);
    end
    [stats.width_K, stats.slope, ~] = computeWindowStats(T, Y, idxSelected);
    stats.criteriaSatisfied = false;
    stats.narrowFallback = true;
end
end

function [widthK, slopeK, ok] = computeWindowStats(T, Y, idx)
widthK = NaN;
slopeK = NaN;
ok = false;

if isempty(idx)
    return;
end

Tseg = T(idx);
Yseg = Y(idx);
valid = isfinite(Tseg) & isfinite(Yseg);
Tseg = Tseg(valid);
Yseg = Yseg(valid);

if numel(Tseg) < 2
    return;
end

widthK = max(Tseg) - min(Tseg);
if ~isfinite(widthK)
    return;
end

if numel(unique(Tseg)) >= 2
    p = polyfit(Tseg, Yseg, 1);
    slopeK = p(1);
else
    slopeK = 0;
end

ok = isfinite(slopeK);
end
