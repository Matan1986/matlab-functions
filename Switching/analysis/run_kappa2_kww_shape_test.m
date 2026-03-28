clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
tablesDir = 'C:/Dev/matlab-functions/tables';
reportsDir = 'C:/Dev/matlab-functions/reports';

outCsvPath = 'C:/Dev/matlab-functions/tables/kappa2_kww_shape_test.csv';
outStatusPath = 'C:/Dev/matlab-functions/tables/kappa2_kww_shape_test_status.csv';
outMdPath = 'C:/Dev/matlab-functions/reports/kappa2_kww_shape_test.md';

inRelaxPath = 'C:/Dev/matlab-functions/tables/relaxation_full_dataset.csv';
inKappaPath = 'C:/Dev/matlab-functions/tables/aging_kappa2_master_table.csv';
inPTPath = 'C:/Dev/matlab-functions/tables/kappa1_from_PT.csv';

if exist(tablesDir, 'dir') ~= 7
    mkdir(tablesDir);
end
if exist(reportsDir, 'dir') ~= 7
    mkdir(reportsDir);
end

EXECUTION_STATUS = 'FAIL';
INPUT_FOUND = 'NO';
ERROR_MESSAGE = '';
N_T = 0;
MAIN_RESULT_SUMMARY = 'Not executed';

KWW_GOOD_DESCRIPTION = 'NO';
BETA_CORRELATED_WITH_KAPPA2 = 'NO';
BETA_CORRELATED_WITH_KAPPA1 = 'NO';
BETA_CONTROLLED_BY_PT = 'PARTIAL';
KAPPA2_CONTROLS_RELAXATION_SHAPE = 'NO';

pearson_beta_kappa2 = NaN;
spearman_beta_kappa2 = NaN;
pearson_beta_kappa1 = NaN;
spearman_beta_kappa1 = NaN;
pearson_beta_pt1 = NaN;
spearman_beta_pt1 = NaN;
pearson_beta_pt2 = NaN;
spearman_beta_pt2 = NaN;

n_corr_kappa2 = 0;
n_corr_kappa1 = 0;
n_corr_pt1 = 0;
n_corr_pt2 = 0;

mean_rmse_kww = NaN;
mean_rmse_exp = NaN;
mean_rmse_log = NaN;

pt_feature1_name = 'NA';
pt_feature2_name = 'NA';
normalization_choice = 'Per-temperature min-max normalization on M(T,t), then orientation fixed to decay from ~1 to ~0.';

resultTbl = table('Size', [0, 17], ...
    'VariableTypes', {'double','double','double','double','double','double','double','double','double','double','double','double','double','double','double','double','double'}, ...
    'VariableNames', {'T_relax_K','T_kappa_K','T_pt_K','N_points_total','N_points_fit','beta','tau_s','tau_exp_s','rmse_kww','rmse_exp','rmse_log','beta_drop_early','beta_drop_late','beta_robust_span','kappa1','kappa2','pt_feature1'});

mdLines = {};
mdLines{end + 1} = '# kappa2 kww shape test';
mdLines{end + 1} = '';
mdLines{end + 1} = 'Execution failed before full analysis.';

try
    hasRelax = (exist(inRelaxPath, 'file') == 2);
    hasKappa = (exist(inKappaPath, 'file') == 2);
    hasPT = (exist(inPTPath, 'file') == 2);

    if hasRelax && hasKappa
        INPUT_FOUND = 'YES';
    else
        INPUT_FOUND = 'NO';
        error('Missing required input(s): relaxation=%d kappa=%d', hasRelax, hasKappa);
    end

    relaxTbl = readtable(inRelaxPath, 'VariableNamingRule', 'preserve');
    kappaTbl = readtable(inKappaPath, 'VariableNamingRule', 'preserve');
    if hasPT
        ptTbl = readtable(inPTPath, 'VariableNamingRule', 'preserve');
    else
        ptTbl = table();
    end

    relaxNames = string(relaxTbl.Properties.VariableNames);
    kappaNames = string(kappaTbl.Properties.VariableNames);
    ptNames = string(ptTbl.Properties.VariableNames);

    idxRelaxT = 0;
    idxRelaxLogt = 0;
    idxRelaxM = 0;
    idxRelaxR = 0;
    for i = 1:numel(relaxNames)
        nm = lower(char(relaxNames(i)));
        if idxRelaxT == 0 && contains(nm, 't_k')
            idxRelaxT = i;
        end
        if idxRelaxLogt == 0 && (contains(nm, 'logt') || contains(nm, 'log_t') || contains(nm, 'log10_t'))
            idxRelaxLogt = i;
        end
        if idxRelaxM == 0 && (contains(nm, 'm') || contains(nm, 'magnet'))
            idxRelaxM = i;
        end
        if idxRelaxR == 0 && contains(nm, 'r_relax')
            idxRelaxR = i;
        end
    end

    idxKappaT = 0;
    idxKappa1 = 0;
    idxKappa2 = 0;
    idxKappa2Fallback = 0;
    for i = 1:numel(kappaNames)
        nm = lower(char(kappaNames(i)));
        if idxKappaT == 0 && contains(nm, 't_k')
            idxKappaT = i;
        end
        if idxKappa1 == 0 && contains(nm, 'kappa1')
            idxKappa1 = i;
        end
        if idxKappa2Fallback == 0 && contains(nm, 'kappa2')
            idxKappa2Fallback = i;
        end
        if idxKappa2 == 0 && contains(nm, 'kappa2') && ~contains(nm, 'abs')
            idxKappa2 = i;
        end
    end
    if idxKappa2 == 0
        idxKappa2 = idxKappa2Fallback;
    end

    idxPtT = 0;
    idxPtFeature1 = 0;
    idxPtFeature2 = 0;
    if hasPT
        for i = 1:numel(ptNames)
            nm = lower(char(ptNames(i)));
            if idxPtT == 0 && contains(nm, 't_k')
                idxPtT = i;
            end
            if idxPtFeature1 == 0 && contains(nm, 'tail_width_q90_q50')
                idxPtFeature1 = i;
            end
            if idxPtFeature2 == 0 && contains(nm, 'extreme_tail_q95_q75')
                idxPtFeature2 = i;
            end
        end
    end

    assert(idxRelaxT > 0, 'Could not detect relaxation temperature column.');
    assert(idxRelaxLogt > 0, 'Could not detect relaxation log-time column.');
    assert((idxRelaxM > 0) || (idxRelaxR > 0), 'Could not detect relaxation M(T,t) or R_relax(T,t) column.');
    assert(idxKappaT > 0 && idxKappa1 > 0 && idxKappa2 > 0, 'Could not detect kappa columns.');

    if idxPtFeature1 > 0
        pt_feature1_name = char(ptNames(idxPtFeature1));
    end
    if idxPtFeature2 > 0
        pt_feature2_name = char(ptNames(idxPtFeature2));
    end

    T_relax_all = double(relaxTbl{:, idxRelaxT});
    logt_all = double(relaxTbl{:, idxRelaxLogt});
    if idxRelaxM > 0
        signal_all = double(relaxTbl{:, idxRelaxM});
    else
        signal_all = double(relaxTbl{:, idxRelaxR});
        normalization_choice = 'Per-temperature min-max normalization on R_relax(T,t), then orientation fixed to decay from ~1 to ~0.';
    end

    okRelax = isfinite(T_relax_all) & isfinite(logt_all) & isfinite(signal_all);
    T_relax_all = T_relax_all(okRelax);
    logt_all = logt_all(okRelax);
    signal_all = signal_all(okRelax);
    assert(~isempty(T_relax_all), 'No valid relaxation rows after finite filter.');

    T_kappa_src = double(kappaTbl{:, idxKappaT});
    kappa1_src = double(kappaTbl{:, idxKappa1});
    kappa2_src = double(kappaTbl{:, idxKappa2});
    okKappa = isfinite(T_kappa_src) & isfinite(kappa1_src) & isfinite(kappa2_src);
    T_kappa_src = T_kappa_src(okKappa);
    kappa1_src = kappa1_src(okKappa);
    kappa2_src = kappa2_src(okKappa);
    assert(~isempty(T_kappa_src), 'No valid kappa rows after finite filter.');

    if hasPT && idxPtT > 0
        T_pt_src = double(ptTbl{:, idxPtT});
        if idxPtFeature1 > 0
            pt_feature1_src = double(ptTbl{:, idxPtFeature1});
        else
            pt_feature1_src = NaN(height(ptTbl), 1);
        end
        if idxPtFeature2 > 0
            pt_feature2_src = double(ptTbl{:, idxPtFeature2});
        else
            pt_feature2_src = NaN(height(ptTbl), 1);
        end
        okPT = isfinite(T_pt_src);
        T_pt_src = T_pt_src(okPT);
        pt_feature1_src = pt_feature1_src(okPT);
        pt_feature2_src = pt_feature2_src(okPT);
    else
        T_pt_src = NaN(0, 1);
        pt_feature1_src = NaN(0, 1);
        pt_feature2_src = NaN(0, 1);
    end

    T_relax_unique = unique(T_relax_all, 'sorted');
    N_T = numel(T_relax_unique);
    assert(N_T > 0, 'No temperatures found in relaxation data.');

    T_kappa_match = NaN(N_T, 1);
    T_pt_match = NaN(N_T, 1);
    N_points_total = zeros(N_T, 1);
    N_points_fit = zeros(N_T, 1);
    beta_vals = NaN(N_T, 1);
    tau_vals = NaN(N_T, 1);
    tau_exp_vals = NaN(N_T, 1);
    rmse_kww_vals = NaN(N_T, 1);
    rmse_exp_vals = NaN(N_T, 1);
    rmse_log_vals = NaN(N_T, 1);
    beta_drop_early_vals = NaN(N_T, 1);
    beta_drop_late_vals = NaN(N_T, 1);
    beta_robust_span_vals = NaN(N_T, 1);
    kappa1_match = NaN(N_T, 1);
    kappa2_match = NaN(N_T, 1);
    pt_feature1_match = NaN(N_T, 1);
    pt_feature2_match = NaN(N_T, 1);

    for iT = 1:N_T
        T_now = T_relax_unique(iT);

        dK = abs(T_kappa_src - T_now);
        [~, idxNearK] = min(dK);
        T_kappa_match(iT) = T_kappa_src(idxNearK);
        kappa1_match(iT) = kappa1_src(idxNearK);
        kappa2_match(iT) = kappa2_src(idxNearK);

        if ~isempty(T_pt_src)
            dP = abs(T_pt_src - T_now);
            [~, idxNearP] = min(dP);
            T_pt_match(iT) = T_pt_src(idxNearP);
            if ~isempty(pt_feature1_src)
                pt_feature1_match(iT) = pt_feature1_src(idxNearP);
            end
            if ~isempty(pt_feature2_src)
                pt_feature2_match(iT) = pt_feature2_src(idxNearP);
            end
        end

        maskT = (abs(T_relax_all - T_now) < 1e-12);
        logt_curve = logt_all(maskT);
        sig_curve = signal_all(maskT);
        [logt_curve, ord] = sort(logt_curve, 'ascend');
        sig_curve = sig_curve(ord);

        N_points_total(iT) = numel(logt_curve);
        if numel(logt_curve) < 5
            continue;
        end

        sMin = min(sig_curve);
        sMax = max(sig_curve);
        if ~(isfinite(sMin) && isfinite(sMax)) || (sMax - sMin) <= 0
            continue;
        end
        R_relax_norm = (sig_curve - sMin) ./ (sMax - sMin);
        if numel(R_relax_norm) >= 2 && R_relax_norm(end) > R_relax_norm(1)
            R_relax_norm = 1 - R_relax_norm;
        end

        t_s_curve = exp(logt_curve);
        fitMask = isfinite(t_s_curve) & isfinite(R_relax_norm) & (t_s_curve > 0) & (R_relax_norm > 0) & (R_relax_norm < 1);
        t_fit = t_s_curve(fitMask);
        R_fit = R_relax_norm(fitMask);
        if isempty(t_fit)
            continue;
        end

        [t_fit, ordFit] = sort(t_fit, 'ascend');
        R_fit = R_fit(ordFit);
        x_fit = log(t_fit);
        y_fit = log(-log(R_fit));
        validXY = isfinite(x_fit) & isfinite(y_fit);
        x_fit = x_fit(validXY);
        y_fit = y_fit(validXY);
        t_fit = t_fit(validXY);
        R_fit = R_fit(validXY);

        N_points_fit(iT) = numel(x_fit);
        if numel(x_fit) < 3
            continue;
        end

        xMean = mean(x_fit);
        yMean = mean(y_fit);
        dx = x_fit - xMean;
        dy = y_fit - yMean;
        denSlope = sum(dx .^ 2);
        if denSlope <= 0
            continue;
        end

        beta_now = sum(dx .* dy) / denSlope;
        intercept_now = yMean - beta_now * xMean;
        if ~(isfinite(beta_now) && isfinite(intercept_now)) || beta_now <= 0
            continue;
        end

        tau_now = exp(-intercept_now / beta_now);
        if ~(isfinite(tau_now) && tau_now > 0)
            continue;
        end

        pred_kww = exp(- (t_fit ./ tau_now) .^ beta_now);
        rmse_kww_now = sqrt(mean((pred_kww - R_fit) .^ 2));

        z_fit = -log(R_fit);
        denExp = sum(t_fit .^ 2);
        tau_exp_now = NaN;
        rmse_exp_now = NaN;
        if denExp > 0
            slope_exp = sum(t_fit .* z_fit) / denExp;
            if isfinite(slope_exp) && slope_exp > 0
                tau_exp_now = 1 / slope_exp;
                pred_exp = exp(-slope_exp .* t_fit);
                rmse_exp_now = sqrt(mean((pred_exp - R_fit) .^ 2));
            end
        end

        rmse_log_now = NaN;
        xLogMean = mean(x_fit);
        denLog = sum((x_fit - xLogMean) .^ 2);
        if denLog > 0
            yRMean = mean(R_fit);
            slope_log = sum((x_fit - xLogMean) .* (R_fit - yRMean)) / denLog;
            int_log = yRMean - slope_log * xLogMean;
            pred_log = int_log + slope_log .* x_fit;
            rmse_log_now = sqrt(mean((pred_log - R_fit) .^ 2));
        end

        beta_drop_early_now = NaN;
        beta_drop_late_now = NaN;
        beta_span_now = NaN;
        nFit = numel(x_fit);
        cutN = floor(0.2 * nFit);
        if cutN < 1
            cutN = 1;
        end

        if (nFit - cutN) >= 3
            idxEarly = (cutN + 1):nFit;
            x_early = x_fit(idxEarly);
            y_early = y_fit(idxEarly);
            xEarlyMean = mean(x_early);
            yEarlyMean = mean(y_early);
            denEarly = sum((x_early - xEarlyMean) .^ 2);
            if denEarly > 0
                beta_early = sum((x_early - xEarlyMean) .* (y_early - yEarlyMean)) / denEarly;
                if isfinite(beta_early)
                    beta_drop_early_now = beta_early;
                end
            end

            idxLate = 1:(nFit - cutN);
            x_late = x_fit(idxLate);
            y_late = y_fit(idxLate);
            xLateMean = mean(x_late);
            yLateMean = mean(y_late);
            denLate = sum((x_late - xLateMean) .^ 2);
            if denLate > 0
                beta_late = sum((x_late - xLateMean) .* (y_late - yLateMean)) / denLate;
                if isfinite(beta_late)
                    beta_drop_late_now = beta_late;
                end
            end
        end

        if isfinite(beta_drop_early_now) && isfinite(beta_drop_late_now)
            beta_span_now = abs(beta_drop_early_now - beta_drop_late_now);
        end

        beta_vals(iT) = beta_now;
        tau_vals(iT) = tau_now;
        tau_exp_vals(iT) = tau_exp_now;
        rmse_kww_vals(iT) = rmse_kww_now;
        rmse_exp_vals(iT) = rmse_exp_now;
        rmse_log_vals(iT) = rmse_log_now;
        beta_drop_early_vals(iT) = beta_drop_early_now;
        beta_drop_late_vals(iT) = beta_drop_late_now;
        beta_robust_span_vals(iT) = beta_span_now;
    end

    resultTbl = table( ...
        T_relax_unique, T_kappa_match, T_pt_match, N_points_total, N_points_fit, ...
        beta_vals, tau_vals, tau_exp_vals, rmse_kww_vals, rmse_exp_vals, rmse_log_vals, ...
        beta_drop_early_vals, beta_drop_late_vals, beta_robust_span_vals, ...
        kappa1_match, kappa2_match, pt_feature1_match, ...
        'VariableNames', {'T_relax_K','T_kappa_K','T_pt_K','N_points_total','N_points_fit','beta','tau_s','tau_exp_s','rmse_kww','rmse_exp','rmse_log','beta_drop_early','beta_drop_late','beta_robust_span','kappa1','kappa2','pt_feature1'});

    validKWW = isfinite(resultTbl.rmse_kww);
    validExp = isfinite(resultTbl.rmse_exp);
    validLog = isfinite(resultTbl.rmse_log);
    if any(validKWW)
        mean_rmse_kww = mean(resultTbl.rmse_kww(validKWW));
    end
    if any(validExp)
        mean_rmse_exp = mean(resultTbl.rmse_exp(validExp));
    end
    if any(validLog)
        mean_rmse_log = mean(resultTbl.rmse_log(validLog));
    end

    bestBaseline = NaN;
    if isfinite(mean_rmse_exp) && isfinite(mean_rmse_log)
        bestBaseline = min(mean_rmse_exp, mean_rmse_log);
    elseif isfinite(mean_rmse_exp)
        bestBaseline = mean_rmse_exp;
    elseif isfinite(mean_rmse_log)
        bestBaseline = mean_rmse_log;
    end

    nValidBeta = sum(isfinite(resultTbl.beta));
    if isfinite(mean_rmse_kww) && isfinite(bestBaseline) && nValidBeta >= 4
        if mean_rmse_kww <= 0.90 * bestBaseline
            KWW_GOOD_DESCRIPTION = 'YES';
        elseif mean_rmse_kww <= 1.05 * bestBaseline
            KWW_GOOD_DESCRIPTION = 'PARTIAL';
        else
            KWW_GOOD_DESCRIPTION = 'NO';
        end
    elseif nValidBeta >= 3
        KWW_GOOD_DESCRIPTION = 'PARTIAL';
    else
        KWW_GOOD_DESCRIPTION = 'NO';
    end

    maskK2 = isfinite(resultTbl.beta) & isfinite(resultTbl.kappa2);
    n_corr_kappa2 = sum(maskK2);
    if n_corr_kappa2 >= 3
        x = resultTbl.beta(maskK2);
        y = resultTbl.kappa2(maskK2);
        xMean = mean(x);
        yMean = mean(y);
        dx = x - xMean;
        dy = y - yMean;
        den = sqrt(sum(dx .^ 2) * sum(dy .^ 2));
        if den > 0
            pearson_beta_kappa2 = sum(dx .* dy) / den;
        end

        [xSort, xOrd] = sort(x, 'ascend');
        xRank = NaN(numel(x), 1);
        i = 1;
        while i <= numel(x)
            j = i;
            while j < numel(x) && abs(xSort(j + 1) - xSort(i)) <= 1e-12
                j = j + 1;
            end
            avgRank = 0.5 * (i + j);
            xRank(xOrd(i:j)) = avgRank;
            i = j + 1;
        end

        [ySort, yOrd] = sort(y, 'ascend');
        yRank = NaN(numel(y), 1);
        i = 1;
        while i <= numel(y)
            j = i;
            while j < numel(y) && abs(ySort(j + 1) - ySort(i)) <= 1e-12
                j = j + 1;
            end
            avgRank = 0.5 * (i + j);
            yRank(yOrd(i:j)) = avgRank;
            i = j + 1;
        end

        xrMean = mean(xRank);
        yrMean = mean(yRank);
        dxr = xRank - xrMean;
        dyr = yRank - yrMean;
        denr = sqrt(sum(dxr .^ 2) * sum(dyr .^ 2));
        if denr > 0
            spearman_beta_kappa2 = sum(dxr .* dyr) / denr;
        end
    end

    maskK1 = isfinite(resultTbl.beta) & isfinite(resultTbl.kappa1);
    n_corr_kappa1 = sum(maskK1);
    if n_corr_kappa1 >= 3
        x = resultTbl.beta(maskK1);
        y = resultTbl.kappa1(maskK1);
        xMean = mean(x);
        yMean = mean(y);
        dx = x - xMean;
        dy = y - yMean;
        den = sqrt(sum(dx .^ 2) * sum(dy .^ 2));
        if den > 0
            pearson_beta_kappa1 = sum(dx .* dy) / den;
        end

        [xSort, xOrd] = sort(x, 'ascend');
        xRank = NaN(numel(x), 1);
        i = 1;
        while i <= numel(x)
            j = i;
            while j < numel(x) && abs(xSort(j + 1) - xSort(i)) <= 1e-12
                j = j + 1;
            end
            avgRank = 0.5 * (i + j);
            xRank(xOrd(i:j)) = avgRank;
            i = j + 1;
        end

        [ySort, yOrd] = sort(y, 'ascend');
        yRank = NaN(numel(y), 1);
        i = 1;
        while i <= numel(y)
            j = i;
            while j < numel(y) && abs(ySort(j + 1) - ySort(i)) <= 1e-12
                j = j + 1;
            end
            avgRank = 0.5 * (i + j);
            yRank(yOrd(i:j)) = avgRank;
            i = j + 1;
        end

        xrMean = mean(xRank);
        yrMean = mean(yRank);
        dxr = xRank - xrMean;
        dyr = yRank - yrMean;
        denr = sqrt(sum(dxr .^ 2) * sum(dyr .^ 2));
        if denr > 0
            spearman_beta_kappa1 = sum(dxr .* dyr) / denr;
        end
    end

    if n_corr_kappa2 >= 5 && isfinite(pearson_beta_kappa2) && isfinite(spearman_beta_kappa2) ...
            && (abs(pearson_beta_kappa2) >= 0.60) && (abs(spearman_beta_kappa2) >= 0.60) ...
            && (sign(pearson_beta_kappa2) == sign(spearman_beta_kappa2))
        BETA_CORRELATED_WITH_KAPPA2 = 'YES';
    elseif n_corr_kappa2 >= 4 && (abs(pearson_beta_kappa2) >= 0.45 || abs(spearman_beta_kappa2) >= 0.45)
        BETA_CORRELATED_WITH_KAPPA2 = 'PARTIAL';
    else
        BETA_CORRELATED_WITH_KAPPA2 = 'NO';
    end

    if n_corr_kappa1 >= 5 && isfinite(pearson_beta_kappa1) && isfinite(spearman_beta_kappa1) ...
            && (abs(pearson_beta_kappa1) >= 0.60) && (abs(spearman_beta_kappa1) >= 0.60) ...
            && (sign(pearson_beta_kappa1) == sign(spearman_beta_kappa1))
        BETA_CORRELATED_WITH_KAPPA1 = 'YES';
    elseif n_corr_kappa1 >= 4 && (abs(pearson_beta_kappa1) >= 0.45 || abs(spearman_beta_kappa1) >= 0.45)
        BETA_CORRELATED_WITH_KAPPA1 = 'PARTIAL';
    else
        BETA_CORRELATED_WITH_KAPPA1 = 'NO';
    end

    ptStrongest = NaN;
    if idxPtFeature1 > 0
        maskPT1 = isfinite(resultTbl.beta) & isfinite(pt_feature1_match);
        n_corr_pt1 = sum(maskPT1);
        if n_corr_pt1 >= 3
            x = resultTbl.beta(maskPT1);
            y = pt_feature1_match(maskPT1);
            xMean = mean(x);
            yMean = mean(y);
            dx = x - xMean;
            dy = y - yMean;
            den = sqrt(sum(dx .^ 2) * sum(dy .^ 2));
            if den > 0
                pearson_beta_pt1 = sum(dx .* dy) / den;
            end

            [xSort, xOrd] = sort(x, 'ascend');
            xRank = NaN(numel(x), 1);
            i = 1;
            while i <= numel(x)
                j = i;
                while j < numel(x) && abs(xSort(j + 1) - xSort(i)) <= 1e-12
                    j = j + 1;
                end
                avgRank = 0.5 * (i + j);
                xRank(xOrd(i:j)) = avgRank;
                i = j + 1;
            end

            [ySort, yOrd] = sort(y, 'ascend');
            yRank = NaN(numel(y), 1);
            i = 1;
            while i <= numel(y)
                j = i;
                while j < numel(y) && abs(ySort(j + 1) - ySort(i)) <= 1e-12
                    j = j + 1;
                end
                avgRank = 0.5 * (i + j);
                yRank(yOrd(i:j)) = avgRank;
                i = j + 1;
            end

            xrMean = mean(xRank);
            yrMean = mean(yRank);
            dxr = xRank - xrMean;
            dyr = yRank - yrMean;
            denr = sqrt(sum(dxr .^ 2) * sum(dyr .^ 2));
            if denr > 0
                spearman_beta_pt1 = sum(dxr .* dyr) / denr;
            end
        end
    end

    if idxPtFeature2 > 0
        maskPT2 = isfinite(resultTbl.beta) & isfinite(pt_feature2_match);
        n_corr_pt2 = sum(maskPT2);
        if n_corr_pt2 >= 3
            x = resultTbl.beta(maskPT2);
            y = pt_feature2_match(maskPT2);
            xMean = mean(x);
            yMean = mean(y);
            dx = x - xMean;
            dy = y - yMean;
            den = sqrt(sum(dx .^ 2) * sum(dy .^ 2));
            if den > 0
                pearson_beta_pt2 = sum(dx .* dy) / den;
            end

            [xSort, xOrd] = sort(x, 'ascend');
            xRank = NaN(numel(x), 1);
            i = 1;
            while i <= numel(x)
                j = i;
                while j < numel(x) && abs(xSort(j + 1) - xSort(i)) <= 1e-12
                    j = j + 1;
                end
                avgRank = 0.5 * (i + j);
                xRank(xOrd(i:j)) = avgRank;
                i = j + 1;
            end

            [ySort, yOrd] = sort(y, 'ascend');
            yRank = NaN(numel(y), 1);
            i = 1;
            while i <= numel(y)
                j = i;
                while j < numel(y) && abs(ySort(j + 1) - ySort(i)) <= 1e-12
                    j = j + 1;
                end
                avgRank = 0.5 * (i + j);
                yRank(yOrd(i:j)) = avgRank;
                i = j + 1;
            end

            xrMean = mean(xRank);
            yrMean = mean(yRank);
            dxr = xRank - xrMean;
            dyr = yRank - yrMean;
            denr = sqrt(sum(dxr .^ 2) * sum(dyr .^ 2));
            if denr > 0
                spearman_beta_pt2 = sum(dxr .* dyr) / denr;
            end
        end
    end

    vals = [abs(pearson_beta_pt1), abs(spearman_beta_pt1), abs(pearson_beta_pt2), abs(spearman_beta_pt2)];
    vals = vals(isfinite(vals));
    if ~isempty(vals)
        ptStrongest = max(vals);
    end

    if isempty(T_pt_src)
        BETA_CONTROLLED_BY_PT = 'PARTIAL';
    elseif isfinite(ptStrongest) && ptStrongest >= 0.60
        BETA_CONTROLLED_BY_PT = 'YES';
    elseif isfinite(ptStrongest) && ptStrongest >= 0.40
        BETA_CONTROLLED_BY_PT = 'PARTIAL';
    else
        BETA_CONTROLLED_BY_PT = 'NO';
    end

    absK2 = max(abs([pearson_beta_kappa2, spearman_beta_kappa2]));
    absK1 = max(abs([pearson_beta_kappa1, spearman_beta_kappa1]));

    if strcmp(KWW_GOOD_DESCRIPTION, 'YES') && strcmp(BETA_CORRELATED_WITH_KAPPA2, 'YES') ...
            && (strcmp(BETA_CORRELATED_WITH_KAPPA1, 'NO') || (isfinite(absK2) && isfinite(absK1) && (absK2 >= absK1 + 0.10)))
        KAPPA2_CONTROLS_RELAXATION_SHAPE = 'YES';
    elseif ~strcmp(KWW_GOOD_DESCRIPTION, 'NO') && (strcmp(BETA_CORRELATED_WITH_KAPPA2, 'YES') || strcmp(BETA_CORRELATED_WITH_KAPPA2, 'PARTIAL'))
        KAPPA2_CONTROLS_RELAXATION_SHAPE = 'PARTIAL';
    else
        KAPPA2_CONTROLS_RELAXATION_SHAPE = 'NO';
    end

    matchedT = resultTbl.T_kappa_K(isfinite(resultTbl.T_kappa_K));
    matchedTList = '';
    for i = 1:numel(matchedT)
        matchedTList = [matchedTList, sprintf(' %.6g', matchedT(i))]; %#ok<AGROW>
    end
    if isempty(matchedTList)
        matchedTList = ' none';
    end

    mdLines = {};
    mdLines{end + 1} = '# kappa2 kww shape test';
    mdLines{end + 1} = '';
    mdLines{end + 1} = '## data sources';
    mdLines{end + 1} = ['- Relaxation dataset: ', inRelaxPath];
    mdLines{end + 1} = ['- Kappa table: ', inKappaPath];
    if hasPT
        mdLines{end + 1} = ['- PT observables: ', inPTPath];
    else
        mdLines{end + 1} = '- PT observables: not available';
    end
    mdLines{end + 1} = '';
    mdLines{end + 1} = '## alignment summary';
    mdLines{end + 1} = '- Alignment method: manual nearest matching on T_K (no innerjoin)';
    mdLines{end + 1} = ['- Matched temperature count: ', num2str(sum(isfinite(resultTbl.T_kappa_K)))];
    mdLines{end + 1} = ['- Matched T list (kappa side):', matchedTList];
    mdLines{end + 1} = ['- Total points across all T: ', num2str(sum(resultTbl.N_points_total))];
    mdLines{end + 1} = ['- Fit points across all T: ', num2str(sum(resultTbl.N_points_fit))];
    mdLines{end + 1} = '';
    mdLines{end + 1} = '## kww fit setup';
    mdLines{end + 1} = ['- Normalization: ', normalization_choice];
    mdLines{end + 1} = '- Transform: x = log(t), y = log(-log(R_relax_norm))';
    mdLines{end + 1} = '- Regression: manual slope/intercept, beta = slope, tau = exp(-intercept/beta)';
    mdLines{end + 1} = '- Invalid values excluded: R_relax_norm <= 0 or >= 1';
    mdLines{end + 1} = '';
    mdLines{end + 1} = '## beta(T) and tau(T)';
    mdLines{end + 1} = '|T_relax_K|T_kappa_K|N_fit|beta|tau_s|RMSE_KWW|RMSE_EXP|RMSE_LOG|';
    mdLines{end + 1} = '|---:|---:|---:|---:|---:|---:|---:|---:|';
    for i = 1:height(resultTbl)
        mdLines{end + 1} = sprintf('|%.6g|%.6g|%d|%.6g|%.6g|%.6g|%.6g|%.6g|', ...
            resultTbl.T_relax_K(i), resultTbl.T_kappa_K(i), resultTbl.N_points_fit(i), ...
            resultTbl.beta(i), resultTbl.tau_s(i), resultTbl.rmse_kww(i), resultTbl.rmse_exp(i), resultTbl.rmse_log(i));
    end
    mdLines{end + 1} = '';
    mdLines{end + 1} = '## fit quality';
    mdLines{end + 1} = ['- Mean RMSE KWW: ', num2str(mean_rmse_kww, '%.6g')];
    mdLines{end + 1} = ['- Mean RMSE exponential (beta=1): ', num2str(mean_rmse_exp, '%.6g')];
    mdLines{end + 1} = ['- Mean RMSE logarithmic: ', num2str(mean_rmse_log, '%.6g')];
    mdLines{end + 1} = '- RMSE vs T available in output CSV columns rmse_kww/rmse_exp/rmse_log.';
    mdLines{end + 1} = '';
    mdLines{end + 1} = '## correlations';
    mdLines{end + 1} = sprintf('- beta vs kappa2: Pearson=%.6g Spearman=%.6g n=%d', pearson_beta_kappa2, spearman_beta_kappa2, n_corr_kappa2);
    mdLines{end + 1} = sprintf('- beta vs kappa1: Pearson=%.6g Spearman=%.6g n=%d', pearson_beta_kappa1, spearman_beta_kappa1, n_corr_kappa1);
    if hasPT
        mdLines{end + 1} = sprintf('- beta vs %s: Pearson=%.6g Spearman=%.6g n=%d', pt_feature1_name, pearson_beta_pt1, spearman_beta_pt1, n_corr_pt1);
        mdLines{end + 1} = sprintf('- beta vs %s: Pearson=%.6g Spearman=%.6g n=%d', pt_feature2_name, pearson_beta_pt2, spearman_beta_pt2, n_corr_pt2);
    else
        mdLines{end + 1} = '- PT feature correlations not computed.';
    end
    mdLines{end + 1} = '';
    mdLines{end + 1} = '## robustness checks';
    mdLines{end + 1} = sprintf('- Mean |beta(remove early) - beta(remove late)|: %.6g', mean(resultTbl.beta_robust_span(isfinite(resultTbl.beta_robust_span))));
    mdLines{end + 1} = sprintf('- Variance beta(T): %.6g', var(resultTbl.beta(isfinite(resultTbl.beta)), 1));
    mdLines{end + 1} = '';
    mdLines{end + 1} = '## final verdict block';
    mdLines{end + 1} = ['- KWW_GOOD_DESCRIPTION: ', KWW_GOOD_DESCRIPTION];
    mdLines{end + 1} = ['- BETA_CORRELATED_WITH_KAPPA2: ', BETA_CORRELATED_WITH_KAPPA2];
    mdLines{end + 1} = ['- BETA_CORRELATED_WITH_KAPPA1: ', BETA_CORRELATED_WITH_KAPPA1];
    mdLines{end + 1} = ['- BETA_CONTROLLED_BY_PT: ', BETA_CONTROLLED_BY_PT];
    mdLines{end + 1} = ['- KAPPA2_CONTROLS_RELAXATION_SHAPE: ', KAPPA2_CONTROLS_RELAXATION_SHAPE];
    mdLines{end + 1} = '';
    mdLines{end + 1} = '## short physical interpretation';
    mdLines{end + 1} = 'If beta tracks kappa2 more strongly than kappa1 and KWW fits are good, this supports a shape-control role for kappa2 in relaxation broadening.';

    EXECUTION_STATUS = 'SUCCESS';
    MAIN_RESULT_SUMMARY = sprintf('nT=%d, mean_rmse_kww=%.4g, corr_beta_kappa2=[%.3f, %.3f], kappa2_controls=%s', ...
        N_T, mean_rmse_kww, pearson_beta_kappa2, spearman_beta_kappa2, KAPPA2_CONTROLS_RELAXATION_SHAPE);

catch ME
    ERROR_MESSAGE = strrep(ME.message, newline, ' ');
    mdLines = {};
    mdLines{end + 1} = '# kappa2 kww shape test';
    mdLines{end + 1} = '';
    mdLines{end + 1} = '## execution status';
    mdLines{end + 1} = '- EXECUTION_STATUS: FAIL';
    mdLines{end + 1} = ['- ERROR_MESSAGE: ', ERROR_MESSAGE];
    mdLines{end + 1} = '';
    mdLines{end + 1} = '## final verdict block';
    mdLines{end + 1} = ['- KWW_GOOD_DESCRIPTION: ', KWW_GOOD_DESCRIPTION];
    mdLines{end + 1} = ['- BETA_CORRELATED_WITH_KAPPA2: ', BETA_CORRELATED_WITH_KAPPA2];
    mdLines{end + 1} = ['- BETA_CORRELATED_WITH_KAPPA1: ', BETA_CORRELATED_WITH_KAPPA1];
    mdLines{end + 1} = ['- BETA_CONTROLLED_BY_PT: ', BETA_CONTROLLED_BY_PT];
    mdLines{end + 1} = ['- KAPPA2_CONTROLS_RELAXATION_SHAPE: ', KAPPA2_CONTROLS_RELAXATION_SHAPE];
end

if ~istable(resultTbl)
    resultTbl = table('Size', [0, 17], ...
        'VariableTypes', {'double','double','double','double','double','double','double','double','double','double','double','double','double','double','double','double','double'}, ...
        'VariableNames', {'T_relax_K','T_kappa_K','T_pt_K','N_points_total','N_points_fit','beta','tau_s','tau_exp_s','rmse_kww','rmse_exp','rmse_log','beta_drop_early','beta_drop_late','beta_robust_span','kappa1','kappa2','pt_feature1'});
end
writetable(resultTbl, outCsvPath);

statusTbl = table( ...
    {EXECUTION_STATUS}, {INPUT_FOUND}, {ERROR_MESSAGE}, N_T, {MAIN_RESULT_SUMMARY}, ...
    {KWW_GOOD_DESCRIPTION}, {BETA_CORRELATED_WITH_KAPPA2}, {BETA_CORRELATED_WITH_KAPPA1}, {BETA_CONTROLLED_BY_PT}, {KAPPA2_CONTROLS_RELAXATION_SHAPE}, ...
    pearson_beta_kappa2, spearman_beta_kappa2, pearson_beta_kappa1, spearman_beta_kappa1, ...
    pearson_beta_pt1, spearman_beta_pt1, pearson_beta_pt2, spearman_beta_pt2, ...
    mean_rmse_kww, mean_rmse_exp, mean_rmse_log, ...
    'VariableNames', {'EXECUTION_STATUS','INPUT_FOUND','ERROR_MESSAGE','N_T','MAIN_RESULT_SUMMARY', ...
    'KWW_GOOD_DESCRIPTION','BETA_CORRELATED_WITH_KAPPA2','BETA_CORRELATED_WITH_KAPPA1','BETA_CONTROLLED_BY_PT','KAPPA2_CONTROLS_RELAXATION_SHAPE', ...
    'PEARSON_BETA_KAPPA2','SPEARMAN_BETA_KAPPA2','PEARSON_BETA_KAPPA1','SPEARMAN_BETA_KAPPA1', ...
    'PEARSON_BETA_PT1','SPEARMAN_BETA_PT1','PEARSON_BETA_PT2','SPEARMAN_BETA_PT2', ...
    'MEAN_RMSE_KWW','MEAN_RMSE_EXP','MEAN_RMSE_LOG'});
writetable(statusTbl, outStatusPath);

fid = fopen(outMdPath, 'w');
if fid > 0
    for i = 1:numel(mdLines)
        fprintf(fid, '%s\n', mdLines{i});
    end
    fclose(fid);
else
    ERROR_MESSAGE = ['Could not write report: ', outMdPath];
    statusTbl.ERROR_MESSAGE = {ERROR_MESSAGE};
    writetable(statusTbl, outStatusPath);
end

