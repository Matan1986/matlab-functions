function Q = folding_quality(theta, y, fold, binDeg)

P = 360 / fold;
thetaFold = mod(theta, P);

edges = 0:binDeg:P;
[~,~,bin] = histcounts(thetaFold, edges);

nb = numel(edges)-1;
meanBin = nan(nb,1);
varBin  = nan(nb,1);

for b = 1:nb
    idx = bin == b;
    if nnz(idx) > 2
        meanBin(b) = mean(y(idx));
        varBin(b)  = var(y(idx));
    end
end

signalVar = var(meanBin,'omitnan');
noiseVar  = mean(varBin,'omitnan');

Q = signalVar / noiseVar;
end
