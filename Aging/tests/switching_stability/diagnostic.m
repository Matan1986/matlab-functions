%% PRL Validation: J-dependent Model
%
% Compares experimental Rsw curves against model using real A/B bases.
% - Normalized shape correlation with model
% - Peak temperature shift T*(J)
% - Channel weight balance ratio

clc; clear; close all;

fprintf('DIAGNOSTIC: Starting script...\n');

baseFolder = 'c:\Dev\matlab-functions';
addpath(genpath(baseFolder));

% =========================================================
% LOAD + FULL PREPROCESS PIPELINE
% =========================================================
cfg = agingConfig();
cfg = stage0_setupPaths(cfg);

cfg.switchParams.enableGlobalJFit = true;
cfg.debug.verbose = true;

state = stage1_loadData(cfg);
state = stage2_preprocess(state, cfg);
state = stage3_computeDeltaM(state, cfg);

% Run Stage 7 to perform global J-fit optimization
state = stage7_reconstructSwitching(state, cfg);

% Define Jlist for stage8 (must be a vector)
Jlist = [15 20 25 30 35 45];
nJ = numel(Jlist);

% Run Stage 8: global J-fit optimization across all currents
state = stage8_globalJfit_shiftGating(state, cfg, Jlist);

% Extract global fit parameters
p8 = state.stage8;

% Use global fit parameters
params = cfg.switchParams;
params.enableJModel = true;
params.alpha = p8.alpha;
params.J0 = p8.J0;
params.Jc = p8.Jc;
params.dJ = p8.dJ;

Tsw = cfg.Tsw(:);
J_list = Jlist;

% Use pauseRuns if available
pauseRuns = struct();
if isfield(state, 'pauseRuns')
    pauseRuns = state.pauseRuns;
end

% ---------------------------------------------------------
% Get temperature grid directly from production model
% ---------------------------------------------------------

fprintf('\nLoaded Tsw grid from model: %d points\n', numel(Tsw));
fprintf('Tsw range: %.1f %.1f K\n\n', min(Tsw), max(Tsw));

% =========================================================
% VERIFY EXPERIMENTAL DATA
% =========================================================
assert(isfield(cfg, 'Rsw_15mA'), 'Missing: cfg.Rsw_15mA');
assert(isfield(cfg, 'Rsw_20mA'), 'Missing: cfg.Rsw_20mA');
assert(isfield(cfg, 'Rsw_25mA'), 'Missing: cfg.Rsw_25mA');
assert(isfield(cfg, 'Rsw_30mA'), 'Missing: cfg.Rsw_30mA');
assert(isfield(cfg, 'Rsw_35mA'), 'Missing: cfg.Rsw_35mA');
assert(isfield(cfg, 'Rsw_45mA'), 'Missing: cfg.Rsw_45mA');

Rsw_exp = [ ...
    cfg.Rsw_15mA(:), ...
    cfg.Rsw_20mA(:), ...
    cfg.Rsw_25mA(:), ...
    cfg.Rsw_30mA(:), ...
    cfg.Rsw_35mA(:), ...
    cfg.Rsw_45mA(:) ];

assert(size(Rsw_exp, 1) == numel(Tsw), ...
    'Length mismatch: experimental data does not match model Tsw grid');

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

fprintf('Computing metrics:\n');
fprintf('%s\n', repmat('-', 1, 80));

% =========================================================
% CONSTRUCT Tp BEFORE LOOP
% =========================================================
Tp = vertcat(state.pauseRuns.waitK);  % Extract pause temperatures

% =========================================================
% LOOP OVER J VALUES
% =========================================================
for k = 1:nJ

    J = J_list(k);
    dR_exp = Rsw_exp(:, k);

    % =====================================================
    % CALL PRODUCTION MODEL
    % =====================================================

    % Use stage8 global fit parameters
    params.J = J;
    params.alpha = p8.alpha;
    params.J0 = p8.J0;
    params.Jc = p8.Jc;
    params.dJ = p8.dJ;

    result = reconstructSwitchingAmplitude( ...
        'experimental', ...
        pauseRuns, ...
        pauseRuns, ...
        params, ...
        Tp, ...
        Tsw, ...
        dR_exp);

    dR_model = result.Rhat;
    fprintf('J=%d: min(model)=%.3g, max(model)=%.3g | min(exp)=%.3g, max(exp)=%.3g\n', ...
        J, min(dR_model), max(dR_model), min(dR_exp), max(dR_exp))

    if isfield(result,'Tsw_valid') && ~isempty(result.Tsw_valid)
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

    A_vec = result.A_basis;
    B_vec = result.B_basis;
    wA_prod = result.wA;
    wB_prod = result.wB;

    % =====================================================
    % (1) NORMALIZED SHAPE CORRELATION
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
    % (2) T*(J) COMPARISON
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
    % (EXTRA) Peak shift after baseline subtraction
    % =====================================================
    idxBase = (Tsw >= 4 & Tsw <= 8);      % low-T window
    b = mean(dR_exp(idxBase));            % estimate baseline
    dR_exp0 = dR_exp - b;                 % remove baseline

    [pk0, i0] = max(dR_exp0);
    Tpk0 = Tsw(i0);

    fprintf('   Baseline=%.4g | Raw T*=%.2f K | Baseline-removed T*=%.2f K\n', ...
        b, T_star_exp(k), Tpk0);
    % =====================================================
    % (3) BALANCE CONDITION
    % =====================================================
    assert(numel(A_vec)==numel(Tsw) && numel(B_vec)==numel(Tsw), ...
        'A/B basis length mismatch');

    assert(wA_prod ~= 0, 'wA is zero at J=%g', J);

    if abs(A_vec(idx_exp)) < 1e-12
        warning('Skipping balance test at J=%g (A(T*) ~ 0)', J);
        ratio_data(k)  = NaN;
        ratio_model(k) = NaN;
        balance_error(k) = NaN;
    else
        ratio_data(k)  = B_vec(idx_exp) / A_vec(idx_exp);
        ratio_model(k) = wB_prod / wA_prod;
        balance_error(k) = abs(ratio_data(k) - ratio_model(k));
    end


    fprintf('J=%3d mA: corr=%.4f, T*_exp=%.2f K, T*_mod=%.2f K, ΔT=%+.2f K\n', ...
        J, corr_shape(k), T_star_exp(k), T_star_model(k), delta_T(k));
end

fprintf('%s\n', repmat('-', 1, 80));

% =========================================================
% BUILD RESULTS TABLE
% =========================================================
fprintf('\nResults Table\n');

results_table = table( ...
    J_list(:), ...
    corr_shape(:), ...
    T_star_exp(:), ...
    T_star_model(:), ...
    delta_T(:), ...
    ratio_data(:), ...
    ratio_model(:), ...
    balance_error(:), ...
    'VariableNames', { ...
    'J_mA', ...
    'corr_shape', ...
    'T_star_exp_K', ...
    'T_star_model_K', ...
    'delta_T_K', ...
    'ratio_data', ...
    'ratio_model', ...
    'balance_error' ...
    });

disp(results_table);

% =========================================================
% SUMMARY METRICS
% =========================================================
fprintf('\n--- PRL Validation Summary ---\n');
fprintf('Mean shape correlation: %.4f\n', nanmean(corr_shape));
fprintf('Max |delta_T| (K): %.4f\n', max(abs(delta_T)));
fprintf('Max balance error: %.4f\n', max(balance_error));
fprintf('\n--- Global Fit Results (Stage8) ---\n');
fprintf('SSE_initial     = %.6g\n', p8.SSE_initial);
fprintf('SSE_final       = %.6g\n', p8.SSE_final);
fprintf('alpha (K/mA)    = %.6g\n', p8.alpha);
fprintf('J0 (mA)         = %.6g\n', p8.J0);
fprintf('Jc (mA)         = %.6g\n', p8.Jc);
fprintf('dJ (mA)         = %.6g\n', p8.dJ);
fprintf('--------------------------------\n\n');
