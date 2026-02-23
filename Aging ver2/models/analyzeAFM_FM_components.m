function pauseRuns = analyzeAFM_FM_components( ...
    pauseRuns, dip_window_K, smoothWindow_K, ...
    excludeLowT_FM, excludeLowT_K, ...
    FM_plateau_K, excludeLowT_mode, FM_buffer_K, dipMetric)

% =========================================================
% analyzeAFM_FM_components
%
% PURPOSE:
%   Decompose DeltaM into AFM-like (sharp dip) and FM-like (smooth background)
%   components and compute per-pause metrics.
%
% INPUTS:
%   pauseRuns       - struct array with fields T_common, DeltaM, waitK
%   dip_window_K    - half-window around Tp for AFM dip
%   smoothWindow_K  - smoothing scale for FM background
%   excludeLowT_FM  - flag to exclude low-T in FM background
%   excludeLowT_K   - temperature cutoff for low-T exclusion
%   FM_plateau_K    - width of FM plateau window
%   excludeLowT_mode- 'pre' or 'post' handling of low-T exclusion
%   FM_buffer_K     - buffer distance from dip for FM plateau
%   dipMetric       - 'height' or 'area'
%
% OUTPUTS:
%   pauseRuns       - updated struct with AFM/FM metrics and components
%
% Physics meaning:
%   AFM = sharp dip in DeltaM (memory component)
%   FM  = smooth background step around Tp
%
% =========================================================

%% ---------------- Defaults ----------------
if nargin < 3 || isempty(smoothWindow_K)
    smoothWindow_K = 12;     % K
end
if nargin < 4 || isempty(excludeLowT_FM)
    excludeLowT_FM = false;
end
if nargin < 5 || isempty(excludeLowT_K)
    excludeLowT_K = -inf;
end
if nargin < 6 || isempty(FM_plateau_K)
    FM_plateau_K = 6;        % K
end
if nargin < 7 || isempty(excludeLowT_mode)
    excludeLowT_mode = 'pre';
end
if nargin < 8 || isempty(FM_buffer_K)
    FM_buffer_K = 3;         % K
end
if nargin < 9 || isempty(dipMetric)
    dipMetric = 'height';   % ברירת מחדל
end
dipMetric = lower(string(dipMetric));

excludeLowT_mode = lower(string(excludeLowT_mode));

%% ---------------- Loop ----------------
assert(isfield(pauseRuns, 'DeltaM'), 'pauseRuns missing DeltaM');
for i = 1:numel(pauseRuns)

    % ---- persist settings ----
    pauseRuns(i).dip_window_K   = dip_window_K;
    pauseRuns(i).smoothWindow_K = smoothWindow_K;
    pauseRuns(i).FM_plateau_K   = FM_plateau_K;
    pauseRuns(i).FM_buffer_K    = FM_buffer_K;
    pauseRuns(i).excludeLowT_FM = excludeLowT_FM;
    pauseRuns(i).excludeLowT_K  = excludeLowT_K;
    pauseRuns(i).excludeLowT_mode = char(excludeLowT_mode);

    % ---- init outputs ----
    pauseRuns(i).DeltaM_smooth = [];
    pauseRuns(i).DeltaM_sharp  = [];
    pauseRuns(i).AFM_amp       = NaN;
    pauseRuns(i).AFM_amp_err   = NaN;
    pauseRuns(i).AFM_area      = NaN;
    pauseRuns(i).AFM_area_err  = NaN;
    pauseRuns(i).FM_step_raw   = NaN;
    pauseRuns(i).FM_step_mag   = NaN;
    pauseRuns(i).FM_step_err   = NaN;

    if ~isfield(pauseRuns(i),'T_common') || ~isfield(pauseRuns(i),'DeltaM')
        continue;
    end

    T  = pauseRuns(i).T_common(:);
    dM = pauseRuns(i).DeltaM(:);
    Tp = pauseRuns(i).waitK;

    if numel(T) < 20 || numel(T) ~= numel(dM)
        continue;
    end

    %% =====================================================
    % 0) validity
    %% =====================================================
    baseValid = isfinite(T) & isfinite(dM);

    if excludeLowT_FM
        lowT_invalid = T < excludeLowT_K;
    else
        lowT_invalid = false(size(T));
    end

    %% =====================================================
    % 1) FM smooth background
    %% =====================================================
    dT = median(diff(T(baseValid)));
    if ~isfinite(dT) || dT <= 0
        dT = 0.1;
    end

    winPts = round(smoothWindow_K / dT);
    winPts = max(winPts + mod(winPts+1,2), 11);

    dM_work = dM;
    if excludeLowT_FM && excludeLowT_mode == "pre"
        dM_work(lowT_invalid) = NaN;
    end

    finiteMask = isfinite(dM_work) & isfinite(T);

    if nnz(finiteMask) < winPts
        dM_smooth = NaN(size(dM));
    else
        dM_fill = dM_work;
        dM_fill(~finiteMask) = interp1( ...
            T(finiteMask), dM_work(finiteMask), ...
            T(~finiteMask), 'linear','extrap');

        dM_smooth = sgolayfilt(dM_fill,2,winPts);
        dM_smooth(~baseValid) = NaN;
        if excludeLowT_FM && excludeLowT_mode=="pre"
            dM_smooth(lowT_invalid) = NaN;
        end
    end

    dM(~baseValid) = NaN;
    if excludeLowT_FM && excludeLowT_mode=="post"
        dM(lowT_invalid) = NaN;
        dM_smooth(lowT_invalid) = NaN;
    end

    %% =====================================================
    % 2) AFM sharp component
    %% =====================================================
    dM_sharp = dM - dM_smooth;

    pauseRuns(i).DeltaM_smooth = dM_smooth;
    pauseRuns(i).DeltaM_sharp  = dM_sharp;

    maskDip = isfinite(T) & ...
        (T > Tp - dip_window_K) & ...
        (T < Tp + dip_window_K);

    if nnz(maskDip) < 5
        continue;
    end

    dipVals = dM_sharp(maskDip);
    dipVals = dipVals(isfinite(dipVals));

    if isempty(dipVals)
        continue;
    end
    %% =====================================================
    % 3) AFM dip metrics + errors
    %% =====================================================
    switch dipMetric

        case "height"
            % ----- dip as amplitude -----
            pauseRuns(i).AFM_amp = -mean(dipVals);
            pauseRuns(i).AFM_amp_err = std(dipVals) / sqrt(numel(dipVals));
            pauseRuns(i).AFM_area = NaN;
            pauseRuns(i).AFM_area_err = NaN;

        case "area"
            % ----- dip as integrated weight -----
            y = max(0, -dM_sharp);
            xDip = T(maskDip);
            yDip = y(maskDip);

            if numel(xDip) ~= numel(yDip)
                error('analyzeAFM_FM_components:AFMAreaLengthMismatch', ...
                    'AFM area integration length mismatch at Tp=%.6g K: numel(xDip)=%d, numel(yDip)=%d', ...
                    Tp, numel(xDip), numel(yDip));
            end

            finiteDip = isfinite(xDip) & isfinite(yDip);
            xDip = xDip(finiteDip);
            yDip = yDip(finiteDip);

            if numel(xDip) < 2 || numel(yDip) < 2
                pauseRuns(i).AFM_area = NaN;
                warning('analyzeAFM_FM_components:AFMAreaInsufficientPoints', ...
                    'AFM area set to NaN at Tp=%.6g K due to insufficient dip points (numel(xDip)=%d, numel(yDip)=%d).', ...
                    Tp, numel(xDip), numel(yDip));
                continue;
            end

            pauseRuns(i).AFM_area = trapz(xDip, yDip);

            dTloc = median(diff(T(maskDip)));
            sigma_y = std(dipVals);
            pauseRuns(i).AFM_area_err = sqrt(numel(dipVals)) * sigma_y * dTloc;

            pauseRuns(i).AFM_amp = NaN;
            pauseRuns(i).AFM_amp_err = NaN;

        otherwise
            error('Unknown dipMetric: %s', dipMetric);
    end


    %% =====================================================
    % 4) FM plateau step + error
    %% =====================================================
    maskLow = isfinite(T) & ...
        (T > Tp - dip_window_K - FM_buffer_K - FM_plateau_K) & ...
        (T < Tp - dip_window_K - FM_buffer_K);

    maskHigh = isfinite(T) & ...
        (T > Tp + dip_window_K + FM_buffer_K) & ...
        (T < Tp + dip_window_K + FM_buffer_K + FM_plateau_K);

    if nnz(maskLow)>=3 && nnz(maskHigh)>=3
        lowVals  = dM_smooth(maskLow);
        highVals = dM_smooth(maskHigh);

        FM_low  = mean(lowVals,'omitnan');
        FM_high = mean(highVals,'omitnan');

        pauseRuns(i).FM_step_raw = FM_high - FM_low;
        pauseRuns(i).FM_step_mag = abs(pauseRuns(i).FM_step_raw);

        semL = std(lowVals,'omitnan') / sqrt(nnz(isfinite(lowVals)));
        semH = std(highVals,'omitnan') / sqrt(nnz(isfinite(highVals)));

        pauseRuns(i).FM_step_err = sqrt(semL^2 + semH^2);
    end

end
end
