function [T_raw, M_raw, T_clean, M_clean, T_smooth, M_smooth] = ...
    clean_MT_data(T_in, M_in, fieldOe, params, ViewRAW)
% CLEAN_MT_DATA
% מחזירה:
%   T_raw, M_raw        – המקור (RAW)
%   T_clean, M_clean    – ניקוי Outliers + אינטרפולציה
%   T_smooth, M_smooth  – ניקוי + החלקה (SG + moving avg)

%% ---------------- RAW COPY ---------------- %%
T_raw = T_in;
M_raw = M_in;

% במצב RAW → מחזירים הכל כפי שהוא (לא מבצעים ניקוי)
if ViewRAW
    T_clean  = T_raw;
    M_clean  = M_raw;
    T_smooth = T_raw;
    M_smooth = M_raw;
    return;
end

%% ---------------- PARAMETERS ---------------- %%
tempJump_K      = params.tempJump_K;
magJump_sigma   = params.magJump_sigma;
useHampel       = params.useHampel;
hampelWindow    = params.hampelWindow;
hampelSigma     = params.hampelSigma;
max_interp_gap  = params.max_interp_gap;
sgOrder         = params.sgOrder;
sgFrame         = params.sgFrame;
movingAvgWindow = params.movingAvgWindow;
field_threshold = params.field_threshold;

T = T_in;
M = M_in;

%% ---------------- LOW FIELD → RAW ---------------- %%
if fieldOe < field_threshold
    T_clean  = T_raw;
    M_clean  = M_raw;
    T_smooth = T_raw;
    M_smooth = M_raw;
    return;
end

%% ---------------- OUTLIER DETECTION ---------------- %%

% 1) Temperature jumps
dT = [0; diff(T)];
badT = abs(dT) > tempJump_K;

% 2) Magnetization spikes (MAD of dM on smoothed M)
M_for_dM = movmedian(M,5);
dM = [0; diff(M_for_dM)];

dM_valid = dM(isfinite(dM));
if isempty(dM_valid)
    sMAD = eps;
else
    med_dM = median(dM_valid);
    sMAD   = 1.4826 * median(abs(dM_valid - med_dM));
    if sMAD == 0 || ~isfinite(sMAD)
        sMAD = std(dM_valid);
        if sMAD == 0 || ~isfinite(sMAD), sMAD = eps; end
    end
end
badM = abs(dM) > magJump_sigma * sMAD;

% Combined mask (לפני Hampel)
bad_mask = badT | badM;

%% ---------------- Hampel Correction (לא מוחקים!) ---------------- %%
if useHampel && numel(M) >= hampelWindow
    [M_hpl, idxH] = hampel(M, hampelWindow, hampelSigma);
    M(idxH) = M_hpl(idxH);
end

%% ---------------- Apply mask → NaN ---------------- %%
T(bad_mask) = NaN;
M(bad_mask) = NaN;

%% ---------------- Interpolation across gaps ---------------- %%
if max_interp_gap > 0
    goodIdx = find(~isnan(M) & ~isnan(T));

    if numel(goodIdx) >= 2
        M_int = fillmissing(M,'pchip');
        T_int = fillmissing(T,'pchip');

        gaps = diff(goodIdx) - 1;
        badLong = false(size(M));

        for g = find(gaps > max_interp_gap)'
            a = goodIdx(g);
            b = goodIdx(g+1);
            badLong(a+1:b-1) = true;
        end

        M_int(badLong) = NaN;
        T_int(badLong) = NaN;

        M = M_int;
        T = T_int;
    end
end

%% ---------------- Save CLEAN version ---------------- %%
T_clean = T;
M_clean = M;

%% ---------------- SMOOTHING ---------------- %%
M_smooth = M_clean;

if numel(M_smooth) >= sgFrame
    M_smooth = sgolayfilt(M_smooth, sgOrder, sgFrame);
end

if numel(M_smooth) >= movingAvgWindow
    M_smooth = movmean(M_smooth, movingAvgWindow, 'Endpoints','shrink');
end

T_smooth = T_clean;

end
