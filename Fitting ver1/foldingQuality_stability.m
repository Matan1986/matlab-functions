function Q = foldingQuality_stability(theta, y, fold, binDeg)
% Use for stable Q(n,T) maps and cross-temperature comparison (robust, bounded metric)
P = 360 / fold;
thetaFold = mod(theta, P);

edges = 0:binDeg:P;
[~,~,bin] = histcounts(thetaFold, edges);

nb = numel(edges)-1;
meanBin = nan(nb,1);

for b = 1:nb
    idx = bin == b;
    if nnz(idx) >= 5
        meanBin(b) = mean(y(idx));
    end
end

valid = ~isnan(meanBin);
thetaSpan = range(thetaFold);        % actual covered angle
effectiveBins = ceil(thetaSpan / binDeg);

if nnz(valid) < 0.7 * effectiveBins
    Q = NaN;
    return
end


signalStd = std(meanBin(valid));
noiseStd  = std(y);

Q = signalStd / noiseStd;
end
