function [angMax, angMin] = extrema_from_model(theta, fold, p, Nharm)
% Use when you want robust extrema: take maxima/minima from the fitted Fourier model (not raw noisy data)

theta = theta(:);
tmin = min(theta); 
tmax = max(theta);

P = 360/fold;

% dense grid only over measured range (important for partial sweeps)
th = linspace(tmin, tmax, 4000);
yM = fourier_model(p, th*pi/180, fold, Nharm);

% find peaks on smooth model
[~,locMax] = findpeaks(yM, th, 'MinPeakDistance', 0.5*P/fold); %#ok<ASGLU>
[~,locMin] = findpeaks(-yM, th, 'MinPeakDistance', 0.5*P/fold); %#ok<ASGLU>

angMax = locMax(:).';
angMin = locMin(:).';
end
