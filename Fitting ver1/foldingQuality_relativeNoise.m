function Q = foldingQuality_relativeNoise(theta, y, fold, binDeg)
% Use for automatic fold detection with partial angular coverage

P = 360 / fold;
thetaFold = mod(theta, P);

edges = 0:binDeg:P;
[~,~,bin] = histcounts(thetaFold, edges);

nb = numel(edges)-1;
meanBin = nan(nb,1);
varBin  = nan(nb,1);
nBin    = zeros(nb,1);

for b = 1:nb
    idx = (bin == b);
    nBin(b) = nnz(idx);

    if nBin(b) >= 3          % <<< היה 5 — זה היה קשוח מדי
        meanBin(b) = mean(y(idx));
        varBin(b)  = var(y(idx));
    end
end

% ---- effective coverage (only where data exist) ----
validMean = ~isnan(meanBin);
validVar  = ~isnan(varBin);

nEff = nnz(validMean);
if nEff < 6                 % <<< מינימום bins אפקטיביים
    Q = NaN;
    return
end

% ---- signal ----
signalVar = var(meanBin(validMean));

% ---- noise ----
noiseVar = mean(varBin(validVar));

% ---- noise floor ----
globalVar = var(y);
noiseVar  = max(noiseVar, 0.05 * globalVar);

Q = signalVar / noiseVar;
end
