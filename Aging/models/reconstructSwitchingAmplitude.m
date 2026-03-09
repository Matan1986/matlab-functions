function result = reconstructSwitchingAmplitude(mode, pauseRuns, pauseRuns_raw, params, Tp, Tsw, Rsw)
% =========================================================
% reconstructSwitchingAmplitude
%
% PURPOSE:
%   Reconstruct switching amplitude from aging memory metrics.
%
% INPUTS:
%   mode         - 'experimental' or 'fit'
%   pauseRuns    - struct array with pause data
%   pauseRuns_raw- raw pauseRuns for FM metric (fit mode)
%   params       - parameter struct (fit windows, lambda scan, etc.)
%   Tp           - pause temperatures
%   Tsw          - switching temperature grid
%   Rsw          - measured switching amplitude
%
% OUTPUTS:
%   result       - struct with reconstructed Rhat, lambda, a, b, R2, and bases
%
% Physics meaning:
%   AFM = low-manifold dip metric (memory dip)
%   FM  = high-manifold background metric (step-like)
%
% =========================================================

% Ensure column vectors
Tp  = Tp(:);
Tsw = Tsw(:);
Rsw = Rsw(:);

% Lightweight assertions (do not alter numeric behavior)
assert(isfield(pauseRuns, 'DeltaM'), 'pauseRuns missing DeltaM');

% ===============================
% Feature toggle: J-dependent extension
% ===============================
if ~isfield(params, 'enableJModel')
    params.enableJModel = false;
end

if ~isfield(params, 'Jmodel')
    params.Jmodel = struct();
end

% Defaults for J-dependent shift/gating (backward compatible)
if ~isfield(params, 'alpha')
    params.alpha = 0;
end
if ~isfield(params, 'J0')
    params.J0 = 0;
end
if ~isfield(params, 'Jc')
    params.Jc = 0;
end
if ~isfield(params, 'dJ') || params.dJ == 0
    params.dJ = 1;
end

% ===============================
% Extract aging metrics
% ===============================
nPauses = numel(pauseRuns);
AFM_metric = zeros(nPauses,1);
FM_metric_signed = NaN(nPauses,1);
FM_metric_mag = NaN(nPauses,1);

if ~isfield(params, 'FM_source') || isempty(params.FM_source)
    params.FM_source = 'stage7_recompute';  % default: preserve legacy behavior
end
FM_source = lower(string(params.FM_source));

switch lower(mode)

    case 'experimental'

    for i = 1:nPauses

        pr = pauseRuns(i);

        T = pr.T_common(:);
        DeltaM = pr.DeltaM(:);
        Tp_i = Tp(i);

        dip_mask = abs(T - Tp_i) <= params.dipWindowK;

        % --- baseline (excluding dip window)
        T_base = T(~dip_mask);
        M_base = DeltaM(~dip_mask);

        if numel(T_base) > 2
            p = polyfit(T_base, M_base, 1);
            baseline = polyval(p, T);
        else
            baseline = mean(DeltaM);
        end

        % ===============================
        % 1) AFM metric ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â dip area
        % ===============================
        dip_signal = DeltaM(dip_mask) - baseline(dip_mask);
        dip_mag = abs(dip_signal);

        if numel(dip_mag) >= 2
            AFM_metric(i) = trapz(T(dip_mask), dip_mag);
        elseif numel(dip_mag) == 1
            AFM_metric(i) = dip_mag;
        else
            AFM_metric(i) = NaN;
        end

                % ===============================
        % 2) FM metric
        % ===============================
        if FM_source == "stage4"
            if isfield(pr, 'FM_signed') && ~isempty(pr.FM_signed) && isfinite(pr.FM_signed)
                F_raw_signed = double(pr.FM_signed);
            elseif isfield(pr, 'FM_step_raw') && ~isempty(pr.FM_step_raw) && isfinite(pr.FM_step_raw)
                F_raw_signed = double(pr.FM_step_raw);
            elseif isfield(pr, 'FM_step_mag') && ~isempty(pr.FM_step_mag) && isfinite(pr.FM_step_mag)
                F_raw_signed = double(pr.FM_step_mag);
            else
                F_raw_signed = NaN;
            end

            if isfinite(F_raw_signed)
                FM_metric_signed(i) = F_raw_signed;
                if isfield(pr, 'FM_abs') && ~isempty(pr.FM_abs) && isfinite(pr.FM_abs)
                    FM_metric_mag(i) = double(pr.FM_abs);
                else
                    F_raw_mag = abs(F_raw_signed);
                    FM_metric_mag(i) = F_raw_mag;
                end
            else
                FM_metric_signed(i) = NaN;
                FM_metric_mag(i) = NaN;
            end
        else
            wide_mask = abs(T - Tp_i) <= params.wideWindowK & ~dip_mask;

            sig = DeltaM - baseline;
            Twide = T(wide_mask);
            sigwide = sig(wide_mask);

            low  = sigwide(Twide < Tp_i);
            high = sigwide(Twide > Tp_i);

            if numel(low) > 2 && numel(high) > 2
                F_raw_signed = mean(high,'omitnan') - mean(low,'omitnan');
                FM_metric_signed(i) = F_raw_signed;
                F_raw_mag = abs(F_raw_signed);
                FM_metric_mag(i) = F_raw_mag;
            else
                FM_metric_signed(i) = NaN;
                FM_metric_mag(i) = NaN;
            end
        end

    end

    case 'fit'

    for i = 1:nPauses

        % ===============================
        % 1) AFM metric from fit
        % ===============================
        AFM_metric(i) = pauseRuns(i).Dip_area;

                % ===============================
        % 2) FM metric source
        % ===============================
        if FM_source == "stage4"
            if isfield(pauseRuns(i), 'FM_signed') && ~isempty(pauseRuns(i).FM_signed) && isfinite(pauseRuns(i).FM_signed)
                F_raw_signed = double(pauseRuns(i).FM_signed);
            elseif isfield(pauseRuns(i), 'FM_step_raw') && ~isempty(pauseRuns(i).FM_step_raw) && isfinite(pauseRuns(i).FM_step_raw)
                F_raw_signed = double(pauseRuns(i).FM_step_raw);
            elseif isfield(pauseRuns(i), 'FM_step_mag') && ~isempty(pauseRuns(i).FM_step_mag) && isfinite(pauseRuns(i).FM_step_mag)
                F_raw_signed = double(pauseRuns(i).FM_step_mag);
            else
                F_raw_signed = NaN;
            end

            if isfinite(F_raw_signed)
                FM_metric_signed(i) = F_raw_signed;
                if isfield(pauseRuns(i), 'FM_abs') && ~isempty(pauseRuns(i).FM_abs) && isfinite(pauseRuns(i).FM_abs)
                    FM_metric_mag(i) = double(pauseRuns(i).FM_abs);
                else
                    F_raw_mag = abs(F_raw_signed);
                    FM_metric_mag(i) = F_raw_mag;
                end
            else
                FM_metric_signed(i) = NaN;
                FM_metric_mag(i) = NaN;
            end
        else
            pr = pauseRuns_raw(i);

            T = pr.T_common(:);
            DeltaM = pr.DeltaM(:);
            Tp_i = Tp(i);

            dip_mask = abs(T - Tp_i) <= params.dipWindowK;

            % baseline excluding dip
            T_base = T(~dip_mask);
            M_base = DeltaM(~dip_mask);

            if numel(T_base) > 2
                p = polyfit(T_base, M_base, 1);
                baseline = polyval(p, T);
            else
                baseline = mean(DeltaM);
            end

            wide_mask = abs(T - Tp_i) <= params.wideWindowK & ~dip_mask;

            sig = DeltaM - baseline;
            Twide = T(wide_mask);
            sigwide = sig(wide_mask);

            low  = sigwide(Twide < Tp_i);
            high = sigwide(Twide > Tp_i);

            if numel(low) > 2 && numel(high) > 2
                F_raw_signed = mean(high,'omitnan') - mean(low,'omitnan');
                FM_metric_signed(i) = F_raw_signed;
                F_raw_mag = abs(F_raw_signed);
                FM_metric_mag(i) = F_raw_mag;
            else
                FM_metric_signed(i) = NaN;
                FM_metric_mag(i) = NaN;
            end
        end

    end
end

% ===============================
% Interpolate to switching grid
% ===============================
Dp = AFM_metric;
Fp_signed = FM_metric_signed;
Fp_mag = FM_metric_mag;

% Initialize signed FM flag (default: false to preserve existing behavior)
if ~isfield(params, 'allowSignedFM')
    params.allowSignedFM = false;
end

if params.allowSignedFM
    Fp = Fp_signed;
else
    Fp = Fp_mag;
end

fprintf('Dp>0: %d / %d\n', nnz(Dp>0), numel(Dp));
fprintf('Fp>0: %d / %d\n', nnz(Fp_mag>0 & isfinite(Fp_mag)), numel(Fp_mag));
disp(table(Tp(:), Dp(:), Fp(:), 'VariableNames',{'Tp','Dp','Fp'}));
fprintf('allowSignedFM = %d\n', params.allowSignedFM);
fprintf('FM_source = %s\n', params.FM_source);

% Interpolation mode configuration (PR7)
if ~isfield(params, 'interp')
    params.interp = struct();
end
if ~isfield(params.interp, 'mode')
    params.interp.mode = 'pchip';  % default: pchip
end
if ~isfield(params.interp, 'allowExtrap')
    params.interp.allowExtrap = true;  % default: allow extrapolation
end
epsFp = 1e-15;  % Ãƒâ€”Ã‚ÂÃƒâ€”Ã¢â‚¬Â¢ 1e-14 Ãƒâ€”Ã…â€œÃƒâ€”Ã‚Â¤Ãƒâ€”Ã¢â€žÂ¢ Ãƒâ€”Ã‚Â¡Ãƒâ€”Ã¢â‚¬Å“Ãƒâ€”Ã‚Â¨Ãƒâ€”Ã¢â€žÂ¢ Ãƒâ€”Ã¢â‚¬ÂÃƒâ€”Ã¢â‚¬â„¢Ãƒâ€”Ã¢â‚¬Â¢Ãƒâ€”Ã¢â‚¬Å“Ãƒâ€”Ã…â€œ Ãƒâ€”Ã‚ÂÃƒâ€”Ã‚Â¦Ãƒâ€”Ã…â€œÃƒâ€”Ã…Â¡
valid = (Dp>0) & isfinite(Fp_mag) & (Fp_mag > epsFp);


% --- Optional pause-temperature exclusion (diagnostic sensitivity analysis) ---
if isfield(params, 'switchExcludeTp') && ~isempty(params.switchExcludeTp)
    excludeMask = ismember(Tp, params.switchExcludeTp);
    valid = valid & ~excludeMask;
    fprintf('Excluded Tp values: %s\n', mat2str(params.switchExcludeTp));
end
if isfield(params, 'switchExcludeTpAbove') && ~isempty(params.switchExcludeTpAbove)
    excludeMask = Tp > params.switchExcludeTpAbove;
    valid = valid & ~excludeMask;
    fprintf('Excluded Tp > %.1f K\n', params.switchExcludeTpAbove);
end

Tp = Tp(valid);
Dp = Dp(valid);
Fp = Fp(valid);
Fp_signed = Fp_signed(valid);
Fp_mag = Fp_mag(valid);

fprintf('Number of valid pauses after filtering: %d\n', numel(Tp));

% Store filtered pause vectors for Phase C export (before any interpolation)
Tp_pause_export = Tp(:);
Dp_pause_export = Dp(:);
Fp_pause_export = Fp(:);
Fp_pause_signed_export = Fp_signed(:);
Fp_pause_abs_export = Fp_mag(:);

% --- Interpolate to switching grid (RAW first) ---
switch params.interp.mode
    case 'pchip'
        if params.interp.allowExtrap
            D_interp_raw = interp1(Tp, Dp, Tsw, 'pchip', 'extrap');
            F_interp_raw_signed = interp1(Tp, Fp_signed, Tsw, 'pchip', 'extrap');
            F_interp_raw_mag = interp1(Tp, Fp_mag, Tsw, 'pchip', 'extrap');
        else
            D_interp_raw = interp1(Tp, Dp, Tsw, 'pchip', NaN);
            F_interp_raw_signed = interp1(Tp, Fp_signed, Tsw, 'pchip', NaN);
            F_interp_raw_mag = interp1(Tp, Fp_mag, Tsw, 'pchip', NaN);
        end
    case 'linear'
        if params.interp.allowExtrap
            D_interp_raw = interp1(Tp, Dp, Tsw, 'linear', 'extrap');
            F_interp_raw_signed = interp1(Tp, Fp_signed, Tsw, 'linear', 'extrap');
            F_interp_raw_mag = interp1(Tp, Fp_mag, Tsw, 'linear', 'extrap');
        else
            D_interp_raw = interp1(Tp, Dp, Tsw, 'linear', NaN);
            F_interp_raw_signed = interp1(Tp, Fp_signed, Tsw, 'linear', NaN);
            F_interp_raw_mag = interp1(Tp, Fp_mag, Tsw, 'linear', NaN);
        end
    case 'nearest'
        % nearest doesn't support extrapolation argument
        D_interp_raw = interp1(Tp, Dp, Tsw, 'nearest');
        F_interp_raw_signed = interp1(Tp, Fp_signed, Tsw, 'nearest');
        F_interp_raw_mag = interp1(Tp, Fp_mag, Tsw, 'nearest');
    otherwise
        error('Invalid interp.mode: %s (must be pchip, linear, or nearest)', params.interp.mode);
end

if params.allowSignedFM
    F_interp_raw = F_interp_raw_signed;
    F_interp_for_basis = abs(F_interp_raw_signed);
else
    F_interp_raw = F_interp_raw_mag;
    F_interp_for_basis = F_interp_raw_mag;
end

% --- Interpolation artifact diagnostics ---
if isfield(params, 'debug') && isstruct(params.debug) && isfield(params.debug, 'verbose') && params.debug.verbose
    overshoot_D = max(D_interp_raw) - max(Dp);
    undershoot_D = min(D_interp_raw);
    overshoot_F = max(F_interp_raw) - max(Fp);
    undershoot_F = min(F_interp_raw);
    
    Tmin = min(Tp);
    Tmax = max(Tp);
    extrap_low = sum(Tsw < Tmin);
    extrap_high = sum(Tsw > Tmax);
    
    fprintf('Interpolation diagnostics:\n');
    fprintf('  D overshoot = %.4g\n', overshoot_D);
    fprintf('  D undershoot = %.4g\n', undershoot_D);
    fprintf('  F overshoot = %.4g\n', overshoot_F);
    fprintf('  F undershoot = %.4g\n', undershoot_F);
    fprintf('  Extrapolation points: low=%d, high=%d (out of %d total)\n', extrap_low, extrap_high, numel(Tsw));
end

% --- Legacy pipeline keeps the original behavior (clamp to >=0) ---
% Count clamps before applying them (PR?ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â Clamp diagnostics)
nClampLow_D = nnz(D_interp_raw < 0);
nClampLow_F = nnz(F_interp_for_basis < 0);
D_interp = max(D_interp_raw, 0);
F_interp = max(F_interp_for_basis, 0);

% Initialize all clamp counters before any debug prints
nClampLow_Dn = 0;
nClampHigh_Dn = 0;
nClampLow_Fn = 0;
nClampHigh_Fn = 0;
nClampLow_coex = 0;
nClampHigh_coex = 0;

% ===============================
% Define masks (NO slicing - all vectors remain aligned with Tsw)
% ===============================
% mask_T: physics window defined by temperature bounds (e.g., fitTmin=3, fitTmax=32)
mask_T = (Tsw >= params.fitTmin) & (Tsw <= params.fitTmax);

% mask_SNR: applies SNR/noise floor filtering (configurable)
if ~isfield(params, 'snr') || isempty(params.snr)
    % Default: match historical behavior
    params.snr = struct('mode', 'relative', 'threshold', 0.02);
end

snr_mode = params.snr.mode;
snr_threshold = params.snr.threshold;

switch snr_mode
    case 'off'
        % No SNR masking
        mask_SNR = true(size(Rsw));
        nPoints_kept = numel(Rsw);
    case 'relative'
        % Relative to max of Rsw in physics window
        if ~any(mask_T)
            % Empty physics window: no SNR filtering possible, keep all points
            mask_SNR = true(size(Rsw));
        else
            noiseFloor = snr_threshold * max(Rsw(mask_T));
            mask_SNR = Rsw > noiseFloor;
        end
        nPoints_kept = nnz(mask_SNR);
    case 'absolute'
        % Absolute threshold
        mask_SNR = Rsw > snr_threshold;
        nPoints_kept = nnz(mask_SNR);
    otherwise
        error('Unknown SNR mode: %s. Use ''off'', ''relative'', or ''absolute''.', snr_mode);
end

% mask_fit: final fitting window = physics window AND above noise
mask_fit = mask_T & mask_SNR;

% mask_diag: diagnostic mask = all points (no restrictions)
mask_diag = true(size(Rsw));

% Verify all masks are same size as Tsw
assert(numel(mask_T) == numel(Tsw), 'mask_T size mismatch');
assert(numel(mask_SNR) == numel(Tsw), 'mask_SNR size mismatch');
assert(numel(mask_fit) == numel(Tsw), 'mask_fit size mismatch');
assert(numel(mask_diag) == numel(Tsw), 'mask_diag size mismatch');

% Debug output: SNR masking configuration
if isfield(params, 'debug') && isstruct(params.debug) && isfield(params.debug, 'verbose') && params.debug.verbose
    nPoints_total = numel(mask_T);
    nPoints_physics = nnz(mask_T);
    nPoints_snr = nnz(mask_SNR);
    nPoints_final = nnz(mask_fit);
    fprintf('SNR mask mode: %s\n', snr_mode);
    fprintf('SNR threshold: %.6g\n', snr_threshold);
    fprintf('Points: total=%d, physics_window=%d, above_snr=%d, final=%d / %d\n', ...
        nPoints_total, nPoints_physics, nPoints_snr, nPoints_final, nPoints_total);
    fprintf('Fit points: %d / %d\n', nnz(mask_fit), numel(mask_fit));
    fprintf('Diagnostic points: %d / %d\n', nnz(mask_diag), numel(mask_diag));
    
    % Coexistence suppression status
    if params.coexistence.suppressLowAB
        fprintf('Coexistence suppression: ON\n');
    else
        fprintf('Coexistence suppression: OFF\n');
    end
    
    % Interpolation mode and extrapolation
    fprintf('Interpolation mode: %s\n', params.interp.mode);
    if params.interp.allowExtrap
        fprintf('Extrapolation: ON\n');
    else
        fprintf('Extrapolation: OFF\n');
    end
    
    % Clamp diagnostics
    nClampLow_total = nClampLow_D + nClampLow_F + nClampLow_Dn + nClampLow_Fn + nClampLow_coex;
    nClampHigh_total = nClampHigh_Dn + nClampHigh_Fn + nClampHigh_coex;
    fprintf('\nClamp diagnostics:\n');
    fprintf('  Negative clamps: D=%d, F=%d, Dn=%d, Fn=%d, coex=%d (total=%d)\n', ...
        nClampLow_D, nClampLow_F, nClampLow_Dn, nClampLow_Fn, nClampLow_coex, nClampLow_total);
    fprintf('  Upper clamps: Dn=%d, Fn=%d, coex=%d (total=%d)\n', ...
        nClampHigh_Dn, nClampHigh_Fn, nClampHigh_coex, nClampHigh_total);
    
    % Report temperature locations of clamps (diagnostic)
    if nClampLow_total > 0 || nClampHigh_total > 0
        fprintf('  Temperature locations of clamps (first 5 each):\n');
        max_report = 5;
        
        % D_interp_raw < 0
        if nClampLow_D > 0
            idx_D = find(D_interp_raw < 0);
            idx_D_report = idx_D(1:min(max_report, numel(idx_D)));
            fprintf('    D_interp_raw < 0: Tsw = [');
            fprintf('%.2f ', Tsw(idx_D_report));
            fprintf('] K\n');
        end
        
        % Dn > 1
        if nClampHigh_Dn > 0
            idx_Dn = find(Dn > 1);
            idx_Dn_report = idx_Dn(1:min(max_report, numel(idx_Dn)));
            fprintf('    Dn > 1: Tsw = [');
            fprintf('%.2f ', Tsw(idx_Dn_report));
            fprintf('] K\n');
        end
        
        % Fn > 1
        if nClampHigh_Fn > 0
            idx_Fn = find(Fn > 1);
            idx_Fn_report = idx_Fn(1:min(max_report, numel(idx_Fn)));
            fprintf('    Fn > 1: Tsw = [');
            fprintf('%.2f ', Tsw(idx_Fn_report));
            fprintf('] K\n');
        end
        
        % coexistence < 0
        if nClampLow_coex > 0
            idx_coex_low = find(coexistence < 0);
            idx_coex_low_report = idx_coex_low(1:min(max_report, numel(idx_coex_low)));
            fprintf('    coexistence < 0: Tsw = [');
            fprintf('%.2f ', Tsw(idx_coex_low_report));
            fprintf('] K\n');
        end
        
        % coexistence > 1
        if nClampHigh_coex > 0
            idx_coex_high = find(coexistence > 1);
            idx_coex_high_report = idx_coex_high(1:min(max_report, numel(idx_coex_high)));
            fprintf('    coexistence > 1: Tsw = [');
            fprintf('%.2f ', Tsw(idx_coex_high_report));
            fprintf('] K\n');
        end
    end
end

if ~isfield(params, 'debug')
    params.debug = struct();
end

% --- Debug prints (now mask_fit exists) ---
fprintf('Tp range %.1fÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Å“%.1f\n', min(Tp), max(Tp));
fprintf('Tsw range %.1fÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Å“%.1f\n', min(Tsw), max(Tsw));
fprintf('Any NaN D_interp? %d, F_interp? %d\n', any(isnan(D_interp)), any(isnan(F_interp)));
[r_D, status_D, n_D] = safeCorr(D_interp, Rsw);
[r_F, status_F, n_F] = safeCorr(F_interp, Rsw);
if status_D ~= "ok"
    fprintf('  [safeCorr D_interp/Rsw: status=%s, n=%d]\n', status_D, n_D);
end
if status_F ~= "ok"
    fprintf('  [safeCorr F_interp/Rsw: status=%s, n=%d]\n', status_F, n_F);
end
fprintf('corr(D_interp, Rsw) = %.3f\n', r_D);
fprintf('corr(F_interp, Rsw) = %.3f\n', r_F);
fprintf('max D_interp in mask_fit / global = %.3f\n', max(D_interp(mask_fit)) / max(D_interp + eps));
fprintf('max F_interp in mask_fit / global = %.3f\n', max(F_interp(mask_fit)) / max(F_interp + eps));

% --- Plot gating (safe defaults) ---
doPlotSwitching = true;

% Prefer explicit params.debug.plotSwitching if exists
if isfield(params, 'debug') && isstruct(params.debug) && isfield(params.debug, 'plotSwitching')
    doPlotSwitching = logical(params.debug.plotSwitching);
end

% Also respect a generic params.doPlotting if present
if isfield(params, 'doPlotting')
    doPlotSwitching = doPlotSwitching && logical(params.doPlotting);
end

% In case figures are globally disabled
if ~usejava('desktop')
    doPlotSwitching = false;
end

if doPlotSwitching
    figure;
    plot(Tp, Dp, 'ko-'); hold on;
    plot(Tsw, D_interp, 'r.-');
    legend('Dp at pauses','D_interp on Tsw'); grid on; title('AFM metric interpolation');

    figure;
    plot(Tp, Fp, 'ko-'); hold on;
    plot(Tsw, F_interp, 'r.-');
    legend('Fp at pauses','F_interp on Tsw'); grid on; title('FM metric interpolation');
end


% --- Normalize to [0,1] using global maxima (consistent scaling) ---
Dn = D_interp ./ (max(D_interp) + eps);
Fn = F_interp ./ (max(F_interp) + eps);

% Count clamps before applying them (Clamp diagnostics)
nClampLow_Dn = nnz(Dn < 0);
nClampHigh_Dn = nnz(Dn > 1);
nClampLow_Fn = nnz(Fn < 0);
nClampHigh_Fn = nnz(Fn > 1);
Dn = min(max(Dn,0),1);
Fn = min(max(Fn,0),1);

% Normalization diagnostic (check consistency after global normalization)
if isfield(params, 'debug') && isstruct(params.debug) && isfield(params.debug, 'verbose') && params.debug.verbose
    max_D_global = max(D_interp);
    max_D_masked = max(D_interp(mask_fit));
    max_F_global = max(F_interp);
    max_F_masked = max(F_interp(mask_fit));
    
    ratio_D = max_D_masked / (max_D_global + eps);
    ratio_F = max_F_masked / (max_F_global + eps);
    
    fprintf('\nNormalization diagnostic:\n');
    fprintf('  D_interp: global=%.6g, mask_fit=%.6g, ratio=%.4f\n', max_D_global, max_D_masked, ratio_D);
    fprintf('  F_interp: global=%.6g, mask_fit=%.6g, ratio=%.4f\n', max_F_global, max_F_masked, ratio_F);
    
    % Alert if ratios differ significantly from global norm (ratio < 0.95 indicates masked max is much lower)
    if ratio_D < 0.95 || ratio_F < 0.95
        fprintf('  Warning: Masked data max significantly lower than global max\n');
        
        % Report temperature location of global maxima
        if ratio_D < 0.95
            [~, idx_max_D] = max(D_interp);
            T_max_D = Tsw(idx_max_D);
            in_mask = mask_fit(idx_max_D);
            fprintf('    D_interp global max at Tsw=%.2f K (in mask_fit: %d)\n', T_max_D, in_mask);
        end
        if ratio_F < 0.95
            [~, idx_max_F] = max(F_interp);
            T_max_F = Tsw(idx_max_F);
            in_mask = mask_fit(idx_max_F);
            fprintf('    F_interp global max at Tsw=%.2f K (in mask_fit: %d)\n', T_max_F, in_mask);
        end
    end
end

% ===============================
% Optional: Signed FM coupling model (MUST use RAW)
% ===============================
R_signed_model = NaN;
R2_signed_model = NaN;

if params.allowSignedFM

    % Use RAW FM so sign survives
    F_scale  = max(abs(F_interp_raw)) + eps;
    F_signed = F_interp_raw ./ F_scale;          % signed
    F_mag    = abs(F_interp_raw) ./ F_scale;     % magnitude

    % Use RAW/legacy AFM as you prefer; here: RAW to be consistent
    A_scale = max(abs(D_interp_raw)) + eps;
    A_norm  = D_interp_raw ./ A_scale;

    X_signed = [ A_norm(:).*F_mag(:), ...
                 A_norm(:).*F_signed(:), ...
                 ones(numel(A_norm),1) ];

    y_model = Rsw(:);

    try
        p_signed = X_signed(mask_fit,:) \ y_model(mask_fit);
        R_pred_signed = X_signed * p_signed;

        result.R_signed_pred = R_pred_signed;

        [R_signed, status_signed, n_signed] = safeCorr(R_pred_signed(mask_fit), y_model(mask_fit));
        if status_signed ~= "ok"
            fprintf('  [safeCorr signed/ymodel: status=%s, n=%d]\n', status_signed, n_signed);
        end
        R_signed_model = R_signed;
        R2_signed_model = R_signed^2;

        fprintf('Signed FM coupling R = %.3f, R2 = %.3f\n', R_signed_model, R2_signed_model);
    catch ME
        warning('Signed FM regression failed: %s', ME.message);
    end
end

% ===============================
lambda_grid = linspace(params.lambdaMin, params.lambdaMax, params.nLambda);

best_sse = Inf;
if ~isfield(params,'trivialThr'); params.trivialThr = 0.10; end
if ~isfield(params,'useTrivialSuppression'); params.useTrivialSuppression = true; end

% Coexistence suppression configuration (PR6)
if ~isfield(params, 'coexistence')
    params.coexistence = struct();
end
if ~isfield(params.coexistence, 'suppressLowAB')
    params.coexistence.suppressLowAB = true;  % default: enable suppression
end

J = 0;
if isfield(params, 'J')
    J = params.J;
elseif isfield(params, 'current_mA')
    J = params.current_mA;
end

best_wA = 1;
best_wB = 1;
best_c = 0;

for lambda = lambda_grid

    Deff = 1 - exp(-Dn/lambda);

    % normalize both symmetrically
    AFM_basis = Deff / max(Deff + eps);   % AFM basis: saturated dip contribution
    FM_basis  = Fn   / max(Fn   + eps);   % FM basis: normalized background contribution

    % --- Basis stability diagnostics (PR8) ---
    if isfield(params, 'debug') && isstruct(params.debug) && isfield(params.debug, 'verbose') && params.debug.verbose
        dA = gradient(AFM_basis);
        dB = gradient(FM_basis);
        roughness_A = max(abs(dA));
        roughness_B = max(abs(dB));
        fprintf('Basis roughness:\n');
        fprintf('  AFM: %.4g\n', roughness_A);
        fprintf('  FM : %.4g\n', roughness_B);
    end

    % coexistence functional (A/B overlap proxy)
    coexistence = 1 - abs(AFM_basis - FM_basis);
    
    % Count clamps before applying them (Clamp diagnostics)
    nClampLow_coex = nnz(coexistence < 0);
    nClampHigh_coex = nnz(coexistence > 1);
    coexistence = max(min(coexistence,1),0);

    % ---- trivial-zero suppression (SAFE: only where switching is below SNR within physics window) ----
    if params.coexistence.suppressLowAB
        if isfield(params,'useTrivialSuppression') && params.useTrivialSuppression
            sumAB = AFM_basis + FM_basis;
            thr   = params.trivialThr;
            idx0  = (sumAB < thr) & ~mask_SNR & mask_T;   % Apply suppression only within physics window
            coexistence(idx0) = coexistence(idx0) .* (sumAB(idx0)/thr);
        end
    end

    if params.enableJModel
        delta = params.alpha * (J - params.J0);
        wB = 1 ./ (1 + exp(-(J - params.Jc)./params.dJ));
        wA = 1 - wB;

        switch params.interp.mode
            case 'pchip'
                if params.interp.allowExtrap
                    A_shifted = interp1(Tsw, AFM_basis, Tsw - delta, 'pchip', 'extrap');
                else
                    A_shifted = interp1(Tsw, AFM_basis, Tsw - delta, 'pchip', NaN);
                end
            case 'linear'
                if params.interp.allowExtrap
                    A_shifted = interp1(Tsw, AFM_basis, Tsw - delta, 'linear', 'extrap');
                else
                    A_shifted = interp1(Tsw, AFM_basis, Tsw - delta, 'linear', NaN);
                end
            case 'nearest'
                A_shifted = interp1(Tsw, AFM_basis, Tsw - delta, 'nearest');
            otherwise
                error('Invalid interp.mode: %s', params.interp.mode);
        end
        model_base = wA .* A_shifted + wB .* FM_basis;

        X = ones(size(model_base));
        beta = lsqnonneg(X(mask_fit,:), Rsw(mask_fit) - model_base(mask_fit));
        c = beta(1);
        Rhat = model_base + c;
    else
        X = [coexistence, ones(size(coexistence))];

        % fit only in the chosen window
        beta = lsqnonneg(X(mask_fit,:), Rsw(mask_fit));
        fprintf('beta1=%.4g, beta2=%.4g\n', beta(1), beta(2));
        Rhat = X * beta;
    end

    sse = sum((Rhat(mask_fit) - Rsw(mask_fit)).^2);

    if sse < best_sse
        best_sse = sse;
        best_lambda = lambda;
        if params.enableJModel
            best_a = wA;
            best_b = c;
            best_wA = wA;
            best_wB = wB;
            best_c = c;
        else
            best_a = beta(1);
            best_b = beta(2);
        end
        best_Rhat = Rhat;
        best_AFM_basis = AFM_basis;
        best_FM_basis = FM_basis;
        best_coexistence = coexistence;
    end
end

% ===============================
% RÃƒâ€šÃ‚Â² (same window)
% ===============================
Ruse      = Rsw(mask_fit);
Rhat_use  = best_Rhat(mask_fit);

SS_tot = sum((Ruse - mean(Ruse)).^2);
SS_res = sum((Rhat_use - Ruse).^2);
R2 = 1 - SS_res/SS_tot;

if params.enableJModel
    [~, idx_exp] = max(abs(Ruse));
    [~, idx_model] = max(abs(Rhat_use));
    delta_T = Tsw(mask_fit);
    peak_shift = delta_T(idx_model) - delta_T(idx_exp);
    [R_corr, status_corr, n_corr] = safeCorr(Rhat_use, Ruse);
    if status_corr ~= "ok"
        fprintf('  [safeCorr Rhat/Ruse: status=%s, n=%d]\n', status_corr, n_corr);
    end

    fprintf('J-model alpha = %.6g\n', params.alpha);
    fprintf('J-model Jc = %.6g\n', params.Jc);
    fprintf('Mean correlation across currents: %.6g\n', R_corr);
    fprintf('Max |Delta T| (K): %.6g\n', abs(peak_shift));
end

% ===============================
% Pause-domain vectors for Phase C export
% ===============================
switch params.interp.mode
    case 'pchip'
        if params.interp.allowExtrap
            Rsw_pause = interp1(Tsw, Rsw, Tp_pause_export, 'pchip', 'extrap');
            C_pause = interp1(Tsw, best_coexistence, Tp_pause_export, 'pchip', 'extrap');
        else
            Rsw_pause = interp1(Tsw, Rsw, Tp_pause_export, 'pchip', NaN);
            C_pause = interp1(Tsw, best_coexistence, Tp_pause_export, 'pchip', NaN);
        end
    case 'linear'
        if params.interp.allowExtrap
            Rsw_pause = interp1(Tsw, Rsw, Tp_pause_export, 'linear', 'extrap');
            C_pause = interp1(Tsw, best_coexistence, Tp_pause_export, 'linear', 'extrap');
        else
            Rsw_pause = interp1(Tsw, Rsw, Tp_pause_export, 'linear', NaN);
            C_pause = interp1(Tsw, best_coexistence, Tp_pause_export, 'linear', NaN);
        end
    case 'nearest'
        Rsw_pause = interp1(Tsw, Rsw, Tp_pause_export, 'nearest');
        C_pause = interp1(Tsw, best_coexistence, Tp_pause_export, 'nearest');
    otherwise
        error('Invalid interp.mode: %s', params.interp.mode);
end

% ===============================
% Output
% ===============================
result.Rhat    = best_Rhat;
result.lambda  = best_lambda;
result.a       = best_a;
result.b       = best_b;
result.R2      = R2;
result.Tsw     = Tsw;

% Fix: export valid Tp/Tsw for downstream diagnostics.
result.Tp_valid = Tp_pause_export;
result.Tsw_valid = Tsw(mask_fit);

% Store signed FM model results (if enabled)
result.R_signed_model = R_signed_model;
result.R2_signed_model = R2_signed_model;

result.A_basis = best_AFM_basis;
result.B_basis = best_FM_basis;
result.C_basis = best_coexistence;

% Expose J-dependent channel weights for validation
if params.enableJModel
    result.wA = best_wA;
    result.wB = best_wB;
    result.suppressionS = 1;
    result.wB_over_wA = best_wB / (best_wA + eps);
else
    result.wA = 1;
    result.wB = 1;
    result.suppressionS = 1;
    result.wB_over_wA = 1;
end

result.Tp_pause  = Tp_pause_export;
result.Rsw_pause = Rsw_pause(:);
result.C_pause   = C_pause(:);
result.A_pause   = Dp_pause_export;
result.F_pause   = Fp_pause_export;
result.F_pause_signed = Fp_pause_signed_export;
result.F_pause_abs = Fp_pause_abs_export;
result.F_pause_metric = result.F_pause;

% Validate pause domain exports have matching lengths
assert(all([numel(result.Tp_pause), numel(result.A_pause), ...
            numel(result.F_pause), numel(result.Rsw_pause), ...
            numel(result.C_pause), numel(result.F_pause_signed), ...
            numel(result.F_pause_abs)] == numel(result.Tp_pause)), ...
    'Pause-domain export vectors do not have matching lengths.');

% Readable aliases (keep backward compatibility)
result.AFM_basis = result.A_basis;
result.FM_basis  = result.B_basis;

% for backward compatibility with your old plotting names:
result.D_basis = result.A_basis;
result.F_basis = result.B_basis;

% ===============================
% Mechanism correlations (same window)
% ===============================
AFM_basis = best_AFM_basis(mask_fit);
FM_basis  = best_FM_basis(mask_fit);
coexistence = best_coexistence(mask_fit);
R = Ruse;

[R_dom, status_dom, n_dom] = safeCorr(R, 1-AFM_basis);
if status_dom ~= "ok"
    fprintf('  [safeCorr R/dominance: status=%s, n=%d]\n', status_dom, n_dom);
end
[R_co, status_co, n_co] = safeCorr(R, coexistence);
if status_co ~= "ok"
    fprintf('  [safeCorr R/coexistence: status=%s, n=%d]\n', status_co, n_co);
end
dA = gradient(AFM_basis, Tsw(mask_fit));
dB = gradient(FM_basis, Tsw(mask_fit));
[R_inst, status_inst, n_inst] = safeCorr(R, abs(dA) + abs(dB));
if status_inst ~= "ok"
    fprintf('  [safeCorr R/instability: status=%s, n=%d]\n', status_inst, n_inst);
end

fprintf('\nMechanism correlations:\n');
fprintf('Dominance:   %.3f\n', R_dom);
fprintf('Coexistence: %.3f\n', R_co);
fprintf('Instability: %.3f\n', R_inst);

%% =========================================================
%  Additional overlap models + decision table
% ==========================================================


% Physics window (already defined earlier, reuse it)
A_fit = best_AFM_basis(mask_fit);
B_fit = best_FM_basis(mask_fit);
R_fit = Rsw(mask_fit);

% Keep original variable names for downstream diagnostics
A = A_fit;
B = B_fit;

% --- Overlap models ---
C1 = 1 - abs(A - B);                 % linear coexistence (already used)
C1 = max(min(C1,1),0);

C2 = A .* B;                        % multiplicative overlap

C3 = 2*A.*B ./ (A + B + eps);      % harmonic-type overlap (requires both finite)


% --- Dominance + Instability ---
Dom = 1 - A;

dA = gradient(A, Tsw(mask_fit));
dB = gradient(B, Tsw(mask_fit));
Inst = abs(dA) + abs(dB);

% --- Balanced overlap (rewards similarity without requiring both large) ---
C4 = 1 - (A - B).^2;
C4 = max(min(C4,1),0);

models = struct();

models(1).name = 'Dominance (1-A)';
models(1).X = Dom;

models(2).name = 'Coexistence |A-B|';
models(2).X = C1;

models(3).name = 'Overlap A*B';
models(3).X = C2;

models(4).name = 'Overlap harmonic';
models(4).X = C3;

models(5).name = 'Instability |dA|+|dB|';
models(5).X = Inst;

% insert as an additional model
models(end+1).name = 'Balanced overlap 1-(A-B)^2';
models(end).X = C4;

nM = numel(models);

R2_list   = zeros(nM,1);
Corr_list = zeros(nM,1);

for k = 1:nM

    Xk = models(k).X(:);
    Xfit = [Xk, ones(size(Xk))];

    beta = Xfit \ R;

    Rhat_k = Xfit * beta;

    SS_tot = sum((R - mean(R)).^2);
    SS_res = sum((Rhat_k - R).^2);

    R2_list(k) = 1 - SS_res/SS_tot;
    [Corr_list(k), status_k, n_k] = safeCorr(R, Xk);
    if status_k ~= "ok"
        fprintf('  [safeCorr model %d: status=%s, n=%d]\n', k, status_k, n_k);
    end

end

% ===============================
% Add signed FM coupling model if enabled
% ===============================
if isfield(params, 'allowSignedFM') && params.allowSignedFM ...
        && isfield(result,'R_signed_pred')

    [signedCorr, status_sgn, n_sgn] = safeCorr(result.R_signed_pred(mask_fit), ...
                                                Rsw(mask_fit));
    if status_sgn ~= "ok"
        fprintf('  [safeCorr signed FM: status=%s, n=%d]\n', status_sgn, n_sgn);
    end

    R2_list(end+1)   = result.R2_signed_model;
    Corr_list(end+1) = signedCorr;
end

DecisionTable = table( ...
    string({models.name})', ...
    Corr_list, ...
    R2_list, ...
    'VariableNames', {'Model','Correlation','R2'});
DecisionTable = sortrows(DecisionTable, 'R2', 'descend');

disp(' ');
disp('=== Mechanism decision table ===');
disp(DecisionTable);

% also attach to result struct
result.DecisionTable = DecisionTable;

%% =========================================================
%  Diagnostic: A vs B scatter (balance vs anti-correlation)
% =========================================================
figure('Color','w','Name','A vs B scatter','NumberTitle','off');

A_sc = best_AFM_basis(mask_diag);
B_sc = best_FM_basis(mask_diag);
T_sc = Tsw(mask_diag);

scatter(A_sc, B_sc, 80, T_sc, 'filled');
xlabel('A (Deff normalized)','Interpreter','none');
ylabel('B (FM normalized)','Interpreter','none');
title('A vs B (colored by T)','Interpreter','none');
colorbar; grid on;

[R_AB, status_AB, n_AB] = safeCorr(A_sc, B_sc);
if status_AB ~= "ok"
    fprintf('  [safeCorr A/B: status=%s, n=%d]\n', status_AB, n_AB);
end
fprintf('corr(A,B) = %.3f\n', R_AB);
[r_RT, status_RT, n_RT] = safeCorr(Ruse, Tsw(mask_fit));
if status_RT ~= "ok"
    fprintf('  [safeCorr R/T: status=%s, n=%d]\n', status_RT, n_RT);
end
fprintf('corr(R,T) = %.3f\n', r_RT);
[r_ABT, status_ABT, n_ABT] = safeCorr((A.*B), Tsw(mask_fit));
if status_ABT ~= "ok"
    fprintf('  [safeCorr A*B/T: status=%s, n=%d]\n', status_ABT, n_ABT);
end
fprintf('corr(A*B,T) = %.3f\n', r_ABT);
[r_C1T, status_C1T, n_C1T] = safeCorr((1-abs(A-B)), Tsw(mask_fit));
if status_C1T ~= "ok"
    fprintf('  [safeCorr C1/T: status=%s, n=%d]\n', status_C1T, n_C1T);
end
fprintf('corr(C1,T) = %.3f\n', r_C1T);

Tp_valid = Tp(Dp>0 & Fp_mag>0);
fprintf('Tp range: %.1fÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Å“%.1f K\n', min(Tp_valid), max(Tp_valid));
fprintf('Tsw range: %.1fÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Å“%.1f K\n', min(Tsw), max(Tsw));
% attach for later use
result.corrAB = R_AB;
end

% NOTE: Placeholder functions compute_dR() and compute_channel_weights() removed
% (were unused and contained non-physical placeholder values A_val=1, B_val=1).
% See version control for historical reference if needed.









