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
% Extract aging metrics
% ===============================
nPauses = numel(pauseRuns);
AFM_metric = zeros(nPauses,1);
FM_metric = zeros(nPauses,1);

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
        % 2) FM metric — STEP-like
        % ===============================
        wide_mask = abs(T - Tp_i) <= params.wideWindowK & ~dip_mask;

        sig = DeltaM - baseline;
        Twide = T(wide_mask);
        sigwide = sig(wide_mask);

        low  = sigwide(Twide < Tp_i);
        high = sigwide(Twide > Tp_i);

        if numel(low) > 2 && numel(high) > 2
            FM_metric(i) = abs(mean(high,'omitnan') - mean(low,'omitnan'));
        else
            FM_metric(i) = NaN;
        end

    end

    case 'fit'

    for i = 1:nPauses

        % ===============================
        % 1) AFM metric from fit
        % ===============================
        AFM_metric(i) = pauseRuns(i).Dip_area;

        % ===============================
        % 2) FM metric (STEP-like) from RAW
        % ===============================
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
            FM_metric(i) = abs(mean(high,'omitnan') - mean(low,'omitnan'));
        else
            FM_metric(i) = NaN;
        end

    end
end

% ===============================
% Interpolate to switching grid
% ===============================
Dp = AFM_metric;
Fp = FM_metric;
fprintf('Dp>0: %d / %d\n', nnz(Dp>0), numel(Dp));
fprintf('Fp>0: %d / %d\n', nnz(Fp>0 & isfinite(Fp)), numel(Fp));
disp(table(Tp(:), Dp(:), Fp(:), 'VariableNames',{'Tp','Dp','Fp'}));
epsFp = 1e-15;  % או 1e-14 לפי סדרי הגודל אצלך
valid = (Dp>0) & isfinite(Fp) & (Fp > epsFp);

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

fprintf('Number of valid pauses after filtering: %d\n', numel(Tp));

% Store filtered pause vectors for Phase C export (before any interpolation)
Tp_pause_export = Tp(:);
Dp_pause_export = Dp(:);
Fp_pause_export = Fp(:);

D_interp = interp1(Tp, Dp, Tsw, 'pchip', 'extrap');
F_interp = interp1(Tp, Fp, Tsw, 'pchip', 'extrap');

D_interp = max(D_interp,0);
F_interp = max(F_interp,0);

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

% --- Debug prints (now mask exists) ---
fprintf('Tp range %.1f–%.1f\n', min(Tp), max(Tp));
fprintf('Tsw range %.1f–%.1f\n', min(Tsw), max(Tsw));
fprintf('Any NaN D_interp? %d, F_interp? %d\n', any(isnan(D_interp)), any(isnan(F_interp)));
fprintf('corr(D_interp, Rsw) = %.3f\n', corr(D_interp, Rsw, 'rows','complete'));
fprintf('corr(F_interp, Rsw) = %.3f\n', corr(F_interp, Rsw, 'rows','complete'));
fprintf('max D_interp in mask / global = %.3f\n', max(D_interp(mask)) / max(D_interp + eps));
fprintf('max F_interp in mask / global = %.3f\n', max(F_interp(mask)) / max(F_interp + eps));


figure;
plot(Tp, Dp, 'ko-'); hold on;
plot(Tsw, D_interp, 'r.-');
legend('Dp at pauses','D_interp on Tsw'); grid on; title('AFM metric interpolation');

figure;
plot(Tp, Fp, 'ko-'); hold on;
plot(Tsw, F_interp, 'r.-');
legend('Fp at pauses','F_interp on Tsw'); grid on; title('FM metric interpolation');


% --- Normalize to [0,1] using in-mask maxima (recommended) ---
Dn = D_interp ./ (max(D_interp(mask)) + eps);
Fn = F_interp ./ (max(F_interp(mask)) + eps);
Dn = min(max(Dn,0),1);
Fn = min(max(Fn,0),1);

% ===============================
% Lambda scan
% ===============================
lambda_grid = linspace(params.lambdaMin, params.lambdaMax, params.nLambda);

best_sse = Inf;
if ~isfield(params,'trivialThr'); params.trivialThr = 0.10; end
if ~isfield(params,'useTrivialSuppression'); params.useTrivialSuppression = true; end

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

    X = [coexistence, ones(size(coexistence))];

    % fit only in the chosen window
    beta = X(mask,:) \ Rsw(mask);
    Rhat = X * beta;

    sse = sum((Rhat(mask) - Rsw(mask)).^2);

    if sse < best_sse
        best_sse = sse;
        best_lambda = lambda;
        best_a = beta(1);
        best_b = beta(2);
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

result.A_basis = best_AFM_basis;
result.B_basis = best_FM_basis;
result.C_basis = best_coexistence;

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
