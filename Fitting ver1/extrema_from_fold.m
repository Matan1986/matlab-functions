function [angMax, angMin] = extrema_from_fold(theta, y, fold)

P = 360 / fold;

% folded coordinates
thetaFold = mod(theta, P);
[thetaFold, idx] = sort(thetaFold);
yFold = y(idx);

% dominant extrema in ONE folded period
[~, iMax] = max(yFold);
[~, iMin] = min(yFold);

thetaMaxFold = thetaFold(iMax);
thetaMinFold = thetaFold(iMin);

% replicate over full angular range
kMax = floor((max(theta) - thetaMaxFold)/P);
kMin = floor((max(theta) - thetaMinFold)/P);

angMax = thetaMaxFold + (0:kMax)*P;
angMin = thetaMinFold + (0:kMin)*P;

% keep only measured angles
angMax = angMax(angMax >= min(theta) & angMax <= max(theta));
angMin = angMin(angMin >= min(theta) & angMin <= max(theta));

% sort by angle (as requested)
angMax = sort(angMax);
angMin = sort(angMin);

end
