function [S_norm, S_shape, Speak, rowMean, validRows, robustRows, peakFloor, gPeak] = buildShapeMaps(Smap, temps)
Speak = NaN(size(temps));
S_norm = NaN(size(Smap));
S_shape = NaN(size(Smap));
rowMean = NaN(size(temps));

for it = 1:numel(temps)
    row = Smap(it, :);
    v = isfinite(row);
    if ~any(v)
        continue;
    end
    Speak(it) = max(row(v), [], 'omitnan');
end

gPeak = max(Speak(isfinite(Speak)), [], 'omitnan');
peakFloor = max(1e-6, 1e-4 * gPeak);
validRows = isfinite(Speak) & Speak > peakFloor;

for it = 1:numel(temps)
    if ~validRows(it)
        continue;
    end
    row = Smap(it, :);
    v = isfinite(row);
    rn = NaN(size(row));
    rn(v) = row(v) / Speak(it);
    S_norm(it, :) = rn;
    mu = mean(rn(v), 'omitnan');
    rowMean(it) = mu;
    rc = rn;
    rc(v) = rn(v) - mu;
    S_shape(it, :) = rc;
end

robustRows = validRows & isfinite(temps) & temps <= 30 & Speak >= 0.05 * gPeak;
end