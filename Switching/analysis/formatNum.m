function s = formatNum(x)
    if ~isfinite(x)
        s = 'NaN';
        return;
    end

    if abs(x) >= 100
        s = sprintf('%.3g', x);
    elseif abs(x) >= 10
        s = sprintf('%.4g', x);
    elseif abs(x) >= 1
        s = sprintf('%.5g', x);
    else
        s = sprintf('%.6g', x);
    end
end

