function metrics = computeMetrics(y, yhat)
    valid = isfinite(y) & isfinite(yhat);
    x = y(valid);
    yh = yhat(valid);

    metrics = struct();
    if isempty(x)
        metrics.rmse = NaN;
        metrics.pearson_r = NaN;
        metrics.spearman_r = NaN;
        return;
    end

    metrics.rmse = sqrt(mean((x - yh) .^ 2, 'omitnan'));
    metrics.pearson_r = pearsonCorrelation(x, yh);
    metrics.spearman_r = spearmanCorrelation(x, yh);
end

