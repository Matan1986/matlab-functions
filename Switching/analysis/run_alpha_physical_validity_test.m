% run_alpha_physical_validity_test
% Pure script (no local functions).
% Uses manual T_K alignment with tolerance, no innerjoin.

fprintf('[RUN] run_alpha_physical_validity_test\n');
clearvars;

repoRoot = 'C:/Dev/matlab-functions';
scriptPath = 'C:/Dev/matlab-functions/Switching/analysis/run_alpha_physical_validity_test.m';

alphaPath = 'C:/Dev/matlab-functions/tables/alpha_structure.csv';
clockRatioPath = 'C:/Dev/matlab-functions/results/aging/runs/run_2026_03_14_074613_aging_clock_ratio_analysis/tables/table_clock_ratio.csv';

outTablePath = 'C:/Dev/matlab-functions/tables/alpha_stability_test.csv';
outReportPath = 'C:/Dev/matlab-functions/reports/alpha_physical_validity.md';
outStatusPath = 'C:/Dev/matlab-functions/tables/alpha_physical_validity_status.csv';
errorLogPath = 'C:/Dev/matlab-functions/matlab_error.log';

if exist('C:/Dev/matlab-functions/tables', 'dir') ~= 7, mkdir('C:/Dev/matlab-functions/tables'); end
if exist('C:/Dev/matlab-functions/reports', 'dir') ~= 7, mkdir('C:/Dev/matlab-functions/reports'); end

stabilityTbl = table();
statusTbl = table();
md = strings(0, 1);

EXECUTION_STATUS = "FAIL";
INPUT_FOUND = "NO";
N_T = 0;
ERROR_MESSAGE = "";
MAIN_RESULT_SUMMARY = "";

ALPHA_STABLE = "NO";
ALPHA_PHYSICAL = "NO";
KAPPA2_SUPERIOR_TO_ALPHA = "NO";

try
    if exist(alphaPath, 'file') ~= 2
        error('run_alpha_physical_validity_test:MissingAlpha', 'Missing alpha table: %s', alphaPath);
    end
    if exist(clockRatioPath, 'file') ~= 2
        error('run_alpha_physical_validity_test:MissingClock', 'Missing clock-ratio table: %s', clockRatioPath);
    end
    INPUT_FOUND = "YES";

    A = readtable(alphaPath, 'VariableNamingRule', 'preserve');
    aNames = string(A.Properties.VariableNames);
    aNamesLow = lower(aNames);
    idxT = find(contains(aNamesLow, 't_k') | contains(aNamesLow, 'temp'), 1, 'first');
    idxK1 = find(contains(aNamesLow, 'kappa1'), 1, 'first');
    idxK2 = find(contains(aNamesLow, 'kappa2'), 1, 'first');
    if isempty(idxT) || isempty(idxK1) || isempty(idxK2)
        error('run_alpha_physical_validity_test:MissingColumns', 'alpha_structure.csv must provide T_K, kappa1, kappa2 (contains-based detection).');
    end

    T = double(A{:, idxT});
    k1 = double(A{:, idxK1});
    k2 = double(A{:, idxK2});

    alpha = NaN(size(k1));
    mDen = isfinite(k1) & abs(k1) > eps & isfinite(k2);
    alpha(mDen) = k2(mDen) ./ k1(mDen);

    validBase = isfinite(T) & isfinite(k1) & isfinite(k2) & isfinite(alpha);
    T = T(validBase);
    k1 = k1(validBase);
    k2 = k2(validBase);
    alpha = alpha(validBase);

    [T, ord] = sort(T, 'ascend');
    k1 = k1(ord);
    k2 = k2(ord);
    alpha = alpha(ord);
    N_T = numel(T);
    if N_T < 5
        error('run_alpha_physical_validity_test:TooFewRows', 'Need at least 5 valid temperatures, got %d.', N_T);
    end

    % STEP 1: alpha vs kappa2 comparison
    rho_alpha_k2 = corr(alpha, k2, 'rows', 'pairwise');
    rhoS_alpha_k2 = corr(alpha, k2, 'type', 'Spearman', 'rows', 'pairwise');
    alpha_cv = std(alpha, 'omitnan') / max(abs(mean(alpha, 'omitnan')), eps);
    k2_cv = std(k2, 'omitnan') / max(abs(mean(k2, 'omitnan')), eps);

    % STEP 2: leave-one-point-out recomputation
    alpha_loo = NaN(N_T, 1);
    alpha_loo_abs_delta = NaN(N_T, 1);
    alpha_loo_rel_delta = NaN(N_T, 1);
    for i = 1:N_T
        tr = true(N_T, 1);
        tr(i) = false;
        Ttr = T(tr);
        k1tr = k1(tr);
        k2tr = k2(tr);
        if numel(Ttr) < 2
            continue;
        end
        k1_hat = interp1(Ttr, k1tr, T(i), 'linear', 'extrap');
        k2_hat = interp1(Ttr, k2tr, T(i), 'linear', 'extrap');
        if isfinite(k1_hat) && abs(k1_hat) > eps && isfinite(k2_hat)
            a_hat = k2_hat / k1_hat;
            alpha_loo(i) = a_hat;
            alpha_loo_abs_delta(i) = abs(a_hat - alpha(i));
            alpha_loo_rel_delta(i) = abs(a_hat - alpha(i)) / max(abs(alpha(i)), eps);
        end
    end
    loo_rel_median = median(alpha_loo_rel_delta, 'omitnan');
    loo_rel_p95 = prctile(alpha_loo_rel_delta(isfinite(alpha_loo_rel_delta)), 95);

    % STEP 3: noise sensitivity (noise on kappa1)
    rng(42);
    nMC = 300;
    noiseFrac = 0.01;
    alpha_noisy = NaN(N_T, nMC);
    for r = 1:nMC
        k1n = k1 .* (1 + noiseFrac * randn(N_T, 1));
        m = abs(k1n) > eps & isfinite(k1n) & isfinite(k2);
        aN = NaN(N_T, 1);
        aN(m) = k2(m) ./ k1n(m);
        alpha_noisy(:, r) = aN;
    end
    noise_std_alpha = std(alpha_noisy, 0, 2, 'omitnan');
    noise_abs_delta_med = median(abs(alpha_noisy - alpha), 2, 'omitnan');
    noise_rel_delta_med = noise_abs_delta_med ./ max(abs(alpha), eps);
    noise_rel_median = median(noise_rel_delta_med, 'omitnan');
    noise_rel_p95 = prctile(noise_rel_delta_med(isfinite(noise_rel_delta_med)), 95);

    % STEP 5: predictive power comparison
    C = readtable(clockRatioPath, 'VariableNamingRule', 'preserve');
    cNames = string(C.Properties.VariableNames);
    cNamesLow = lower(cNames);
    idxCT = find(contains(cNamesLow, 't_k') | cNamesLow == "tp" | contains(cNamesLow, 'temp'), 1, 'first');
    idxCR = find(contains(cNamesLow, 'r_tau_fm_over_tau_dip') | (contains(cNamesLow, 'r_') & contains(cNamesLow, 'over')), 1, 'first');
    if isempty(idxCT) || isempty(idxCR)
        error('run_alpha_physical_validity_test:ClockColumns', ...
            'table_clock_ratio.csv must provide temperature and R column (contains-based detection).');
    end
    Tc = double(C{:, idxCT});
    Rc = double(C{:, idxCR});

    tTol = 0.25;
    Tm = NaN(N_T, 1);
    Rm = NaN(N_T, 1);
    for i = 1:N_T
        dT = abs(Tc - T(i));
        [dMin, idxMin] = min(dT);
        if isfinite(dMin) && dMin <= tTol
            Tm(i) = Tc(idxMin);
            Rm(i) = Rc(idxMin);
        end
    end

    mPred = isfinite(Rm) & isfinite(k1) & isfinite(k2) & isfinite(alpha);
    y = Rm(mPred);
    xk1 = k1(mPred);
    xk2 = k2(mPred);
    xa = alpha(mPred);
    Tpred = T(mPred);

    nPred = numel(y);
    rmse_k1k2 = NaN; pear_k1k2 = NaN; spear_k1k2 = NaN;
    rmse_k1a = NaN; pear_k1a = NaN; spear_k1a = NaN;
    rmse_base = NaN;

    if nPred >= 4
        yhat_base = NaN(nPred, 1);
        yhat_k1k2 = NaN(nPred, 1);
        yhat_k1a = NaN(nPred, 1);
        for i = 1:nPred
            tr = true(nPred, 1);
            tr(i) = false;
            ytr = y(tr);

            yhat_base(i) = mean(ytr, 'omitnan');

            Z12 = [ones(nnz(tr), 1), xk1(tr), xk2(tr)];
            b12 = pinv(Z12) * ytr;
            yhat_k1k2(i) = [1, xk1(i), xk2(i)] * b12;

            Z1a = [ones(nnz(tr), 1), xk1(tr), xa(tr)];
            b1a = pinv(Z1a) * ytr;
            yhat_k1a(i) = [1, xk1(i), xa(i)] * b1a;
        end

        rmse_base = sqrt(mean((y - yhat_base).^2, 'omitnan'));
        rmse_k1k2 = sqrt(mean((y - yhat_k1k2).^2, 'omitnan'));
        rmse_k1a = sqrt(mean((y - yhat_k1a).^2, 'omitnan'));

        mk = isfinite(y) & isfinite(yhat_k1k2);
        ma = isfinite(y) & isfinite(yhat_k1a);
        if nnz(mk) >= 2
            pear_k1k2 = corr(y(mk), yhat_k1k2(mk), 'rows', 'pairwise');
            spear_k1k2 = corr(y(mk), yhat_k1k2(mk), 'type', 'Spearman', 'rows', 'pairwise');
        end
        if nnz(ma) >= 2
            pear_k1a = corr(y(ma), yhat_k1a(ma), 'rows', 'pairwise');
            spear_k1a = corr(y(ma), yhat_k1a(ma), 'type', 'Spearman', 'rows', 'pairwise');
        end
    end

    % Verdicts
    if isfinite(loo_rel_median) && isfinite(noise_rel_median) && isfinite(loo_rel_p95) && isfinite(noise_rel_p95) && ...
            loo_rel_median <= 0.15 && noise_rel_median <= 0.10 && loo_rel_p95 <= 0.60 && noise_rel_p95 <= 0.40
        ALPHA_STABLE = "YES";
    end

    if isfinite(rmse_k1a) && isfinite(rmse_k1k2) && ALPHA_STABLE == "YES" && rmse_k1a <= 1.05 * rmse_k1k2
        ALPHA_PHYSICAL = "YES";
    end

    if isfinite(rmse_k1k2) && isfinite(rmse_k1a) && rmse_k1k2 < rmse_k1a - 1e-12
        KAPPA2_SUPERIOR_TO_ALPHA = "YES";
    end

    stabilityTbl = table( ...
        T, k1, k2, alpha, ...
        alpha_loo, alpha_loo_abs_delta, alpha_loo_rel_delta, ...
        noise_std_alpha, noise_abs_delta_med, noise_rel_delta_med, ...
        'VariableNames', { ...
        'T_K', 'kappa1', 'kappa2', 'alpha', ...
        'alpha_loo_recomputed', 'alpha_loo_abs_delta', 'alpha_loo_rel_delta', ...
        'alpha_noise_std', 'alpha_noise_median_abs_delta', 'alpha_noise_median_rel_delta'});

    EXECUTION_STATUS = "SUCCESS";
    MAIN_RESULT_SUMMARY = sprintf(['nT=%d | rho(alpha,k2)=%.4f | median LOO rel=%.4g | median noise rel=%.4g | ' ...
        'rmse(k1+k2)=%.4g vs rmse(k1+alpha)=%.4g'], ...
        N_T, rho_alpha_k2, loo_rel_median, noise_rel_median, rmse_k1k2, rmse_k1a);

    md(end+1) = "# Alpha physical validity test";
    md(end+1) = "";
    md(end+1) = "Script: `" + string(scriptPath) + "`";
    md(end+1) = "Alpha input: `" + string(alphaPath) + "`";
    md(end+1) = "R input: `" + string(clockRatioPath) + "`";
    md(end+1) = "";
    md(end+1) = "## Step 1: alpha vs kappa2";
    md(end+1) = sprintf('- Pearson(alpha, kappa2) = %.6g', rho_alpha_k2);
    md(end+1) = sprintf('- Spearman(alpha, kappa2) = %.6g', rhoS_alpha_k2);
    md(end+1) = sprintf('- CV(alpha) = %.6g, CV(kappa2) = %.6g', alpha_cv, k2_cv);
    md(end+1) = "";
    md(end+1) = "## Step 2: leave-one-point-out alpha recomputation";
    md(end+1) = sprintf('- median relative change = %.6g', loo_rel_median);
    md(end+1) = sprintf('- p95 relative change = %.6g', loo_rel_p95);
    md(end+1) = "";
    md(end+1) = "## Step 3: noise sensitivity (1% kappa1 noise)";
    md(end+1) = sprintf('- median relative alpha change = %.6g', noise_rel_median);
    md(end+1) = sprintf('- p95 relative alpha change = %.6g', noise_rel_p95);
    md(end+1) = "";
    md(end+1) = "## Step 5: LOOCV predictive power";
    md(end+1) = sprintf('- n_pred = %d', nPred);
    md(end+1) = sprintf('- baseline RMSE (constant) = %.6g', rmse_base);
    md(end+1) = sprintf('- RMSE: R ~ kappa1 + kappa2 = %.6g | Pearson=%.6g | Spearman=%.6g', rmse_k1k2, pear_k1k2, spear_k1k2);
    md(end+1) = sprintf('- RMSE: R ~ kappa1 + alpha  = %.6g | Pearson=%.6g | Spearman=%.6g', rmse_k1a, pear_k1a, spear_k1a);
    md(end+1) = "";
    md(end+1) = "## Verdicts";
    md(end+1) = "- ALPHA_STABLE: `" + ALPHA_STABLE + "`";
    md(end+1) = "- ALPHA_PHYSICAL: `" + ALPHA_PHYSICAL + "`";
    md(end+1) = "- KAPPA2_SUPERIOR_TO_ALPHA: `" + KAPPA2_SUPERIOR_TO_ALPHA + "`";
    md(end+1) = "";
    md(end+1) = "Summary: " + string(MAIN_RESULT_SUMMARY);

catch ME
    EXECUTION_STATUS = "FAIL";
    ERROR_MESSAGE = string(ME.message);
    MAIN_RESULT_SUMMARY = "Execution failed before completing alpha validity analysis.";
    md = strings(0, 1);
    md(end+1) = "# Alpha physical validity test";
    md(end+1) = "";
    md(end+1) = "Execution failed.";
    md(end+1) = "ERROR: `" + ERROR_MESSAGE + "`";
    try
        fidErr = fopen(errorLogPath, 'a');
        if fidErr ~= -1
            fprintf(fidErr, '%s\n', getReport(ME, 'extended'));
            fclose(fidErr);
        end
    catch
    end
end

if isempty(stabilityTbl)
    stabilityTbl = table(NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
        'VariableNames', {'T_K', 'kappa1', 'kappa2', 'alpha', ...
        'alpha_loo_recomputed', 'alpha_loo_abs_delta', 'alpha_loo_rel_delta', ...
        'alpha_noise_std', 'alpha_noise_median_abs_delta', 'alpha_noise_median_rel_delta'});
end

statusTbl = table( ...
    string(EXECUTION_STATUS), string(INPUT_FOUND), string(ERROR_MESSAGE), N_T, string(MAIN_RESULT_SUMMARY), ...
    string(ALPHA_STABLE), string(ALPHA_PHYSICAL), string(KAPPA2_SUPERIOR_TO_ALPHA), ...
    'VariableNames', { ...
    'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY', ...
    'ALPHA_STABLE', 'ALPHA_PHYSICAL', 'KAPPA2_SUPERIOR_TO_ALPHA'});

writetable(stabilityTbl, outTablePath);
writetable(statusTbl, outStatusPath);
fid = fopen(outReportPath, 'w');
if fid ~= -1
    fprintf(fid, '%s\n', char(strjoin(md, newline)));
    fclose(fid);
else
    statusTbl.EXECUTION_STATUS = "FAIL_REPORT_WRITE";
    statusTbl.ERROR_MESSAGE = "Could not write markdown report.";
    writetable(statusTbl, outStatusPath);
end

fprintf('[DONE] run_alpha_physical_validity_test -> %s\n', outStatusPath);
