function state = stage8_globalJfit_shiftGating(state, cfg, Jlist)
% =========================================================
% stage8_globalJfit_shiftGating
%
% Global optimization of J-dependent shift and gating model:
%   R(T,J) = (1-g(J))*A(T-δ(J)) + g(J)*B(T) + c
%   δ(J) = alpha*(J - J0)
%   g(J) = 1/(1 + exp(-(J - Jc)/dJ))
%
% Uses prediction path already established in state/cfg.
%
% INPUTS:
%   state  - struct with stage7 outputs (Tsw, Rsw, masks)
%   cfg    - configuration struct
%   Jlist  - vector of current values [J1, J2, ..., Jn] with n > 1
%
% OUTPUTS:
%   state  - updated with state.stage8 containing fit results
%
% =========================================================

% Initialize output struct
state.stage8 = struct();

% =====================================================================
% DIAGNOSTICS FLAG
% =====================================================================
diagnostics = true;  % Set to false to suppress diagnostic printing and plots

% =====================================================================
% A) VALIDATE INPUTS & EXTRACT DATA
% =====================================================================

Jlist = Jlist(:);
assert(numel(Jlist) > 1, 'stage8 requires Jlist with >1 current value');

% Determine temperature grid from stage7 outputs
Tsw = firstField(state, cfg, {'stage7.Tsw','result.Tsw','Tsw','cfg.Tsw'});
if isempty(Tsw)
    error('stage8: Could not find Tsw in stage7/result/state/cfg');
end
Tsw = Tsw(:);
nT = numel(Tsw);

% Determine valid temperature mask
try
    Tsw_valid = firstField(state, cfg, {'stage7.Tsw_valid','result.Tsw_valid','Tsw_valid'});
catch
    Tsw_valid = [];
end
if ~isempty(Tsw_valid)
    mask = ismember(Tsw(:), Tsw_valid(:));
else
    mask = true(size(Tsw(:)));
end

if ~any(mask)
    mask = true(size(Tsw(:)));
end

state.stage8.Tmask = mask;
nValid = nnz(mask);

% Load model bases from stage7 outputs
A_basis = firstField(state, cfg, {'stage7.A_basis','result.A_basis','A_basis'});
B_basis = firstField(state, cfg, {'stage7.B_basis','result.B_basis','B_basis'});
if isempty(A_basis) || isempty(B_basis)
    error('stage8: Could not find A_basis/B_basis in stage7/result/state');
end
A_basis = A_basis(:);
B_basis = B_basis(:);
if numel(A_basis) ~= nT || numel(B_basis) ~= nT
    error('stage8: A/B basis length mismatch with Tsw');
end

% Optional constant offset
try
    C_basis = firstField(state, cfg, {'stage7.C_basis','result.C_basis','C_basis'});
catch
    C_basis = [];
end
if ~isempty(C_basis) && isscalar(C_basis)
    c0 = C_basis;
else
    c0 = 0;
end

% Build experimental data matrix from cfg.Rsw_*mA fields
Rexp = zeros(nT, numel(Jlist));
missing = [];
for iJ = 1:numel(Jlist)
    fieldName = sprintf('Rsw_%dmA', Jlist(iJ));
    if isfield(cfg, fieldName) && ~isempty(cfg.(fieldName))
        vec = cfg.(fieldName)(:);
        if numel(vec) ~= nT
            error('stage8: %s length (%d) does not match Tsw (%d)', fieldName, numel(vec), nT);
        end
        Rexp(:, iJ) = vec;
    else
        missing(end+1) = Jlist(iJ); %#ok<AGROW>
    end
end

if ~isempty(missing)
    error('stage8: Missing Rsw_*mA fields for J = %s', mat2str(missing));
end

% =====================================================================
% B) PRECOMPUTE COLUMN VECTORS (Improvement #6)
% =====================================================================
Tsw = Tsw(:);
A_basis = A_basis(:);
B_basis = B_basis(:);
mask = mask(:);
Tsw_range = max(Tsw) - min(Tsw);

% Guard against mask dimension mismatch (Improvement #8)
if numel(mask) ~= numel(Tsw)
    error('stage8: mask size (%d) mismatch with Tsw (%d)', numel(mask), numel(Tsw));
end

% =====================================================================
% C) PARAMETERIZATION & INITIAL GUESS
% =====================================================

alpha0 = 0;
J00 = median(Jlist);
Jc0 = median(Jlist);
dJ0 = (max(Jlist) - min(Jlist)) / 6;

% Override with cfg if available
if isfield(cfg, 'stage8') && isfield(cfg.stage8, 'alpha')
    alpha0 = cfg.stage8.alpha;
end
if isfield(cfg, 'stage8') && isfield(cfg.stage8, 'J0')
    J00 = cfg.stage8.J0;
end
if isfield(cfg, 'stage8') && isfield(cfg.stage8, 'Jc')
    Jc0 = cfg.stage8.Jc;
end
if isfield(cfg, 'stage8') && isfield(cfg.stage8, 'dJ')
    dJ0 = cfg.stage8.dJ;
end

theta0 = [alpha0, J00, Jc0, dJ0];

% =====================================================================
% D) OBJECTIVE FUNCTION (GLOBAL SSE)
% =====================================================================

obj = @(theta) globalJObjective(theta, Jlist, Tsw, Rexp, mask, A_basis, B_basis, c0, Tsw_range);

% Compute initial SSE (without penalties for reporting)
sse0_penalized = obj(theta0);

% Evaluate raw SSE at initial guess
sse0_raw = globalJObjectiveRaw(theta0, Jlist, Tsw, Rexp, mask, A_basis, B_basis, c0);

% =====================================================================
% E) OPTIMIZE
% =====================================================

opts = optimset('Display', 'off', 'MaxIter', 300, 'TolX', 1e-4, 'TolFun', 1e-4);
if isfield(cfg, 'debug') && isfield(cfg.debug, 'verbose') && cfg.debug.verbose
    opts = optimset(opts, 'Display', 'iter');
end

theta_final = fminsearch(obj, theta0, opts);

% Evaluate final SSE (raw, no penalties)
sse_final_raw = globalJObjectiveRaw(theta_final, Jlist, Tsw, Rexp, mask, A_basis, B_basis, c0);

% Compute model residuals for diagnostics
[Rmodel_all, g_values, delta_values] = computeAllModels(theta_final, Jlist, Tsw, Rexp, mask, A_basis, B_basis, c0);

% =====================================================================
% F) STORE OUTPUTS
% =====================================================================


state.stage8.theta0 = theta0;
state.stage8.theta = theta_final;
state.stage8.alpha = theta_final(1);
state.stage8.J0 = theta_final(2);
state.stage8.Jc = theta_final(3);
state.stage8.dJ = theta_final(4);
state.stage8.SSE_initial = sse0_raw;
state.stage8.SSE_final = sse_final_raw;
state.stage8.SSE_ratio = sse_final_raw / max(sse0_raw, 1e-12);
state.stage8.Jlist = Jlist;
state.stage8.Rmodel_all = Rmodel_all;
state.stage8.g_values = g_values;
state.stage8.delta_values = delta_values;
state.stage8.mask = mask;
state.stage8.Tsw = Tsw;
state.stage8.A_basis = A_basis;
state.stage8.B_basis = B_basis;
state.stage8.Rexp = Rexp;

% =====================================================================
% G) PRINT AND PLOT DIAGNOSTICS
% =====================================================================

if diagnostics
    printDiagnosticsBlock(Tsw, Jlist, A_basis, B_basis, mask, theta0, theta_final, sse0_raw, sse_final_raw, Rexp);
    plotDiagnostics(Tsw, Jlist, Rexp, Rmodel_all, g_values, delta_values, mask);
end

end

% =====================================================================
% HELPER FUNCTIONS
% =====================================================================

function v = firstField(state, cfg, candidates)
% Return the first existing field path from candidates
v = [];
for i = 1:numel(candidates)
    path = candidates{i};
    parts = strsplit(path, '.');
    if strcmp(parts{1}, 'cfg')
        base = cfg;
        parts = parts(2:end);
    else
        base = state;
    end
    ok = true;
    for k = 1:numel(parts)
        if ~isfield(base, parts{k})
            ok = false;
            break;
        end
        base = base.(parts{k});
    end
    if ok && ~isempty(base)
        v = base;
        return;
    end
end
error('stage8: None of the candidate fields exist: %s', strjoin(candidates, ', '));
end

function sse = globalJObjective(theta, Jlist, Tsw, Rexp, mask, A_basis, B_basis, c0, Tsw_range)
% Objective function WITH soft bound penalties
sse = globalJObjectiveRaw(theta, Jlist, Tsw, Rexp, mask, A_basis, B_basis, c0);

% Soft bound penalties
alpha = theta(1);
J0 = theta(2);
Jc = theta(3);
dJ = theta(4);

penalty = 0;

% Improvement #5: Guard against extremely small dJ
if dJ < 1e-3
    penalty = penalty + 1e4;
end

% Improvement #4: Enforce positive dJ
if dJ <= 0
    penalty = penalty + 1e6;
end

% Improvement #3: Penalize excessive temperature shift
delta_max = max(abs(alpha * (Jlist - J0)));
if delta_max > 0.5 * Tsw_range
    penalty = penalty + 1e5;
end

sse = sse + penalty;
end

function sse = globalJObjectiveRaw(theta, Jlist, Tsw, Rexp, mask, A_basis, B_basis, c0)
% Compute raw SSE (no penalties) across all J values
sse = 0;
nT = numel(Tsw);

for iJ = 1:numel(Jlist)
    J = Jlist(iJ);
    
    if size(Rexp, 1) ~= nT || size(Rexp, 2) < iJ
        error('stage8: Rexp size mismatch at J=%g', J);
    end
    
    % Improvement #2: Enforce column vector shapes
    Rexp_J = Rexp(:, iJ);
    
    % Use helper function to compute model for this J
    [~, sse_J, ~] = computeModelForJ(J, theta(1), theta(2), theta(3), theta(4), Tsw, Rexp_J, mask, A_basis, B_basis, c0);
    
    sse = sse + sse_J;
end
end

function [Rmodel, sse_J, g_val] = computeModelForJ(J, alpha, J0, Jc, dJ, Tsw, Rexp_J, mask, A_basis, B_basis, c0)
% Compute model for a single current value J
% OUTPUTS:
%   Rmodel - predicted R(T) for this J (nT x 1)
%   sse_J  - sum of squared residuals for valid points
%   g_val  - logistic gating value at J

delta = alpha * (J - J0);

% Improved logistic numerical stability
x = (J - Jc) / dJ;
g_val = 1 ./ (1 + exp(-x));

% Prevent unstable extrapolation
A_shifted = interp1(Tsw, A_basis, Tsw - delta, 'linear', NaN);
Rmodel = (1 - g_val) * A_shifted + g_val * B_basis + c0;

% Use validMask to exclude NaN extrapolation artifacts
validMask = mask & ~isnan(A_shifted);

Rexp_J = Rexp_J(:);
residual = Rmodel(validMask) - Rexp_J(validMask);

% Robust SSE accumulation
sse_J = nansum(residual.^2);
end

function [Rmodel_all, g_values, delta_values] = computeAllModels(theta, Jlist, Tsw, Rexp, mask, A_basis, B_basis, c0)
% Compute model for all currents (for diagnostics)
alpha = theta(1);
J0 = theta(2);
Jc = theta(3);
dJ = theta(4);

nJ = numel(Jlist);
nT = numel(Tsw);

Rmodel_all = zeros(nT, nJ);
g_values = zeros(nJ, 1);
delta_values = zeros(nJ, 1);

for iJ = 1:nJ
    J = Jlist(iJ);
    Rexp_J = Rexp(:, iJ);
    
    [Rmodel, ~, g_val] = computeModelForJ(J, alpha, J0, Jc, dJ, Tsw, Rexp_J, mask, A_basis, B_basis, c0);
    
    Rmodel_all(:, iJ) = Rmodel;
    g_values(iJ) = g_val;
    delta_values(iJ) = alpha * (J - J0);
end
end

function printDiagnosticsBlock(Tsw, Jlist, A_basis, B_basis, mask, theta0, theta_final, sse0_raw, sse_final_raw, Rexp)
% Print comprehensive diagnostic summary with checks

alpha = theta_final(1);
J0 = theta_final(2);
Jc = theta_final(3);
dJ = theta_final(4);

alpha0 = theta0(1);
J0_0 = theta0(2);
Jc0 = theta0(3);
dJ0 = theta0(4);

fprintf('\n');
fprintf('==============================\n');
fprintf('Stage8 Global J Fit\n');
fprintf('==============================\n');
fprintf('\n');

% Currents
fprintf('Currents (Jlist):\n');
fprintf('  [%.1f ... %.1f] mA\n', min(Jlist), max(Jlist));
fprintf('  Number of currents: %d\n', numel(Jlist));

% Temperature grid
fprintf('\nTemperature grid:\n');
fprintf('  [%.2f ... %.2f] K\n', min(Tsw), max(Tsw));
fprintf('  nT = %d\n', numel(Tsw));

% Mask coverage
fprintf('\nMask coverage:\n');
fprintf('  sum(mask) / length(mask) = %d / %d = %.1f%%\n', nnz(mask), numel(mask), 100*nnz(mask)/numel(mask));

% Basis stats
fprintf('\nBasis stats:\n');
fprintf('  A_basis: [%.6g ... %.6g]\n', min(A_basis), max(A_basis));
fprintf('  B_basis: [%.6g ... %.6g]\n', min(B_basis), max(B_basis));

% Initial parameters
fprintf('\nInitial parameters:\n');
fprintf('  alpha = %.6g K/mA\n', alpha0);
fprintf('  J0    = %.6g mA\n', J0_0);
fprintf('  Jc    = %.6g mA\n', Jc0);
fprintf('  dJ    = %.6g mA\n', dJ0);

% Optimized parameters
fprintf('\nOptimized parameters:\n');
fprintf('  alpha = %.6g K/mA\n', alpha);
fprintf('  J0    = %.6g mA\n', J0);
fprintf('  Jc    = %.6g mA\n', Jc);
fprintf('  dJ    = %.6g mA\n', dJ);

% Fit quality
fprintf('\nFit quality:\n');
fprintf('  SSE_initial = %.6g\n', sse0_raw);
fprintf('  SSE_final   = %.6g\n', sse_final_raw);
ratio = sse_final_raw / max(sse0_raw, 1e-12);
fprintf('  SSE_ratio   = %.6g%%\n', 100*ratio);

% ===== SANITY CHECKS =====
fprintf('\n[Sanity Checks]\n');

% Check 1: NaN in bases
if any(isnan(A_basis)) || any(isnan(B_basis))
    fprintf('[Stage8 Warning] NaN values detected in A_basis or B_basis\n');
else
    fprintf('  ~ A_basis and B_basis are clean (no NaN)\n');
end

% Check 2: Mask size mismatch
if numel(mask) ~= numel(Tsw)
    fprintf('[Stage8 Warning] Mask size mismatch: mask=%d, Tsw=%d\n', numel(mask), numel(Tsw));
else
    fprintf('  ~ Mask size matches Tsw\n');
end

% Check 3: Delta larger than temperature window
Tsw_range = max(Tsw) - min(Tsw);
delta_max = max(abs(alpha * (Jlist - J0)));
if delta_max > 0.5 * Tsw_range
    fprintf('[Stage8 Warning] Large peak shift: max(|∆T|)=%.3f > 0.5*Tsw_range=%.3f\n', delta_max, 0.5*Tsw_range);
else
    fprintf('  ~ Peak shift within reasonable bounds (%.3f < %.3f K)\n', delta_max, 0.5*Tsw_range);
end

% Check 4: Extremely small dJ
if dJ < 1e-3
    fprintf('[Stage8 Warning] Extremely small dJ (%.6g < 1e-3): logistic may be step-like\n', dJ);
else
    fprintf('  ~ dJ is reasonable (%.6g mA)\n', dJ);
end

% Check 5: g(J) values outside [0,1]
g_at_Jlist = 1 ./ (1 + exp(-((Jlist - Jc) / dJ)));
if any(g_at_Jlist < -0.01) || any(g_at_Jlist > 1.01)
    fprintf('[Stage8 Warning] g(J) values outside expected range [0,1]\n');
else
    fprintf('  ~ g(J) properly bounded in [%.3f, %.3f]\n', min(g_at_Jlist), max(g_at_Jlist));
end

fprintf('==============================\n\n');
end

function plotDiagnostics(Tsw, Jlist, Rexp, Rmodel_all, g_values, delta_values, mask)
% Generate diagnostic plots

% Figure 1: Experimental vs Model curves
fig1 = figure();
set(fig1, 'Position', [100, 100, 1200, 600]);
set(fig1, 'Name', 'Stage8 Global Fit Diagnostics');

n_cols = min(ceil(sqrt(numel(Jlist))), 4);
n_rows = ceil(numel(Jlist) / n_cols);

for iJ = 1:numel(Jlist)
    J = Jlist(iJ);
    
    subplot(n_rows, n_cols, iJ);
    hold on;
    
    % Plot experimental data at valid mask points
    plot(Tsw(mask), Rexp(mask, iJ), 'o', 'MarkerSize', 4, 'MarkerEdgeColor', [0.2, 0.2, 0.8], 'LineStyle', 'none');
    
    % Plot model
    plot(Tsw, Rmodel_all(:, iJ), '-', 'Color', [0.8, 0.2, 0.2], 'LineWidth', 1.5);
    
    xlabel('T (K)');
    ylabel('R (Omega)');
    title(sprintf('J = %.0f mA, g = %.3f', J, g_values(iJ)));
    grid on;
    legend('Exp (masked)', 'Model', 'Location', 'best');
    hold off;
end

sgtitle('Stage8 Global Fit: Experimental vs Model', 'FontSize', 12, 'FontWeight', 'bold');

% Figure 2: Logistic gating g(J) vs current
fig2 = figure();
set(fig2, 'Position', [100, 750, 500, 400]);
set(fig2, 'Name', 'Stage8 Gating Function');

plot(Jlist, g_values, 'o-', 'MarkerSize', 6, 'MarkerFaceColor', [0.2, 0.8, 0.2], 'LineWidth', 1.5, 'Color', [0.2, 0.6, 0.2]);
xlabel('Current (mA)', 'FontSize', 11);
ylabel('g(J) [logistic gating]', 'FontSize', 11);
title('Stage8: Logistic Gating Function', 'FontSize', 12, 'FontWeight', 'bold');
grid on;
set(gca, 'YLim', [-0.1, 1.1]);

% Figure 3: Peak shift delta(J) vs current
fig3 = figure();
set(fig3, 'Position', [650, 750, 500, 400]);
set(fig3, 'Name', 'Stage8 Peak Shift');

plot(Jlist, delta_values, 'o-', 'MarkerSize', 6, 'MarkerFaceColor', [0.8, 0.6, 0.2], 'LineWidth', 1.5, 'Color', [0.8, 0.4, 0.2]);
xlabel('Current (mA)', 'FontSize', 11);
ylabel('Temperature shift ∆T (K)', 'FontSize', 11);
title('Stage8: Peak Shift vs Current', 'FontSize', 12, 'FontWeight', 'bold');
grid on;
end
