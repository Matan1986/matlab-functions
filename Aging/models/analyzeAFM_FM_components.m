function pauseRuns = analyzeAFM_FM_components( ...
    pauseRuns, dip_window_K, smoothWindow_K, ...
    excludeLowT_FM, excludeLowT_K, ...
    FM_plateau_K, excludeLowT_mode, FM_buffer_K, dipMetric, cfg)

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
% Canonical sign layer:
%   DeltaM_signed = M_pause - M_noPause
%   dip_signed    = DeltaM_signed - DeltaM_smooth
%   FM_signed     is signed and may change sign physically
%   Rectified/absolute transforms are metrics, not canonical signed variables.
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
    dipMetric = 'height';   % ×‘×¨×™×¨×ª ×ž×—×“×œ
end
if nargin < 10 || ~isstruct(cfg)
    cfg = struct();
end
dipMetric = lower(string(dipMetric));
fmConvention = resolveFMConvention(cfg);
fmDefinition = resolveFMDefinitionText(fmConvention);

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
    pauseRuns(i).FM_signed     = NaN;
    pauseRuns(i).FMConvention  = char(fmConvention);
    pauseRuns(i).FM_definition_used = fmDefinition;
    pauseRuns(i).FM_step_err   = NaN;
    pauseRuns(i).FM_plateau_valid = false;
    pauseRuns(i).FM_plateau_reason = '';
    pauseRuns(i).FM_plateau_left_window_raw = [NaN NaN];
    pauseRuns(i).FM_plateau_left_window = [NaN NaN];
    pauseRuns(i).FM_plateau_right_window = [NaN NaN];
    pauseRuns(i).FM_plateau_left_clipped = false;
    pauseRuns(i).FM_plateau_n_left = 0;
    pauseRuns(i).FM_plateau_n_right = 0;
    pauseRuns(i).FM_plateau_geometry_source = "stage4";
    pauseRuns(i).FM_plateau_left_width_K = NaN;
    pauseRuns(i).FM_plateau_right_width_K = NaN;
    pauseRuns(i).FM_plateau_left_slope = NaN;
    pauseRuns(i).FM_plateau_right_slope = NaN;
    pauseRuns(i).FM_plateau_meets_minCriteria = false;
    pauseRuns(i).FM_plateau_narrow_fallback = false;

    if ~isfield(pauseRuns(i),'T_common') || ~isfield(pauseRuns(i),'DeltaM')
        continue;
    end

    T  = pauseRuns(i).T_common(:);
    % Analysis observable used by current pipeline logic (legacy-compatible).
    dM = pauseRuns(i).DeltaM(:);
    % Canonical physical DeltaM (project-locked): M_pause - M_noPause.
    if isfield(pauseRuns(i), 'DeltaM_signed') && ~isempty(pauseRuns(i).DeltaM_signed)
        DeltaM_signed = pauseRuns(i).DeltaM_signed(:);
        pauseRuns(i).DeltaM_signed_source = 'input_canonical';
    else
        DeltaM_signed = dM;
        pauseRuns(i).DeltaM_signed_source = 'fallback_from_DeltaM_observable';
    end
    if numel(DeltaM_signed) ~= numel(dM)
        DeltaM_signed = dM;
        pauseRuns(i).DeltaM_signed_source = 'fallback_length_mismatch';
    end
    pauseRuns(i).DeltaM_signed = DeltaM_signed;
    pauseRuns(i).DeltaM_definition_canonical = 'DeltaM = M_{pause} - M_{no-pause}';
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
    % Residual of the active analysis observable (legacy-compatible).
    dM_sharp = dM - dM_smooth;
    % Canonical physical dip (project-locked):
    %   dip_signed = DeltaM_signed - DeltaM_smooth
    dip_signed = DeltaM_signed - dM_smooth;

    pauseRuns(i).DeltaM_smooth = dM_smooth;
    pauseRuns(i).DeltaM_sharp  = dM_sharp;
    pauseRuns(i).DeltaM_sharp_observable = dM_sharp;
    pauseRuns(i).dip_signed    = dip_signed;
    pauseRuns(i).dip_definition_canonical = 'dip_signed = DeltaM_signed - DeltaM_smooth';

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
            pauseRuns(i).AFM_amp = mean(dipVals);
            pauseRuns(i).AFM_amp_err = std(dipVals) / sqrt(numel(dipVals));
            pauseRuns(i).AFM_area = NaN;
            pauseRuns(i).AFM_area_err = NaN;

        case "area"
            % ----- dip as integrated weight -----
            % NOTE: this is a rectified metric transform, not canonical signed dip.
            y = max(0, dM_sharp);
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
    % 4) FM plateau step + error (robust baseline estimation)
    %% =====================================================
    
    % --- Try robust baseline estimation first ---
    useRobustBaseline = false;
    if nargin >= 10 && isstruct(cfg)
        if isfield(cfg, 'useRobustBaseline')
            useRobustBaseline = cfg.useRobustBaseline;
        end
    end
    
    if useRobustBaseline
        % Set up baseline config with defaults
        cfg_baseline = struct();
        cfg_baseline.dip_halfwidth_K = dip_window_K;
        
        if isfield(cfg, 'dip_margin_K')
            cfg_baseline.dip_margin_K = cfg.dip_margin_K;
        else
            cfg_baseline.dip_margin_K = 2;  % default margin
        end
        
        if isfield(cfg, 'plateau_nPoints')
            cfg_baseline.plateau_nPoints = cfg.plateau_nPoints;
        else
            cfg_baseline.plateau_nPoints = 6;  % default
        end
        if isfield(cfg, 'FM_plateau_minWidth_K')
            cfg_baseline.plateau_minWidth_K = cfg.FM_plateau_minWidth_K;
        end
        if isfield(cfg, 'FM_plateau_minPoints')
            cfg_baseline.plateau_minPoints = cfg.FM_plateau_minPoints;
        end
        if isfield(cfg, 'FM_plateau_maxAllowedSlope')
            cfg_baseline.plateau_maxAllowedSlope = cfg.FM_plateau_maxAllowedSlope;
        end
        if isfield(cfg, 'FM_plateau_allowNarrowFallback')
            cfg_baseline.plateau_allowNarrowFallback = cfg.FM_plateau_allowNarrowFallback;
        end
        
        % Call robust baseline estimator
        baselineOut = estimateRobustBaseline(T, dM, Tp, cfg_baseline);
        if isfield(baselineOut, 'idxL') && ~isempty(baselineOut.idxL)
            pauseRuns(i).FM_plateau_left_window_raw = [min(T(baselineOut.idxL)), max(T(baselineOut.idxL))];
            pauseRuns(i).FM_plateau_left_window = pauseRuns(i).FM_plateau_left_window_raw;
            pauseRuns(i).FM_plateau_n_left = numel(baselineOut.idxL);
        end
        if isfield(baselineOut, 'idxR') && ~isempty(baselineOut.idxR)
            pauseRuns(i).FM_plateau_right_window = [min(T(baselineOut.idxR)), max(T(baselineOut.idxR))];
            pauseRuns(i).FM_plateau_n_right = numel(baselineOut.idxR);
        end
        pauseRuns(i).FM_plateau_left_clipped = false;
        
        if strcmp(baselineOut.status, 'ok')
            % FM CONVENTION OPTIONS:
            %   'rightMinusLeft' -> baseR - baseL
            %   'leftMinusRight' -> baseL - baseR
            % CURRENT PROJECT DEFAULT: FM = baseL - baseR
            pauseRuns(i).FM_step_raw = computeFMFromBases(baselineOut.baseL, baselineOut.baseR, fmConvention);
            % SIGNED PHYSICAL VARIABLE â€” DO NOT MODIFY SIGN
            % FM_signed is a signed physical background/step quantity.
            % Its sign is physically meaningful and may change between runs.
            FM_signed = pauseRuns(i).FM_step_raw;
            pauseRuns(i).FM_signed = FM_signed;
            pauseRuns(i).FM_step_mag = pauseRuns(i).FM_step_raw;
            pauseRuns(i).FM_step_err = NaN;  % Not computed in robust version
            pauseRuns(i).FM_plateau_valid = true;
            pauseRuns(i).FM_plateau_reason = '';
            if pauseRuns(i).FM_plateau_narrow_fallback
                pauseRuns(i).FM_plateau_reason = 'narrow_fallback';
            end
            pauseRuns(i).baseline_TL = baselineOut.TL;
            pauseRuns(i).baseline_TR = baselineOut.TR;
            pauseRuns(i).baseline_slope = baselineOut.slope;
            pauseRuns(i).baseline_status = baselineOut.status;
            if isfield(baselineOut, 'plateauL_width_K')
                pauseRuns(i).FM_plateau_left_width_K = baselineOut.plateauL_width_K;
            end
            if isfield(baselineOut, 'plateauR_width_K')
                pauseRuns(i).FM_plateau_right_width_K = baselineOut.plateauR_width_K;
            end
            if isfield(baselineOut, 'plateauL_slope')
                pauseRuns(i).FM_plateau_left_slope = baselineOut.plateauL_slope;
            end
            if isfield(baselineOut, 'plateauR_slope')
                pauseRuns(i).FM_plateau_right_slope = baselineOut.plateauR_slope;
            end
            if isfield(baselineOut, 'plateauCriteriaSatisfied')
                pauseRuns(i).FM_plateau_meets_minCriteria = logical(baselineOut.plateauCriteriaSatisfied);
            end
            if isfield(baselineOut, 'narrowFallback')
                pauseRuns(i).FM_plateau_narrow_fallback = logical(baselineOut.narrowFallback);
            end
            if pauseRuns(i).FM_plateau_narrow_fallback && isempty(pauseRuns(i).FM_plateau_reason)
                pauseRuns(i).FM_plateau_reason = 'narrow_fallback';
            end
            if isfield(baselineOut, 'idxL') && ~isempty(baselineOut.idxL)
                pauseRuns(i).FM_plateau_left_window_raw = [min(T(baselineOut.idxL)), max(T(baselineOut.idxL))];
                pauseRuns(i).FM_plateau_left_window = pauseRuns(i).FM_plateau_left_window_raw;
                pauseRuns(i).FM_plateau_n_left = numel(baselineOut.idxL);
            end
            if isfield(baselineOut, 'idxR') && ~isempty(baselineOut.idxR)
                pauseRuns(i).FM_plateau_right_window = [min(T(baselineOut.idxR)), max(T(baselineOut.idxR))];
                pauseRuns(i).FM_plateau_n_right = numel(baselineOut.idxR);
            end
            pauseRuns(i).FM_plateau_left_clipped = false;
            
            % Verbose diagnostics
            if isfield(cfg, 'debug') && isfield(cfg.debug, 'verbose') && cfg.debug.verbose
                fprintf('  Dip baseline [Tp=%.4g K]:\n', Tp);
                fprintf('    Tmin=%.4g, dip_window=[%.4g,%.4g]\n', ...
                    Tp, Tp-dip_window_K, Tp+dip_window_K);
                fprintf('    plateau_L: T=[%.4g,%.4g], n=%d\n', ...
                    min(T(baselineOut.idxL)), max(T(baselineOut.idxL)), numel(baselineOut.idxL));
                fprintf('    plateau_R: T=[%.4g,%.4g], n=%d\n', ...
                    min(T(baselineOut.idxR)), max(T(baselineOut.idxR)), numel(baselineOut.idxR));
                fprintf('    baseL=%.6g, baseR=%.6g, slope=%.6g\n', ...
                    baselineOut.baseL, baselineOut.baseR, baselineOut.slope);
                fprintf('    plateau width/slope: L=[%.4g K, %.6g], R=[%.4g K, %.6g], criteria=%d, narrowFallback=%d\n', ...
                    pauseRuns(i).FM_plateau_left_width_K, pauseRuns(i).FM_plateau_left_slope, ...
                    pauseRuns(i).FM_plateau_right_width_K, pauseRuns(i).FM_plateau_right_slope, ...
                    pauseRuns(i).FM_plateau_meets_minCriteria, pauseRuns(i).FM_plateau_narrow_fallback);
            end
        else
            % Robust baseline failed, fall back to old method
            pauseRuns(i).FM_step_raw = NaN;
            pauseRuns(i).FM_step_mag = NaN;
            pauseRuns(i).FM_step_err = NaN;
            pauseRuns(i).FM_plateau_valid = false;
            pauseRuns(i).FM_plateau_reason = sprintf('robust_baseline_failed: %s', baselineOut.status);
            continue;
        end
    else
        % --- Original plateau window logic ---
        % Check for fixed right plateau mode
        useFixedRightPlateau = false;
        if nargin >= 10 && isstruct(cfg)
            if isfield(cfg, 'FM_rightPlateauMode') && strcmpi(cfg.FM_rightPlateauMode, 'fixed')
                useFixedRightPlateau = true;
            elseif isfield(cfg, 'fmMetric') && isfield(cfg.fmMetric, 'rightWindow')
                useFixedRightPlateau = true;
            end
        end

        % Fix: clamp plateau windows to data range and track validity.
        finiteT = T(isfinite(T));
        if isempty(finiteT)
            Tmin_data = -inf;
            Tmax_data = inf;
        else
            Tmin_data = min(finiteT);
            Tmax_data = max(finiteT);
        end
        Nmin = 3;
        
        if useFixedRightPlateau
            lowWin_raw = [Tp - dip_window_K - FM_buffer_K - FM_plateau_K, ...
                          Tp - dip_window_K - FM_buffer_K];
            lowWin_req = lowWin_raw;
            lowWin_clipped_by_lowT = false;
            if excludeLowT_FM && isfinite(excludeLowT_K)
                lowWin_req = [max(excludeLowT_K, lowWin_raw(1)), ...
                              max(excludeLowT_K, lowWin_raw(2))];
                lowWin_clipped_by_lowT = any(lowWin_req ~= lowWin_raw);
            end

            % Fixed high-temperature FM background window
            if isfield(cfg, 'FM_rightPlateauFixedWindow_K') && ~isempty(cfg.FM_rightPlateauFixedWindow_K)
                highWin = cfg.FM_rightPlateauFixedWindow_K(:).';
            elseif isfield(cfg, 'fmMetric') && isfield(cfg.fmMetric, 'rightWindow')
                highWin = cfg.fmMetric.rightWindow(:).';
            else
                error('Fixed right plateau mode enabled but no window defined');
            end
            [highWin, ~] = clampWindow(highWin, Tmin_data, Tmax_data);
            idx_bg = T >= highWin(1) & T <= highWin(2);

            % Safety check for too-small window
            if nnz(idx_bg) < 5
                error('FM background window too small or outside data range.');
            end

            % Use fixed window as high-T reference
            maskHigh = isfinite(T) & idx_bg;
            [lowWin, lowWin_clamped_data] = clampWindow(lowWin_req, Tmin_data, Tmax_data);
            maskLow = isfinite(T) & (T > lowWin(1)) & (T < lowWin(2));
        else
            % Default Tp-dependent plateau window logic
            lowWin_raw = [Tp - dip_window_K - FM_buffer_K - FM_plateau_K, ...
                          Tp - dip_window_K - FM_buffer_K];
            lowWin_req = lowWin_raw;
            lowWin_clipped_by_lowT = false;
            if excludeLowT_FM && isfinite(excludeLowT_K)
                lowWin_req = [max(excludeLowT_K, lowWin_raw(1)), ...
                              max(excludeLowT_K, lowWin_raw(2))];
                lowWin_clipped_by_lowT = any(lowWin_req ~= lowWin_raw);
            end

            highWin = [Tp + dip_window_K + FM_buffer_K, ...
                       Tp + dip_window_K + FM_buffer_K + FM_plateau_K];
            [lowWin, lowWin_clamped_data] = clampWindow(lowWin_req, Tmin_data, Tmax_data);
            [highWin, ~] = clampWindow(highWin, Tmin_data, Tmax_data);

            maskLow = isfinite(T) & (T > lowWin(1)) & (T < lowWin(2));
            maskHigh = isfinite(T) & (T > highWin(1)) & (T < highWin(2));
        end

        pauseRuns(i).FM_plateau_left_window_raw = lowWin_raw;
        pauseRuns(i).FM_plateau_left_window = lowWin;
        pauseRuns(i).FM_plateau_right_window = highWin;
        pauseRuns(i).FM_plateau_left_clipped = logical(lowWin_clipped_by_lowT || lowWin_clamped_data);
        pauseRuns(i).FM_plateau_n_left = nnz(maskLow);
        pauseRuns(i).FM_plateau_n_right = nnz(maskHigh);
        pauseRuns(i).FM_plateau_geometry_source = "stage4";
        [leftWidthK, leftSlopeK] = computeMaskWidthSlope(T, dM_smooth, maskLow);
        [rightWidthK, rightSlopeK] = computeMaskWidthSlope(T, dM_smooth, maskHigh);
        pauseRuns(i).FM_plateau_left_width_K = leftWidthK;
        pauseRuns(i).FM_plateau_right_width_K = rightWidthK;
        pauseRuns(i).FM_plateau_left_slope = leftSlopeK;
        pauseRuns(i).FM_plateau_right_slope = rightSlopeK;
        minWidthReq = 0;
        if nargin >= 10 && isstruct(cfg) && isfield(cfg, 'FM_plateau_minWidth_K')
            minWidthReq = cfg.FM_plateau_minWidth_K;
        end
        minPointsReq = Nmin;
        if nargin >= 10 && isstruct(cfg) && isfield(cfg, 'FM_plateau_minPoints')
            minPointsReq = max(Nmin, cfg.FM_plateau_minPoints);
        end
        maxSlopeReq = inf;
        if nargin >= 10 && isstruct(cfg) && isfield(cfg, 'FM_plateau_maxAllowedSlope')
            maxSlopeReq = abs(cfg.FM_plateau_maxAllowedSlope);
        end
        if ~isfinite(maxSlopeReq) || maxSlopeReq <= 0
            maxSlopeReq = inf;
        end
        meetsCriteria = ...
            (pauseRuns(i).FM_plateau_n_left >= minPointsReq) && ...
            (pauseRuns(i).FM_plateau_n_right >= minPointsReq) && ...
            isfinite(leftWidthK) && isfinite(rightWidthK) && ...
            (leftWidthK >= minWidthReq) && (rightWidthK >= minWidthReq) && ...
            isfinite(leftSlopeK) && isfinite(rightSlopeK) && ...
            (abs(leftSlopeK) <= maxSlopeReq) && (abs(rightSlopeK) <= maxSlopeReq);
        pauseRuns(i).FM_plateau_meets_minCriteria = logical(meetsCriteria);
        pauseRuns(i).FM_plateau_narrow_fallback = ~pauseRuns(i).FM_plateau_meets_minCriteria;

        if nargin >= 10 && isstruct(cfg) && isfield(cfg, 'debug') && isfield(cfg.debug, 'enable') && cfg.debug.enable
            fprintf(['FM plateau geometry [Tp=%.4g K]: left=[%.4g, %.4g], right=[%.4g, %.4g], ' ...
                     'clipped=%d, nL=%d, nR=%d, widthL=%.4g K, widthR=%.4g K, ' ...
                     'slopeL=%.6g, slopeR=%.6g, meetsCriteria=%d, narrowFallback=%d\n'], ...
                Tp, lowWin(1), lowWin(2), highWin(1), highWin(2), ...
                pauseRuns(i).FM_plateau_left_clipped, pauseRuns(i).FM_plateau_n_left, pauseRuns(i).FM_plateau_n_right, ...
                pauseRuns(i).FM_plateau_left_width_K, pauseRuns(i).FM_plateau_right_width_K, ...
                pauseRuns(i).FM_plateau_left_slope, pauseRuns(i).FM_plateau_right_slope, ...
                pauseRuns(i).FM_plateau_meets_minCriteria, pauseRuns(i).FM_plateau_narrow_fallback);
        end

        plateauWinInvalid = (lowWin(2) <= lowWin(1)) || (highWin(2) <= highWin(1));
        validPlateau = ~plateauWinInvalid && (nnz(maskLow) >= Nmin) && (nnz(maskHigh) >= Nmin);
        if ~validPlateau
            pauseRuns(i).FM_step_raw = NaN;
            pauseRuns(i).FM_step_mag = NaN;
            pauseRuns(i).FM_step_err = NaN;
            if isfield(pauseRuns(i), 'FM_step_A')
                pauseRuns(i).FM_step_A = NaN;
            end
            if isfield(pauseRuns(i), 'FM_A')
                pauseRuns(i).FM_A = NaN;
            end
            if isfield(pauseRuns(i), 'FM_area_abs')
                pauseRuns(i).FM_area_abs = NaN;
            end
            pauseRuns(i).FM_plateau_valid = false;
            pauseRuns(i).FM_plateau_reason = 'plateau_invalid_or_insufficient';
            continue;
        end

        pauseRuns(i).FM_plateau_valid = true;
        pauseRuns(i).FM_plateau_reason = '';
        if pauseRuns(i).FM_plateau_narrow_fallback
            pauseRuns(i).FM_plateau_reason = 'narrow_fallback';
        end

        if nnz(maskLow)>=3 && nnz(maskHigh)>=3
            lowVals  = dM_smooth(maskLow);
            highVals = dM_smooth(maskHigh);

            FM_low  = mean(lowVals,'omitnan');
            FM_high = mean(highVals,'omitnan');

            pauseRuns(i).FM_step_raw = computeFMFromBases(FM_low, FM_high, fmConvention);
            % SIGNED PHYSICAL VARIABLE â€” DO NOT MODIFY SIGN
            % FM_signed is a signed physical background/step quantity.
            % Its sign is physically meaningful and may change between runs.
            FM_signed = pauseRuns(i).FM_step_raw;
            pauseRuns(i).FM_signed = FM_signed;
            pauseRuns(i).FM_step_mag = pauseRuns(i).FM_step_raw;  % Keep raw signed value

            semL = std(lowVals,'omitnan') / sqrt(nnz(isfinite(lowVals)));
            semH = std(highVals,'omitnan') / sqrt(nnz(isfinite(highVals)));

            pauseRuns(i).FM_step_err = sqrt(semL^2 + semH^2);
        end
    end  % end of old method else

end
end

function fmConvention = resolveFMConvention(cfg)
fmConvention = "leftMinusRight";
if isstruct(cfg) && isfield(cfg, 'FMConvention') && ~isempty(cfg.FMConvention)
    fmConvention = string(cfg.FMConvention);
end
fmConvention = lower(fmConvention);
switch fmConvention
    case {"rightminusleft", "leftminusright"}
        return;
    otherwise
        error('Unknown FMConvention: %s', fmConvention);
end
end

function fmValue = computeFMFromBases(baseL, baseR, fmConvention)
switch lower(string(fmConvention))
    case "rightminusleft"
        fmValue = baseR - baseL;
    case "leftminusright"
        fmValue = baseL - baseR;
    otherwise
        error('Unknown FMConvention: %s', string(fmConvention));
end
end

function txt = resolveFMDefinitionText(fmConvention)
switch lower(string(fmConvention))
    case "rightminusleft"
        txt = 'FM = baseR - baseL';
    case "leftminusright"
        txt = 'FM = baseL - baseR';
    otherwise
        error('Unknown FMConvention: %s', string(fmConvention));
end
end

function [winOut, changed] = clampWindow(winIn, Tmin, Tmax)
% Clamp window bounds to data range (robust plateau validity).
changed = false;
if isempty(winIn) || numel(winIn) ~= 2 || any(~isfinite(winIn)) || ~isfinite(Tmin) || ~isfinite(Tmax)
    winOut = winIn;
    return;
end
winOut = winIn;
lo = max(min(winIn), Tmin);
hi = min(max(winIn), Tmax);
if lo ~= winIn(1) || hi ~= winIn(2)
    changed = true;
end
winOut(1) = lo;
winOut(2) = hi;
end
function [widthK, slopeK] = computeMaskWidthSlope(T, Y, mask)
widthK = NaN;
slopeK = NaN;

if isempty(mask) || ~any(mask)
    return;
end

idx = find(mask);
Tseg = T(idx);
Yseg = Y(idx);
valid = isfinite(Tseg) & isfinite(Yseg);
Tseg = Tseg(valid);
Yseg = Yseg(valid);

if numel(Tseg) < 2
    return;
end

widthK = max(Tseg) - min(Tseg);
if ~isfinite(widthK)
    widthK = NaN;
end

if numel(unique(Tseg)) >= 2
    p = polyfit(Tseg, Yseg, 1);
    slopeK = p(1);
else
    slopeK = 0;
end

if ~isfinite(slopeK)
    slopeK = NaN;
end
end

