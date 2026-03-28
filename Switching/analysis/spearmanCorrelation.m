function r = spearmanCorrelation(x, y)
    x = x(:);
    y = y(:);
    valid = isfinite(x) & isfinite(y);
    x = x(valid);
    y = y(valid);
    if numel(x) < 2
        r = NaN;
        return;
    end

    rx = tiedRankLocal(x);
    ry = tiedRankLocal(y);
    r = pearsonCorrelation(rx, ry);
end

