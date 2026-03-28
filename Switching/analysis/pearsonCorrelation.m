function r = pearsonCorrelation(x, y)
    x = x(:);
    y = y(:);
    valid = isfinite(x) & isfinite(y);
    x = x(valid);
    y = y(valid);
    if numel(x) < 2
        r = NaN;
        return;
    end

    sx = std(x, 0, 1);
    sy = std(y, 0, 1);
    if sx <= 0 || sy <= 0
        r = NaN;
        return;
    end

    x0 = x - mean(x);
    y0 = y - mean(y);
    r = sum(x0 .* y0) / ((numel(x) - 1) * sx * sy);
end

