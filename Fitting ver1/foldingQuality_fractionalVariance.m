function Q = foldingQuality_fractionalVariance(theta, y, fold, binDeg)
% Use to quantify how much of the total signal variance is explained by an n-fold symmetry
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

if nnz(valid) < 0.6 * effectiveBins
    Q = NaN;
    return
end


signalVar = var(meanBin(valid));
totalVar  = var(y);

Q = signalVar / totalVar;
end
