function switchAmp = computeRepeatedSwitchAmplitude( ...
    Rpulse, plateaus, safetyFrac)
% COMPUTEREPEATEDSWITCHAMPLITUDE
% Robust switching amplitude for Repeated switching
%
% INPUT:
%   Rpulse     - pulse-resolved resistance (1D vector)
%   plateaus   - struct array with fields:
%                .idx    (indices in Rpulse)
%                .state  (A/B or 0/1)
%   safetyFrac - fraction of plateau used (default 0.2)
%
% OUTPUT:
%   switchAmp.values
%   switchAmp.median
%   switchAmp.mean
%   switchAmp.std
%   switchAmp.N

if nargin < 3 || isempty(safetyFrac)
    safetyFrac = 0.2;
end

deltas = [];

for k = 1:numel(plateaus)-1
    p1 = plateaus(k);
    p2 = plateaus(k+1);

    % Only true A <-> B transitions
    if p1.state == p2.state
        continue;
    end

    idx1 = p1.idx;
    idx2 = p2.idx;

    n1 = numel(idx1);
    n2 = numel(idx2);

    if n1 < 5 || n2 < 5
        continue;
    end

    % --- late part of plateau before transition ---
    i1 = idx1( ceil((1-safetyFrac)*n1) : end );

    % --- early part of plateau after transition ---
    i2 = idx2( 1 : ceil(safetyFrac*n2) );

    R1 = mean(Rpulse(i1),'omitnan');
    R2 = mean(Rpulse(i2),'omitnan');

    if isfinite(R1) && isfinite(R2)
        deltas(end+1) = abs(R2 - R1); %#ok<AGROW>
    end
end

switchAmp.values = deltas(:);
switchAmp.N      = numel(deltas);

if isempty(deltas)
    switchAmp.median = NaN;
    switchAmp.mean   = NaN;
    switchAmp.std    = NaN;
else
    switchAmp.median = median(deltas,'omitnan');
    switchAmp.mean   = mean(deltas,'omitnan');
    switchAmp.std    = std(deltas,'omitnan');
end
end
