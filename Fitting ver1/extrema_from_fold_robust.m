function [angMax, angMin] = extrema_from_fold_robust(theta, y, fold)

P = 360 / fold;

% --- fold angles ---
thetaFold = mod(theta, P);
[thetaFold, idx] = sort(thetaFold);
yFold = y(idx);

% --- smoothing ---
ys = smoothdata(yFold, 'movmean', max(5, round(numel(yFold)/40)));

% --- peak detection parameters ---
minProm = 0.05 * range(ys);
minDist = P / fold * 0.6;   % in degrees (folded domain)

% --- maxima ---
[~, locMax] = findpeaks(ys, ...
    'MinPeakProminence', minProm, ...
    'MinPeakDistance',  round(numel(ys)/fold));

angMax = thetaFold(locMax);

% --- minima ---
[~, locMin] = findpeaks(-ys, ...
    'MinPeakProminence', minProm, ...
    'MinPeakDistance',  round(numel(ys)/fold));

angMin = thetaFold(locMin);

end
