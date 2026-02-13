function [thetaBin, yFold, nUsed] = fold_and_bin(thetaFold, y, binDeg)

edges = 0:binDeg:max(thetaFold)+binDeg;
[~,~,bin] = histcounts(thetaFold, edges);

nb = numel(edges)-1;
thetaBinAll = edges(1:end-1) + binDeg/2;
yFoldAll   = nan(nb,1);

for b = 1:nb
    idx = (bin == b);
    if nnz(idx) >= 1          % <-- היה >1 , עכשיו >=1
        yFoldAll(b) = mean(y(idx));
    end
end

mask = isfinite(yFoldAll);
thetaBin = thetaBinAll(mask);
yFold    = yFoldAll(mask);
nUsed    = numel(yFold);

end
