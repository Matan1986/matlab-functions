function [angMax, angMin] = extrema_from_fold_local(theta, y, fold, opts)
% Find local extrema guided by folding symmetry

if nargin < 4, opts = struct(); end
if ~isfield(opts,'sgolayOrder'),  opts.sgolayOrder = 3; end
if ~isfield(opts,'sgolayFrame'),  opts.sgolayFrame = 11; end
if ~isfield(opts,'minPromFrac'),  opts.minPromFrac = 0.15; end
if ~isfield(opts,'minPeakDistDeg')
    opts.minPeakDistDeg = 0.4 * (360/fold);
end

theta = theta(:);
y     = y(:);

P = 360 / fold;

%% --- 1) light smoothing ---
ySmooth = sgolayfilt(y, opts.sgolayOrder, opts.sgolayFrame);

%% --- 2) find ALL local extrema (index-based, robust) ---
yRange  = max(ySmooth) - min(ySmooth);
minProm = opts.minPromFrac * yRange;

[pksMax, idxMax] = findpeaks(ySmooth, ...
    'MinPeakProminence', minProm, ...
    'MinPeakDistance',  round(opts.minPeakDistFrac * numel(ySmooth) / fold));

[pksMin, idxMin] = findpeaks(-ySmooth, ...
    'MinPeakProminence', minProm, ...
    'MinPeakDistance',  round(opts.minPeakDistFrac * numel(ySmooth) / fold));
pksMin = -pksMin;

locMax = theta(idxMax);
locMin = theta(idxMin);

%% --- 3) assign extrema to folded coordinate ---
foldMax = mod(locMax, P);
foldMin = mod(locMin, P);

angMax = [];
angMin = [];

%% --- 4) pick dominant extremum per folded sector ---
angMax = [];
angMin = [];

theta0 = min(theta);

nPeriods = floor((max(theta) - theta0) / P) + 1;

for j = 0:nPeriods-1
    lo = theta0 + j*P;
    hi = lo + P;

    % -------- maxima --------
    idx = locMax >= lo & locMax < hi;
    if any(idx)
        locs = locMax(idx);
        vals = pksMax(idx);
        [~, i] = max(vals);
        angMax(end+1) = locs(i);
    end

    % -------- minima --------
    idx = locMin >= lo & locMin < hi;
    if any(idx)
        locs = locMin(idx);
        vals = pksMin(idx);
        [~, i] = min(vals);
        angMin(end+1) = locs(i);
    end
end

%% --- 5) sort & clip to measured range ---
angMax = sort(angMax);
angMin = sort(angMin);

angMax = angMax(angMax >= min(theta) & angMax <= max(theta));
angMin = angMin(angMin >= min(theta) & angMin <= max(theta));

end
