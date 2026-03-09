function [Xshape, Aleft, Aright] = computeXshapeFromMap(Smap, currents, Ipeak)
Xshape = NaN(size(Ipeak));
Aleft = NaN(size(Ipeak));
Aright = NaN(size(Ipeak));

for it = 1:numel(Ipeak)
    row = Smap(it, :);
    cur = currents(:)';
    v = isfinite(row) & isfinite(cur) & isfinite(Ipeak(it));
    if nnz(v) < 3
        continue;
    end

    rv = row(v);
    cv = cur(v);
    mL = cv < Ipeak(it);
    mR = cv > Ipeak(it);
    if ~any(mL) || ~any(mR)
        continue;
    end

    Aleft(it) = sum(rv(mL), 'omitnan');
    Aright(it) = sum(rv(mR), 'omitnan');
    den = Aleft(it) + Aright(it);
    if isfinite(den) && abs(den) > eps
        Xshape(it) = max(min((Aright(it) - Aleft(it)) / den, 1), -1);
    end
end
end