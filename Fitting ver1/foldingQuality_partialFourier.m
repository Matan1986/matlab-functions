function Q = foldingQuality_partialFourier(thetaDeg, y, fold)
% foldingQuality_partialFourier
% Q metric adapted for partial angular sweeps
%
% USE WHEN:
% - Angular coverage < 360 deg
% - Want sensitivity to low folds (n=3,4)
% - Robust to incomplete periods
%
% Q = (power in nth harmonic) / (total signal variance)

theta = thetaDeg(:) * pi/180;   % radians
y     = y(:);

% remove mean (critical!)
y = y - mean(y,'omitnan');

N = numel(y);
if N < 5 || var(y)==0
    Q = NaN;
    return
end

% Fourier projection
a = (2/N) * sum(y .* cos(fold * theta));
b = (2/N) * sum(y .* sin(fold * theta));

A2 = a^2 + b^2;      % harmonic power
V  = var(y);         % total variance

Q = A2 / V;
end
