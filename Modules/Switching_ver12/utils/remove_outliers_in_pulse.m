function vals_clean = remove_outliers_in_pulse(vals, PulseOutlierPercent)
% Remove outliers inside a pulse window based on percent threshold
%
% vals – vector of samples inside the pulse window
% PulseOutlierPercent – threshold such as 150, 200, 300 [%]

    if isempty(vals) || all(isnan(vals))
        vals_clean = vals;
        return;
    end

    mu  = mean(vals,'omitnan');
    thr = abs(mu) * (PulseOutlierPercent/100);

    good = abs(vals - mu) <= thr;
    vals_clean = vals(good);

    if isempty(vals_clean)
        % If everything was removed (rare) – keep mean of original
        vals_clean = mu;
    end
end
