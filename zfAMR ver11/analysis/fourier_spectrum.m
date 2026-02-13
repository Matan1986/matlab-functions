function out = fourier_spectrum(theta, y, opts)
% fourier_spectrum
% ------------------------------------------------------------
% Compute Fourier-like angular spectrum on discrete angle grid
%
% - Supports arbitrary angular ranges (not necessarily 0–360)
% - Normalizes scan span to 360 degrees
% - Robust to partial and non-uniform angle grids
% - Guards against duplicated periodic endpoints (e.g. 0 & 360)
%
% Inputs:
%   theta : angular coordinate (deg)
%   y     : signal
%   opts:
%       .removeMean (true/false)
%       .doDetrend  (true/false)
%       .maxHarm    (integer)
%
% Output:
%   out.n    : harmonic index
%   out.An   : cosine coefficients
%   out.Bn   : sine coefficients
%   out.Amp  : amplitude

    %% --- reshape ---
    theta = theta(:);
    y     = y(:);

    %% --- guard: remove duplicated periodic endpoint ---
    % If scan includes both endpoints of one full period
    % (e.g. 0 and 360, -180 and 180, etc.)
    if numel(theta) > 1
        span = max(theta) - min(theta);
        tol  = 1e-6;
        if abs(theta(end) - theta(1) - span) < tol
            theta = theta(1:end-1);
            y     = y(1:end-1);
        end
    end

    %% --- preprocessing ---
    if isfield(opts,'removeMean') && opts.removeMean
        y = y - nanmean(y);
    end
    if isfield(opts,'doDetrend') && opts.doDetrend
        y = detrend(y);
    end

    %% --- angular normalization ---
    span  = max(theta) - min(theta);
    scale = 360 / span;

    %% --- Fourier coefficients ---
    maxH = opts.maxHarm;
    An = zeros(maxH,1);
    Bn = zeros(maxH,1);

    for n = 1:maxH
        An(n) = trapz(theta, y .* cosd(n * scale * theta));
        Bn(n) = trapz(theta, y .* sind(n * scale * theta));
    end

    %% --- output ---
    out.n   = (1:maxH).';
    out.An  = An;
    out.Bn  = Bn;
    out.Amp = hypot(An, Bn);

end
