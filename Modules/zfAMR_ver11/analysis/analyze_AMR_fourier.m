% =========================================================
% Helper: Fourier-like projection on arbitrary angle grid
% =========================================================
function out = analyze_AMR_fourier(thetaDeg, y, opts)
% analyze_AMR_fourier
% Returns harmonic coefficients from y(theta) using projection on cos/sin basis.
%
% This does NOT require full 0-360 coverage. It uses the available angles only.

thetaDeg = thetaDeg(:);
y = y(:);

% Remove NaNs
m = isfinite(thetaDeg) & isfinite(y);
thetaDeg = thetaDeg(m);
y = y(m);

% Sort by angle
[thetaDeg, idx] = sort(thetaDeg);
y = y(idx);

% Optional preprocessing
if opts.removeMean
    y = y - mean(y, 'omitnan');
end
if opts.doDetrend
    y = detrend(y);
end

nH = opts.maxHarm;
nVec = (1:nH).';

Acos = zeros(nH,1);
Bsin = zeros(nH,1);

% Use trapezoidal rule on nonuniform grid
for n = 1:nH
    c = cosd(n * thetaDeg);
    s = sind(n * thetaDeg);
    Acos(n) = trapz(thetaDeg, y .* c);
    Bsin(n) = trapz(thetaDeg, y .* s);
end

Amp = hypot(Acos, Bsin);
Phi = atan2d(Bsin, Acos);  % degrees

out = struct();
out.n    = nVec;
out.Acos = Acos;
out.Bsin = Bsin;
out.Amp  = Amp;
out.Phi  = Phi;
end