function rel = relImprovement(oldVal, newVal)
    % Returns (old - new) / old; NaN if old invalid.
    if ~isfinite(oldVal) || oldVal == 0 || ~isfinite(newVal)
        rel = NaN;
        return;
    end
    rel = (oldVal - newVal) / oldVal;
end

