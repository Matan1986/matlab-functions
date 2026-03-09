%% PRL Validation: J-dependent Model
%
% Official repository test for J-dependent switching reconstruction model.
%
% PURPOSE:
%   Validates the J-dependent model by comparing predicted vs measured
%   switching curves across multiple current values.
%
% METRICS VALIDATED:
%   1. Normalized shape correlation (model vs experimental)
%   2. Peak temperature shift T*(J) 
%   3. Channel weight balance ratio
%
% DEPENDENCIES:
%   - Main_Aging.m (runs full pipeline through stage 7)
%   - stage8_globalJfit_shiftGating.m (J-model parameter optimization)
%   - reconstructSwitchingAmplitude.m (per-current reconstruction)
%
% OUTPUT:
%   - Console summary of validation metrics
%   - Results table with correlations, peak shifts, and balance errors
%
% USAGE:
%   Run this script after ensuring cfg = agingConfig() is properly configured
%   with multi-current switching data (Rsw_15mA, Rsw_20mA, etc.)
%
% =========================================================

clc; clear; close all;

fprintf('\n=======================================================\n');
fprintf('PRL VALIDATION: J-dependent Switching Model\n');
fprintf('=======================================================\n\n');

baseFolder = 'c:\Dev\matlab-functions';
addpath(genpath(baseFolder));

% =========================================================
% CONFIGURATION
% =========================================================
cfg = agingConfig();

% Enable global J-fit in stage 7
cfg.switchParams.enableGlobalJFit = true;
cfg.debug.verbose = false;  % Set to true for detailed diagnostics

fprintf('Running full aging pipeline (Main_Aging)...\n');

% =========================================================
% RUN FULL PIPELINE THROUGH STAGE 7
% =========================================================
state = Main_Aging(cfg);

fprintf('✓ Pipeline completed through stage 7\n');

% =========================================================
% RUN STAGE 8: GLOBAL J-FIT OPTIMIZATION
% =========================================================
% Define current values for multi-current validation
Jlist = [15 20 25 30 35 45];
nJ = numel(Jlist);

fprintf('Running stage 8 global J-fit...\n');
state = stage8_globalJfit_shiftGating(state, cfg, Jlist);
fprintf('✓ Stage 8 completed\n\n');

% =========================================================
% EXTRACT RESULTS FROM STATE
% =========================================================

% Stage 8 global fit parameters
p8 = state.stage8;

fprintf('=== Global Fit Parameters (Stage 8) ===\n');
fprintf('alpha (K/mA)    = %+.6g\n', p8.alpha);
fprintf('J0 (mA)         = %.6g\n', p8.J0);
fprintf('Jc (mA)         = %.6g\n', p8.Jc);
fprintf('dJ (mA)         = %.6g\n', p8.dJ);
fprintf('SSE_initial     = %.6g\n', p8.SSE_initial);
fprintf('SSE_final       = %.6g\n', p8.SSE_final);
fprintf('SSE_ratio       = %.6g\n', p8.SSE_ratio);
fprintf('========================================\n\n');

% Temperature grid
Tsw = cfg.Tsw(:);

% Pause temperatures
Tp = [state.pauseRuns.waitK]';

fprintf('Temperature grid: %d points (%.1f–%.1f K)\n', ...
    numel(Tsw), min(Tsw), max(Tsw));
fprintf('Pause temperatures: %d values\n\n', numel(Tp));

% =========================================================
% VERIFY EXPERIMENTAL DATA
% =========================================================
fprintf('Verifying multi-current experimental data...\n');

required_fields = {'Rsw_15mA', 'Rsw_20mA', 'Rsw_25mA', ...
                   'Rsw_30mA', 'Rsw_35mA', 'Rsw_45mA'};

for k = 1:numel(required_fields)
    assert(isfield(cfg, required_fields{k}), ...
        'Missing required field: cfg.%s', required_fields{k});
end

% Assemble experimental data matrix
Rsw_exp = [ ...
    cfg.Rsw_15mA(:), ...
    cfg.Rsw_20mA(:), ...
    cfg.Rsw_25mA(:), ...
    cfg.Rsw_30mA(:), ...
    cfg.Rsw_35mA(:), ...
    cfg.Rsw_45mA(:) ];

assert(size(Rsw_exp, 1) == numel(Tsw), ...
    'Experimental data length (%d) does not match Tsw grid (%d)', ...
    size(Rsw_exp, 1), numel(Tsw));

fprintf('✓ All experimental data present and validated\n\n');

% =========================================================
% INITIALIZE RESULT ARRAYS
% =========================================================
corr_shape = zeros(nJ, 1);
T_star_exp = zeros(nJ, 1);
T_star_model = zeros(nJ, 1);
delta_T = zeros(nJ, 1);
ratio_data = zeros(nJ, 1);
ratio_model = zeros(nJ, 1);
balance_error = zeros(nJ, 1);

% Overlap mechanism metrics
corr_overlap = zeros(nJ, 1);
T_star_overlap = zeros(nJ, 1);
delta_T_overlap = zeros(nJ, 1);
corr_coexistence = zeros(nJ, 1);
corr_dominance = zeros(nJ, 1);

% Full mechanism discrimination metrics
mechanism_names = {'Overlap (A*B)', 'Coexistence (1-|A-B|)', 'Dominance (1-A)'};
nMech = numel(mechanism_names);
corr_mech = zeros(nJ, nMech);
partialcorr_mech = zeros(nJ, nMech);
T_peak_mech = zeros(nJ, nMech);
delta_T_mech = zeros(nJ, nMech);

% Additional partial-correlation diagnostics
partialcorr_A_T = zeros(nJ, 1);
partialcorr_B_T = zeros(nJ, 1);

fprintf('=== Validation Loop ===\n');
fprintf('%s\n', repmat('-', 1, 80));

% =========================================================
% VALIDATION LOOP: RECONSTRUCT FOR EACH CURRENT
% =========================================================

% Set up reconstruction parameters using stage 8 fit results
params = cfg.switchParams;
params.enableJModel = true;
params.alpha = p8.alpha;
params.J0 = p8.J0;
params.Jc = p8.Jc;
params.dJ = p8.dJ;

for k = 1:nJ

    J = Jlist(k);
    dR_exp = Rsw_exp(:, k);

    % =====================================================
    % RECONSTRUCT FOR CURRENT J
    % =====================================================
    params.J = J;

    result = reconstructSwitchingAmplitude( ...
        'experimental', ...
        state.pauseRuns, ...
        state.pauseRuns, ...
        params, ...
        Tp, ...
        Tsw, ...
        dR_exp);

    dR_model = result.Rhat;

    % Extract valid temperature mask
    if isfield(result, 'Tsw_valid') && ~isempty(result.Tsw_valid)
        mask = ismember(Tsw(:), result.Tsw_valid(:));
    else
        mask = true(size(Tsw));
    end

    if ~any(mask)
        mask = true(size(Tsw));
    end

    dR_exp_use   = dR_exp(mask);
    dR_model_use = dR_model(mask);
    T_use        = Tsw(mask);

    % Extract basis functions
    A_vec = result.A_basis;
    B_vec = result.B_basis;
    wA_prod = result.wA;
    wB_prod = result.wB;

    % =====================================================
    % MECHANISM PREDICTORS
    % =====================================================
    M1 = A_vec .* B_vec;          % Overlap
    M2 = 1 - abs(A_vec - B_vec);  % Coexistence
    M3 = 1 - A_vec;               % Dominance

    M_use = [M1(mask), M2(mask), M3(mask)];

    % =====================================================
    % METRIC 1: NORMALIZED SHAPE CORRELATION
    % =====================================================
    mxE = max(abs(dR_exp_use));
    mxM = max(abs(dR_model_use));

    if mxE > 0 && mxM > 0
        dR_exp_n = dR_exp_use / mxE;
        dR_model_n = dR_model_use / mxM;
        C = corrcoef(dR_exp_n, dR_model_n);
        corr_shape(k) = C(1, 2);
    else
        corr_shape(k) = NaN;
    end

    % =====================================================
    % METRIC 2: PEAK TEMPERATURE SHIFT T*(J)
    % =====================================================
    if max(dR_exp_use) >= abs(min(dR_exp_use))
        [~, idx_exp] = max(dR_exp_use);
    else
        [~, idx_exp] = min(dR_exp_use);
    end

    if max(dR_model_use) >= abs(min(dR_model_use))
        [~, idx_model] = max(dR_model_use);
    else
        [~, idx_model] = min(dR_model_use);
    end

    T_star_exp(k) = T_use(idx_exp);
    T_star_model(k) = T_use(idx_model);
    delta_T(k) = T_star_model(k) - T_star_exp(k);

    % =====================================================
    % METRIC 2B: MECHANISM CORRELATIONS + PARTIAL CORRELATIONS
    % =====================================================
    for m = 1:nMech
        corr_mech(k, m) = safeCorr(dR_exp_use, M_use(:, m));
        partialcorr_mech(k, m) = safePartialCorr(dR_exp_use, M_use(:, m), T_use);

        [~, idx_m] = max(abs(M_use(:, m)));
        T_peak_mech(k, m) = T_use(idx_m);
        delta_T_mech(k, m) = T_peak_mech(k, m) - T_star_exp(k);
    end

    % Additional requested diagnostics
    partialcorr_A_T(k) = safePartialCorr(dR_exp_use, A_vec(mask), T_use);
    partialcorr_B_T(k) = safePartialCorr(dR_exp_use, B_vec(mask), T_use);

    % Backward-compatible per-mechanism vectors
    corr_overlap(k) = corr_mech(k, 1);
    corr_coexistence(k) = corr_mech(k, 2);
    corr_dominance(k) = corr_mech(k, 3);
    T_star_overlap(k) = T_peak_mech(k, 1);
    delta_T_overlap(k) = delta_T_mech(k, 1);

    % =====================================================
    % METRIC 3: CHANNEL WEIGHT BALANCE RATIO
    % =====================================================
    assert(numel(A_vec) == numel(Tsw) && numel(B_vec) == numel(Tsw), ...
        'A/B basis length mismatch with Tsw grid');

    assert(wA_prod ~= 0, 'wA is zero at J=%g mA', J);

    if abs(A_vec(idx_exp)) < 1e-12
        warning('Skipping balance test at J=%g mA (A(T*) ≈ 0)', J);
        ratio_data(k)  = NaN;
        ratio_model(k) = NaN;
        balance_error(k) = NaN;
    else
        ratio_data(k)  = B_vec(idx_exp) / A_vec(idx_exp);
        ratio_model(k) = wB_prod / wA_prod;
        balance_error(k) = abs(ratio_data(k) - ratio_model(k));
    end

    % =====================================================
    % PRINT PROGRESS
    % =====================================================
    fprintf('J=%3d mA | corr=%.4f | T*_exp=%.2f K | T*_mod=%.2f K | ΔT=%+.2f K\n', ...
        J, corr_shape(k), T_star_exp(k), T_star_model(k), delta_T(k));
end

fprintf('%s\n', repmat('-', 1, 80));

% =========================================================
% LEAVE-ONE-OUT ROBUSTNESS (remove one Tp pause each time)
% =========================================================
fprintf('\n=== Leave-One-Out Robustness (Tp pauses) ===\n');

nTp = numel(state.pauseRuns);
corr_mech_loo = nan(nTp, nJ, nMech);

for iTp = 1:nTp
    pauseRuns_loo = state.pauseRuns;
    pauseRuns_loo(iTp) = [];
    Tp_loo = [pauseRuns_loo.waitK]';

    for k = 1:nJ
        J = Jlist(k);
        dR_exp = Rsw_exp(:, k);

        params.J = J;
        result_loo = reconstructSwitchingAmplitude( ...
            'experimental', ...
            pauseRuns_loo, ...
            pauseRuns_loo, ...
            params, ...
            Tp_loo, ...
            Tsw, ...
            dR_exp);

        if isfield(result_loo, 'Tsw_valid') && ~isempty(result_loo.Tsw_valid)
            mask_loo = ismember(Tsw(:), result_loo.Tsw_valid(:));
        else
            mask_loo = true(size(Tsw));
        end
        if ~any(mask_loo)
            mask_loo = true(size(Tsw));
        end

        R_use_loo = dR_exp(mask_loo);
        A_loo = result_loo.A_basis;
        B_loo = result_loo.B_basis;

        M_loo = [A_loo(mask_loo) .* B_loo(mask_loo), ...
                 1 - abs(A_loo(mask_loo) - B_loo(mask_loo)), ...
                 1 - A_loo(mask_loo)];

        for m = 1:nMech
            corr_mech_loo(iTp, k, m) = safeCorr(R_use_loo, M_loo(:, m));
        end
    end
end

mean_corr_loo = zeros(1, nMech);
std_corr_loo = zeros(1, nMech);
for m = 1:nMech
    vals = corr_mech_loo(:, :, m);
    vals = vals(:);
    mean_corr_loo(m) = mean(vals, 'omitnan');
    std_corr_loo(m) = std(vals, 'omitnan');
end

fprintf('Computed LOO robustness over %d pause removals × %d currents\n', nTp, nJ);

% =========================================================
% MECHANISM COMPARISON
% =========================================================
fprintf('\n=== Mechanism Comparison ===\n');
fprintf('%s\n', repmat('-', 1, 80));
fprintf('%-10s | %-12s | %-12s | %-12s\n', 'J (mA)', 'Overlap A*B', 'Coexistence', 'Dominance');
fprintf('%s\n', repmat('-', 1, 80));

for k = 1:nJ
    fprintf('%-10d | %12.4f | %12.4f | %12.4f\n', ...
        Jlist(k), corr_overlap(k), corr_coexistence(k), corr_dominance(k));
end

fprintf('%s\n', repmat('-', 1, 80));
fprintf('%-10s | %12.4f | %12.4f | %12.4f\n', ...
    'MEAN', nanmean(corr_overlap), nanmean(corr_coexistence), nanmean(corr_dominance));
fprintf('%s\n', repmat('-', 1, 80));

fprintf('\n=== Partial Correlation (controlling T) ===\n');
fprintf('%s\n', repmat('-', 1, 80));
fprintf('%-10s | %-12s | %-12s | %-12s\n', 'J (mA)', 'Overlap A*B', 'Coexistence', 'Dominance');
fprintf('%s\n', repmat('-', 1, 80));
for k = 1:nJ
    fprintf('%-10d | %12.4f | %12.4f | %12.4f\n', ...
        Jlist(k), partialcorr_mech(k,1), partialcorr_mech(k,2), partialcorr_mech(k,3));
end
fprintf('%s\n', repmat('-', 1, 80));
fprintf('%-10s | %12.4f | %12.4f | %12.4f\n', ...
    'MEAN', nanmean(partialcorr_mech(:,1)), nanmean(partialcorr_mech(:,2)), nanmean(partialcorr_mech(:,3)));
fprintf('%s\n', repmat('-', 1, 80));

fprintf('\n=== Requested Partial-Correlation Diagnostics ===\n');
fprintf('%s\n', repmat('-', 1, 80));
for k = 1:nJ
    fprintf('J=%3d mA | partialcorr(R, A*B | T) = %+0.4f | partialcorr(R, A | T) = %+0.4f | partialcorr(R, B | T) = %+0.4f\n', ...
        Jlist(k), partialcorr_mech(k,1), partialcorr_A_T(k), partialcorr_B_T(k));
end
fprintf('%s\n', repmat('-', 1, 80));
fprintf('MEAN     | partialcorr(R, A*B | T) = %+0.4f | partialcorr(R, A | T) = %+0.4f | partialcorr(R, B | T) = %+0.4f\n', ...
    nanmean(partialcorr_mech(:,1)), nanmean(partialcorr_A_T), nanmean(partialcorr_B_T));
fprintf('%s\n', repmat('-', 1, 80));

% =========================================================
% BUILD RESULTS TABLE
% =========================================================
fprintf('\n=== Results Table ===\n');

results_table = table( ...
    Jlist(:), ...
    corr_shape(:), ...
    T_star_exp(:), ...
    T_star_model(:), ...
    delta_T(:), ...
    corr_overlap(:), ...
    T_star_overlap(:), ...
    delta_T_overlap(:), ...
    corr_coexistence(:), ...
    corr_dominance(:), ...
    ratio_data(:), ...
    ratio_model(:), ...
    balance_error(:), ...
    'VariableNames', { ...
    'J_mA', ...
    'ShapeCorr', ...
    'T_exp_K', ...
    'T_model_K', ...
    'DeltaT_K', ...
    'CorrOverlap', ...
    'ToverlapK', ...
    'DToverlapK', ...
    'CorrCoex', ...
    'CorrDom', ...
    'Ratio_Data', ...
    'Ratio_Model', ...
    'BalanceErr' ...
    });

disp(results_table);

% =========================================================
% FINAL MECHANISM DISCRIMINATION TABLE
% =========================================================
mean_corr = mean(corr_mech, 1, 'omitnan');
mean_partialcorr = mean(partialcorr_mech, 1, 'omitnan');
mean_deltaT = mean(delta_T_mech, 1, 'omitnan');

mechanism_table = table( ...
    string(mechanism_names(:)), ...
    mean_corr(:), ...
    mean_partialcorr(:), ...
    mean_corr_loo(:), ...
    std_corr_loo(:), ...
    mean_deltaT(:), ...
    'VariableNames', {'Mechanism','corr','partialcorr','mean_corr_LOO','std_corr_LOO','mean_delta_T'});

fprintf('\n=== Final Mechanism Comparison Table ===\n');
disp(mechanism_table);

% =========================================================
% RANKINGS BY EACH METRIC (diagnostic only)
% =========================================================
fprintf('\n=== Rankings by Metric ===\n');

[~, idx_corr] = sort(mean_corr, 'descend');
fprintf('By corr (desc):\n');
for r = 1:nMech
    i = idx_corr(r);
    fprintf('  %d) %s : %.4f\n', r, mechanism_names{i}, mean_corr(i));
end

[~, idx_pcorr] = sort(mean_partialcorr, 'descend');
fprintf('By partialcorr (desc):\n');
for r = 1:nMech
    i = idx_pcorr(r);
    fprintf('  %d) %s : %.4f\n', r, mechanism_names{i}, mean_partialcorr(i));
end

[~, idx_loo] = sort(mean_corr_loo, 'descend');
fprintf('By mean_corr_LOO (desc):\n');
for r = 1:nMech
    i = idx_loo(r);
    fprintf('  %d) %s : %.4f\n', r, mechanism_names{i}, mean_corr_loo(i));
end

[~, idx_std] = sort(std_corr_loo, 'ascend');
fprintf('By std_corr_LOO (asc):\n');
for r = 1:nMech
    i = idx_std(r);
    fprintf('  %d) %s : %.4f\n', r, mechanism_names{i}, std_corr_loo(i));
end

[~, idx_dt] = sort(abs(mean_deltaT), 'ascend');
fprintf('By |mean_delta_T| (asc):\n');
for r = 1:nMech
    i = idx_dt(r);
    fprintf('  %d) %s : %.4f K\n', r, mechanism_names{i}, mean_deltaT(i));
end

% =========================================================
% SUMMARY STATISTICS
% =========================================================
fprintf('\n=======================================================\n');
fprintf('VALIDATION SUMMARY\n');
fprintf('=======================================================\n');
fprintf('Mean shape correlation:    %.4f\n', nanmean(corr_shape));
fprintf('Std shape correlation:     %.4f\n', nanstd(corr_shape));
fprintf('Min shape correlation:     %.4f\n', min(corr_shape));
fprintf('Max |ΔT| (peak shift):     %.4f K\n', max(abs(delta_T)));
fprintf('Mean |ΔT|:                 %.4f K\n', mean(abs(delta_T)));
fprintf('Max balance error:         %.4f\n', max(balance_error));
fprintf('Mean balance error:        %.4f\n', nanmean(balance_error));
fprintf('-------------------------------------------------------\n');
fprintf('MECHANISM CORRELATIONS:\n');
fprintf('Mean corr(Rsw, A*B):       %.4f\n', nanmean(corr_overlap));
fprintf('Mean corr(Rsw, C):         %.4f\n', nanmean(corr_coexistence));
fprintf('Mean corr(Rsw, 1-A):       %.4f\n', nanmean(corr_dominance));
fprintf('Max |ΔT_overlap|:          %.4f K\n', max(abs(delta_T_overlap)));
fprintf('Mean |ΔT_overlap|:         %.4f K\n', mean(abs(delta_T_overlap)));
fprintf('=======================================================\n');

% =========================================================
% QUALITY ASSESSMENT
% =========================================================
fprintf('\n=== Quality Assessment ===\n');

mean_corr = nanmean(corr_shape);
max_shift = max(abs(delta_T));

if mean_corr > 0.95 && max_shift < 0.5
    fprintf('✓ EXCELLENT: Model shows excellent agreement with data\n');
elseif mean_corr > 0.90 && max_shift < 1.0
    fprintf('✓ GOOD: Model shows good agreement with data\n');
elseif mean_corr > 0.80 && max_shift < 2.0
    fprintf('⚠ ACCEPTABLE: Model shows acceptable agreement\n');
else
    fprintf('✗ POOR: Model agreement below expected threshold\n');
end

fprintf('\nValidation complete.\n');
fprintf('=======================================================\n\n');

function r = safeCorr(x, y)
valid = isfinite(x) & isfinite(y);
if nnz(valid) < 3
    r = NaN;
    return;
end

xv = x(valid);
yv = y(valid);

if std(xv) < eps || std(yv) < eps
    r = NaN;
    return;
end

C = corrcoef(xv, yv);
r = C(1,2);
end

function r = safePartialCorr(x, y, t)
valid = isfinite(x) & isfinite(y) & isfinite(t);
if nnz(valid) < 3
    r = NaN;
    return;
end

xv = x(valid);
yv = y(valid);
tv = t(valid);

if exist('partialcorr', 'file') == 2
    r = partialcorr(xv, yv, tv, 'rows', 'complete');
    return;
end

X = [ones(numel(tv),1), tv];
bx = X \ xv;
by = X \ yv;
rx = xv - X*bx;
ry = yv - X*by;

r = safeCorr(rx, ry);
end
