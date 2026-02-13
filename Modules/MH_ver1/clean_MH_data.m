function [H_raw, M_raw, H_clean, M_clean, H_smooth, M_smooth] = ...
         clean_MH_data(H_in, M_in, ViewRAW, P)
% Aggressive dent cleaning for MH curves.
% Parameters P:
%   P.slopeFactor      → threshold for detecting abnormal slope (lower = stronger)
%   P.minDentLength    → minimum #points to remove as a dent
%   P.maxInterpLength  → maximum #points to fill by interpolation

H_raw = H_in(:);
M_raw = M_in(:);

%% RAW MODE
if ViewRAW
    H_clean  = H_raw;
    M_clean  = M_raw;
    H_smooth = H_raw;
    M_smooth = M_raw;
    return;
end

H = H_raw;
M = M_raw;

%% 1) Remove non-finite
bad = ~isfinite(H) | ~isfinite(M);
H(bad) = NaN;
M(bad) = NaN;

%% 2) Compute slope dM/dH
dH = diff(H);
dM = diff(M);

slope = dM ./ dH;
slope(~isfinite(slope)) = 0;

%% 3) Typical slope
S0 = median(abs(slope));
if isempty(S0) || isnan(S0) || S0 == 0
    S0 = 1e-12;
end

%% 4) Identify dents based on slope anomaly
dentMask = abs(slope) > P.slopeFactor * S0;

%% 5) Expand to point indices
dentPts = false(length(M),1);
dentPts([dentMask; false]) = true;
dentPts([false; dentMask]) = true;

%% 6) Remove entire dent segments
CC = bwconncomp(dentPts);

for k = 1:CC.NumObjects
    idx = CC.PixelIdxList{k};

    if numel(idx) >= P.minDentLength
        M(idx) = NaN;
    end
end

%% 7) Interpolate small holes
nanIdx = isnan(M);
if any(nanIdx)
    C2 = bwconncomp(nanIdx);

    for k = 1:C2.NumObjects
        hole = C2.PixelIdxList{k};

        if numel(hole) <= P.maxInterpLength
            left  = hole(1)-1;
            right = hole(end)+1;

            if left>=1 && right<=length(M) && ~isnan(M(left)) && ~isnan(M(right))
                vals = linspace(M(left), M(right), numel(hole)+2).';
                M(hole) = vals(2:end-1);
            end
        end
    end
end

%% Final outputs
H_clean  = H;
M_clean  = M;
H_smooth = H_clean;
M_smooth = M_clean;

end
