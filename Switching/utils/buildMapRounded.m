function [temps, currents, Smap] = buildMapRounded(tbl)
Traw = switchingNumericColumn(tbl, 'T_K');
Iraw = switchingNumericColumn(tbl, 'current_mA');
Sraw = switchingNumericColumn(tbl, 'S_percent');

v = isfinite(Traw) & isfinite(Iraw) & isfinite(Sraw);
Traw = Traw(v);
Iraw = Iraw(v);
Sraw = Sraw(v);

Tbin = round(Traw);
temps = sort(unique(Tbin));
currents = sort(unique(Iraw));

Smap = NaN(numel(temps), numel(currents));
for it = 1:numel(temps)
    for ii = 1:numel(currents)
        m = Tbin == temps(it) & abs(Iraw - currents(ii)) < 1e-9;
        if any(m)
            Smap(it, ii) = mean(Sraw(m), 'omitnan');
        end
    end
end
end