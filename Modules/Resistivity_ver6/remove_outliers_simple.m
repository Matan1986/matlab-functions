function y_clean = remove_outliers_simple(y, thr)
    dy = abs(diff(y));
    bad = [false; dy > thr];
    y_clean = y;
    y_clean(bad) = NaN;
end
