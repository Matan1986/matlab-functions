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
        % 1) AFM metric — dip area
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
            if isfield(pr, 'FM_step_mag') && ~isempty(pr.FM_step_mag) && isfinite(pr.FM_step_mag)
                F_raw_signed = double(pr.FM_step_mag);
                FM_metric_signed(i) = F_raw_signed;
                FM_metric_mag(i) = abs(F_raw_signed);
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
                FM_metric_mag(i) = abs(F_raw_signed);
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
            if isfield(pauseRuns(i), 'FM_step_mag') && ~isempty(pauseRuns(i).FM_step_mag) && isfinite(pauseRuns(i).FM_step_mag)
                F_raw_signed = double(pauseRuns(i).FM_step_mag);
                FM_metric_signed(i) = F_raw_signed;
                FM_metric_mag(i) = abs(F_raw_signed);
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
                FM_metric_mag(i) = abs(F_raw_signed);
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
epsFp = 1e-15;  % או 1e-14 לפי סדרי הגודל אצלך
valid = (Dp>0) & isfinite(Fp_mag) & (Fp_mag > epsFp);
% Initialize clamp counters before any debug diagnostics may reference them.
nClampLow_Dn = 0;
nClampHigh_Dn = 0;
nClampLow_Fn = 0;
nClampHigh_Fn = 0;
nClampLow_coex = 0;
nClampHigh_coex = 0;


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

% --- Interpolate to switching grid (RAW first) ---
D_interp_raw = interp1(Tp, Dp, Tsw, 'pchip', 'extrap');
F_interp_raw = interp1(Tp, Fp, Tsw, 'pchip', 'extrap');

% --- Legacy pipeline keeps the original behavior (clamp to >=0) ---
D_interp = max(D_interp_raw, 0);
F_interp = max(F_interp_raw, 0);

% ===============================
% Define masks (NO slicing - all vectors remain aligned with Tsw)
% ===============================
% mask_T: physics window defined by temperature bounds (e.g., fitTmin=3, fitTmax=32)
mask_T = (Tsw >= params.fitTmin) & (Tsw <= params.fitTmax);

% noiseFloor: compute from Rsw within physics window
noiseFloor = 0.02 * max(Rsw(mask_T));

% mask_SNR: points above noise floor (entire Tsw range)
mask_SNR = Rsw > noiseFloor;

% mask: final fitting window = physics window AND above noise
mask = mask_T & mask_SNR;

% Verify all masks are same size as Tsw
assert(numel(mask_T) == numel(Tsw), 'mask_T size mismatch');
assert(numel(mask_SNR) == numel(Tsw), 'mask_SNR size mismatch');
assert(numel(mask) == numel(Tsw), 'mask size mismatch');

if ~isfield(params, 'debug')
    params.debug = struct();
end

% --- Debug prints (now mask exists) ---
fprintf('Tp range %.1f–%.1f\n', min(Tp), max(Tp));
fprintf('Tsw range %.1f–%.1f\n', min(Tsw), max(Tsw));
fprintf('Any NaN D_interp? %d, F_interp? %d\n', any(isnan(D_interp)), any(isnan(F_interp)));
fprintf('corr(D_interp, Rsw) = %.3f\n', corr(D_interp, Rsw, 'rows','complete'));
fprintf('corr(F_interp, Rsw) = %.3f\n', corr(F_interp, Rsw, 'rows','complete'));
fprintf('max D_interp in mask / global = %.3f\n', max(D_interp(mask)) / max(D_interp + eps));
fprintf('max F_interp in mask / global = %.3f\n', max(F_interp(mask)) / max(F_interp + eps));

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


% --- Normalize to [0,1] using in-mask maxima (recommended) ---
Dn = D_interp ./ (max(D_interp(mask)) + eps);
Fn = F_interp ./ (max(F_interp(mask)) + eps);
Dn = min(max(Dn,0),1);
Fn = min(max(Fn,0),1);

% ===============================
% Optional: Signed FM coupling model (MUST use RAW)
% ===============================
R_signed_model = NaN;
R2_signed_model = NaN;

if params.allowSignedFM

    % Use RAW FM so sign survives
    F_scale  = max(abs(F_interp_raw(mask))) + eps;
    F_signed = F_interp_raw ./ F_scale;          % signed
    F_mag    = abs(F_interp_raw) ./ F_scale;     % magnitude

    % Use RAW/legacy AFM as you prefer; here: RAW to be consistent
    A_scale = max(abs(D_interp_raw(mask))) + eps;
    A_norm  = D_interp_raw ./ A_scale;

    X_signed = [ A_norm(:).*F_mag(:), ...
                 A_norm(:).*F_signed(:), ...
                 ones(numel(A_norm),1) ];

    y_model = Rsw(:);

    try
        p_signed = X_signed(mask,:) \ y_model(mask);
        R_pred_signed = X_signed * p_signed;

        result.R_signed_pred = R_pred_signed;

        R_signed = corr(R_pred_signed(mask), y_model(mask), 'rows','complete');
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

    % coexistence functional (A/B overlap proxy)
    coexistence = 1 - abs(AFM_basis - FM_basis);
    coexistence = max(min(coexistence,1),0);

    % ---- trivial-zero suppression (SAFE: only where switching is below SNR within physics window) ----
    if params.useTrivialSuppression
        sumAB = AFM_basis + FM_basis;
        thr   = params.trivialThr;
        idx0  = (sumAB < thr) & ~mask_SNR & mask_T;   % Apply suppression only within physics window
        coexistence(idx0) = coexistence(idx0) .* (sumAB(idx0)/thr);
    end

    if params.enableJModel
        delta = params.alpha * (J - params.J0);
        wB = 1 ./ (1 + exp(-(J - params.Jc)./params.dJ));
        wA = 1 - wB;

        A_shifted = interp1(Tsw, AFM_basis, Tsw - delta, 'pchip', 'extrap');
        model_base = wA .* A_shifted + wB .* FM_basis;

        X = ones(size(model_base));
        beta = lsqnonneg(X(mask,:), Rsw(mask) - model_base(mask));
        c = beta(1);
        Rhat = model_base + c;
    else
        X = [coexistence, ones(size(coexistence))];

        % fit only in the chosen window
        beta = lsqnonneg(X(mask,:), Rsw(mask));
        fprintf('beta1=%.4g, beta2=%.4g\n', beta(1), beta(2));
        Rhat = X * beta;
    end

    sse = sum((Rhat(mask) - Rsw(mask)).^2);

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
% R² (same window)
% ===============================
Ruse      = Rsw(mask);
Rhat_use  = best_Rhat(mask);

SS_tot = sum((Ruse - mean(Ruse)).^2);
SS_res = sum((Rhat_use - Ruse).^2);
R2 = 1 - SS_res/SS_tot;

if params.enableJModel
    [~, idx_exp] = max(abs(Ruse));
    [~, idx_model] = max(abs(Rhat_use));
    delta_T = Tsw(mask);
    peak_shift = delta_T(idx_model) - delta_T(idx_exp);
    R_corr = corr(Rhat_use, Ruse, 'rows','complete');

    fprintf('J-model alpha = %.6g\n', params.alpha);
    fprintf('J-model Jc = %.6g\n', params.Jc);
    fprintf('Mean correlation across currents: %.6g\n', R_corr);
    fprintf('Max |Delta T| (K): %.6g\n', abs(peak_shift));
end

% ===============================
% Pause-domain vectors for Phase C export
% ===============================
Rsw_pause = interp1(Tsw, Rsw, Tp_pause_export, 'pchip');
C_pause = interp1(Tsw, best_coexistence, Tp_pause_export, 'pchip');

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
result.Tsw_valid = Tsw(mask);

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

% Validate pause domain exports have matching lengths
assert(all([numel(result.Tp_pause), numel(result.A_pause), ...
            numel(result.F_pause), numel(result.Rsw_pause), ...
            numel(result.C_pause)] == numel(result.Tp_pause)), ...
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
AFM_basis = best_AFM_basis(mask);
FM_basis  = best_FM_basis(mask);
coexistence = best_coexistence(mask);
R = Ruse;

R_dom = corr(R, 1-AFM_basis, 'rows','complete');
R_co  = corr(R, coexistence,   'rows','complete');
dA = gradient(AFM_basis, Tsw(mask));
dB = gradient(FM_basis, Tsw(mask));
R_inst = corr(R, abs(dA) + abs(dB), 'rows','complete');

fprintf('\nMechanism correlations:\n');
fprintf('Dominance:   %.3f\n', R_dom);
fprintf('Coexistence: %.3f\n', R_co);
fprintf('Instability: %.3f\n', R_inst);

%% =========================================================
%  Additional overlap models + decision table
% ==========================================================


% Physics window (already defined earlier, reuse it)
A_fit = best_AFM_basis(mask);
B_fit = best_FM_basis(mask);
R_fit = Rsw(mask);

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

dA = gradient(A, Tsw(mask));
dB = gradient(B, Tsw(mask));
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
    Corr_list(k) = corr(R, Xk, 'rows','complete');

end

% ===============================
% Add signed FM coupling model if enabled
% ===============================
if isfield(params, 'allowSignedFM') && params.allowSignedFM ...
        && isfield(result,'R_signed_pred')

    signedCorr = corr(result.R_signed_pred(mask), ...
                      Rsw(mask), 'rows','complete');

    models(end+1).name = 'Signed coupling A*(α|F|+βF)+c';
    models(end).X = result.R_signed_pred(mask);

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

A_sc = best_AFM_basis(mask);
B_sc = best_FM_basis(mask);
T_sc = Tsw(mask);

scatter(A_sc, B_sc, 80, T_sc, 'filled');
xlabel('A (Deff normalized)','Interpreter','none');
ylabel('B (FM normalized)','Interpreter','none');
title('A vs B (colored by T)','Interpreter','none');
colorbar; grid on;

R_AB = corr(A_sc, B_sc, 'rows','complete');
fprintf('corr(A,B) = %.3f\n', R_AB);
fprintf('corr(R,T) = %.3f\n', corr(Ruse, Tsw(mask), 'rows','complete'));
fprintf('corr(A*B,T) = %.3f\n', corr((A.*B), Tsw(mask), 'rows','complete'));
fprintf('corr(C1,T) = %.3f\n', corr((1-abs(A-B)), Tsw(mask), 'rows','complete'));

Tp_valid = Tp(Dp>0 & Fp>0);
fprintf('Tp range: %.1f–%.1f K\n', min(Tp_valid), max(Tp_valid));
fprintf('Tsw range: %.1f–%.1f K\n', min(Tsw), max(Tsw));
% attach for later use
result.corrAB = R_AB;
end

%% =========================================================
%  J-dependent ΔR(T) model (optional extension)
% ==========================================================

function dR = compute_dR(T, J, params)
%COMPUTE_DR Compute ΔR(T) with optional J-dependent extension
%
% SYNTAX:
%   dR = compute_dR(T, J, params)
%
% INPUT:
%   T        - Temperature (K)
%   J        - Exchange coupling parameter (optional, default=0)
%   params   - Parameter struct with dR0, alpha, and optional Jmodel
%
% OUTPUT:
%   dR       - Resistance change in appropriate units
%
% FEATURE: Toggleable J-dependent extension via params.enableJModel

% ===============================
% Backward compatibility
% ===============================
if nargin < 2 || isempty(J)
    J = 0;
end

if nargin < 3
    error('params struct must be provided');
end

% Default parameters if missing
if ~isfield(params, 'dR0')
    params.dR0 = 0;
end
if ~isfield(params, 'alpha')
    params.alpha = 1;
end
if ~isfield(params, 'enableJModel')
    params.enableJModel = false;
end
if ~isfield(params, 'Jmodel')
    params.Jmodel = struct();
end

% ===============================
% Compute intrinsic channels
% ===============================
A_val = 1;  % Placeholder for A(T); user should define this function
B_val = 1;  % Placeholder for B(T); user should define this function

% ===============================
% CASE 1: Feature disabled (DEFAULT)
% ===============================
if ~params.enableJModel
    dR = params.dR0 + params.alpha * (1 - abs(A_val - B_val));
    return;
end

% ===============================
% CASE 2: Feature enabled
% ===============================
if params.enableJModel
    % Get J-dependent weights
    [wA, wB, S] = compute_channel_weights(J, params);
    
    % Compute effective channels
    A_eff = wA .* A_val;
    B_eff = wB .* B_val;
    
    % Extended balance functional
    dR = params.dR0 + params.alpha * (1 - abs(A_eff - B_eff));
    
    % Apply optional suppression factor
    dR = S .* dR;
end
end

% =========================================================
%  Channel weight computation (J-dependent)
% =========================================================

function [wA, wB, S] = compute_channel_weights(J, params)
%COMPUTE_CHANNEL_WEIGHTS Compute J-dependent channel weights
%
% SYNTAX:
%   [wA, wB, S] = compute_channel_weights(J, params)
%
% INPUT:
%   J        - Exchange coupling parameter
%   params   - Parameter struct with Jmodel configuration
%
% OUTPUT:
%   wA       - AFM channel weight
%   wB       - FM channel weight
%   S        - Global suppression factor
%
% NOTE: Returns defaults (1, 1, 1) if Jmodel.type is missing.

% Default values
wA = 1;
wB = 1;
S  = 1;

% If no model type specified, return defaults
if ~isfield(params, 'Jmodel') || ~isfield(params.Jmodel, 'type')
    return;
end

model_type = params.Jmodel.type;

% ===============================
% EXPONENTIAL MODEL
% ===============================
if strcmp(model_type, 'exp')
    if ~isfield(params.Jmodel, 'gamma')
        error('gamma must be defined for exp model');
    end
    
    wA = 1;
    wB = exp(params.Jmodel.gamma * J);
    
% ===============================
% LOGISTIC MODEL
% ===============================
elseif strcmp(model_type, 'logistic')
    if ~isfield(params.Jmodel, 'J0') || ~isfield(params.Jmodel, 'deltaJ')
        error('J0 and deltaJ required for logistic model');
    end
    
    ratio = 1 ./ (1 + exp(-(J - params.Jmodel.J0) / params.Jmodel.deltaJ));
    
    wA = 1;
    wB = ratio;
    
% ===============================
% LINEAR MODEL
% ===============================
elseif strcmp(model_type, 'linear')
    if ~isfield(params.Jmodel, 'c0') || ~isfield(params.Jmodel, 'c1')
        error('c0 and c1 required for linear model');
    end
    
    wA = 1;
    wB = params.Jmodel.c0 + params.Jmodel.c1 * J;
end

% ===============================
% Optional global suppression
% ===============================
if isfield(params.Jmodel, 'suppressionGamma')
    S = exp(-params.Jmodel.suppressionGamma * J.^2);
end
end
