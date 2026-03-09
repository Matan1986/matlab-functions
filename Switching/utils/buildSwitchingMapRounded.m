function [temps, currents, Smap] = buildSwitchingMapRounded(samplesTbl)
tRaw = switchingNumericColumn(samplesTbl, 'T_K');
iRaw = switchingNumericColumn(samplesTbl, 'current_mA');
sRaw = switchingNumericColumn(samplesTbl, 'S_percent');

v = isfinite(tRaw) & isfinite(iRaw) & isfinite(sRaw);
tRaw = tRaw(v);
iRaw = iRaw(v);
sRaw = sRaw(v);

tVals = unique(tRaw);
currents = unique(iRaw);
tVals = sort(tVals(:));
currents = sort(currents(:));

Sraw = NaN(numel(tVals), numel(currents));
for it = 1:numel(tVals)
    for ii = 1:numel(currents)
        m = abs(tRaw - tVals(it)) < 1e-9 & abs(iRaw - currents(ii)) < 1e-9;
        if any(m)
            Sraw(it, ii) = mean(sRaw(m), 'omitnan');
        end
    end
end

Tclean = round(tVals);
[Tuniq, ~, idx] = unique(Tclean, 'sorted');
Smap = NaN(numel(Tuniq), numel(currents));
for k = 1:numel(Tuniq)
    mk = idx == k;
    Smap(k, :) = mean(Sraw(mk, :), 1, 'omitnan');
end

temps = Tuniq(:);
end