% run_kappa2_opening_test
% Strict physics identification test:
% Is kappa2 a predictable geometric extension of PT + kappa1,
% or an independent reorganization mode?
%
% Intended execution:
% eval(fileread('C:/Dev/matlab-functions/Switching/analysis/run_kappa2_opening_test.m'))
%
% Required outputs:
% - C:\Dev\matlab-functions\tables\kappa2_opening_models.csv
% - C:\Dev\matlab-functions\tables\kappa2_opening_decomposition.csv
% - C:\Dev\matlab-functions\tables\kappa2_opening_residuals.csv
% - C:\Dev\matlab-functions\reports\kappa2_opening_test.md
% - C:\Dev\matlab-functions\tables\kappa2_opening_status.csv

clearvars;
clc;

repoRoot = 'C:\Dev\matlab-functions';
tablesDir = fullfile(repoRoot, 'tables');
reportsDir = fullfile(repoRoot, 'reports');
if exist(tablesDir, 'dir') ~= 7, mkdir(tablesDir); end
if exist(reportsDir, 'dir') ~= 7, mkdir(reportsDir); end

modelsOutPath = fullfile(tablesDir, 'kappa2_opening_models.csv');
decompOutPath = fullfile(tablesDir, 'kappa2_opening_decomposition.csv');
residOutPath = fullfile(tablesDir, 'kappa2_opening_residuals.csv');
reportOutPath = fullfile(reportsDir, 'kappa2_opening_test.md');
statusOutPath = fullfile(tablesDir, 'kappa2_opening_status.csv');

runTimestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');

try
    % -----------------------------
    % Config
    % -----------------------------
    tolT = 1e-9;
    transitionMinK = 22;
    transitionMaxK = 24;
    tinyStdThreshold = 0.02;
    strongCorrThreshold = 0.45;

    % -----------------------------
    % Canonical source chain
    % -----------------------------
    decompRunDir = fullfile(switchingCanonicalRunRoot(repoRoot), ...
        '_extract_run_2026_03_24_220314_residual_decomposition', ...
        'run_2026_03_24_220314_residual_decomposition');
    decompTablesDir = fullfile(decompRunDir, 'tables');

    srcPath = fullfile(decompTablesDir, 'residual_decomposition_sources.csv');
    kappa1Path = fullfile(decompTablesDir, 'kappa_vs_T.csv');
    kappa2Path = fullfile(repoRoot, 'tables', 'closure_metrics_per_temperature.csv');

    assert(exist(srcPath, 'file') == 2, 'Missing canonical source table: %s', srcPath);
    assert(exist(kappa1Path, 'file') == 2, 'Missing canonical kappa1 table: %s', kappa1Path);
    assert(exist(kappa2Path, 'file') == 2, 'Missing canonical kappa2 table: %s', kappa2Path);

    ptPath = '';
    srcTbl = readtable(srcPath, 'VariableNamingRule', 'preserve');
    srcVars = string(srcTbl.Properties.VariableNames);
    srcVarsLower = lower(srcVars);

    srcRoleCol = '';
    srcFileCol = '';
    for i = 1:numel(srcVars)
        if strlength(srcRoleCol) == 0 && contains(srcVarsLower(i), 'source_role')
            srcRoleCol = srcVars(i);
        end
        if strlength(srcFileCol) == 0 && contains(srcVarsLower(i), 'source_file')
            srcFileCol = srcVars(i);
        end
    end

    if strlength(srcRoleCol) > 0 && strlength(srcFileCol) > 0
        srcRoles = lower(string(srcTbl.(char(srcRoleCol))));
        srcFiles = string(srcTbl.(char(srcFileCol)));
        idxPt = find(contains(srcRoles, 'pt_matrix'), 1, 'first');
        if ~isempty(idxPt)
            ptPath = char(srcFiles(idxPt));
        end
    end

    if strlength(string(ptPath)) == 0
        ptPath = fullfile(switchingCanonicalRunRoot(repoRoot), ...
            'run_2026_03_24_212033_switching_barrier_distribution_from_map', 'tables', 'PT_matrix.csv');
    end
    assert(exist(ptPath, 'file') == 2, 'Missing canonical PT matrix table: %s', ptPath);

    ptTbl = readtable(ptPath, 'VariableNamingRule', 'preserve');
    k1Tbl = readtable(kappa1Path, 'VariableNamingRule', 'preserve');
    k2Tbl = readtable(kappa2Path, 'VariableNamingRule', 'preserve');

    % -----------------------------
    % Column detection (contains only)
    % -----------------------------
    ptVars = string(ptTbl.Properties.VariableNames);
    ptVarsLower = lower(ptVars);

    ptTCol = '';
    for i = 1:numel(ptVars)
        if strlength(ptTCol) == 0 && contains(ptVarsLower(i), 't_k')
            ptTCol = ptVars(i);
        end
    end
    assert(strlength(ptTCol) > 0, 'PT table missing T_K-like column: %s', ptPath);

    ithIdx = [];
    for i = 1:numel(ptVars)
        if contains(ptVarsLower(i), 'ith_')
            ithIdx(end + 1) = i; %#ok<AGROW>
        end
    end
    assert(~isempty(ithIdx), 'No Ith_* PT columns found in: %s', ptPath);

    Ivals = NaN(1, numel(ithIdx));
    for j = 1:numel(ithIdx)
        vname = char(ptVars(ithIdx(j)));
        s = strrep(vname, 'Ith_', '');
        s = strrep(s, '_mA', '');
        s = strrep(s, '_', '.');
        Ivals(j) = str2double(s);
    end
    [Ivals, ordI] = sort(Ivals, 'ascend');
    ithIdx = ithIdx(ordI);

    k1Vars = string(k1Tbl.Properties.VariableNames);
    k1VarsLower = lower(k1Vars);
    k1TCol = '';
    k1Col = '';
    for i = 1:numel(k1Vars)
        if strlength(k1TCol) == 0 && (contains(k1VarsLower(i), 't_k') || contains(['_' char(k1VarsLower(i)) '_'], '_t_'))
            k1TCol = k1Vars(i);
        end
        if strlength(k1Col) == 0 && contains(k1VarsLower(i), 'kappa')
            k1Col = k1Vars(i);
        end
    end
    assert(strlength(k1TCol) > 0 && strlength(k1Col) > 0, ...
        'kappa1 table missing T/kappa-like columns: %s', kappa1Path);

    k2Vars = string(k2Tbl.Properties.VariableNames);
    k2VarsLower = lower(k2Vars);
    k2TCol = '';
    k2Col = '';
    for i = 1:numel(k2Vars)
        if strlength(k2TCol) == 0 && (contains(k2VarsLower(i), 't_k') || contains(['_' char(k2VarsLower(i)) '_'], '_t_'))
            k2TCol = k2Vars(i);
        end
        if strlength(k2Col) == 0 && contains(k2VarsLower(i), 'kappa2_m3')
            k2Col = k2Vars(i);
        end
    end
    if strlength(k2Col) == 0
        for i = 1:numel(k2Vars)
            if strlength(k2Col) == 0 && contains(k2VarsLower(i), 'kappa2')
                k2Col = k2Vars(i);
            end
        end
    end
    assert(strlength(k2TCol) > 0 && strlength(k2Col) > 0, ...
        'kappa2 table missing T/kappa2-like columns: %s', kappa2Path);

    Tpt = double(ptTbl.(char(ptTCol)));
    PTraw = double(ptTbl{:, ithIdx});
    Tk1 = double(k1Tbl.(char(k1TCol)));
    kappa1 = double(k1Tbl.(char(k1Col)));
    Tk2 = double(k2Tbl.(char(k2TCol)));
    kappa2 = double(k2Tbl.(char(k2Col)));

    keepPt = isfinite(Tpt);
    Tpt = Tpt(keepPt);
    PTraw = PTraw(keepPt, :);

    keepK1 = isfinite(Tk1) & isfinite(kappa1);
    Tk1 = Tk1(keepK1);
    kappa1 = kappa1(keepK1);

    keepK2 = isfinite(Tk2) & isfinite(kappa2);
    Tk2 = Tk2(keepK2);
    kappa2 = kappa2(keepK2);

    [TptU, iaPt] = unique(Tpt, 'stable');
    Tpt = TptU;
    PTraw = PTraw(iaPt, :);
    [Tk1U, iaK1] = unique(Tk1, 'stable');
    Tk1 = Tk1U;
    kappa1 = kappa1(iaK1);
    [Tk2U, iaK2] = unique(Tk2, 'stable');
    Tk2 = Tk2U;
    kappa2 = kappa2(iaK2);

    % -----------------------------
    % PT geometry features per T
    % -----------------------------
    nPt = numel(Tpt);
    pt_width9010 = NaN(nPt, 1);
    pt_asym = NaN(nPt, 1);
    pt_stdI = NaN(nPt, 1);
    pt_width7525 = NaN(nPt, 1);

    for i = 1:nPt
        prow = PTraw(i, :);
        m = isfinite(Ivals(:)') & isfinite(prow);
        Irow = Ivals(m);
        p = double(prow(m));

        if numel(Irow) < 3
            continue;
        end
        p = max(p, 0);
        if ~any(p > 0)
            continue;
        end

        area = trapz(Irow, p);
        if ~isfinite(area) || area <= 0
            continue;
        end
        p = p ./ area;

        cdf = cumtrapz(Irow, p);
        if ~isfinite(cdf(end)) || cdf(end) <= 0
            continue;
        end
        cdf = cdf ./ cdf(end);

        [cdfU, ia] = unique(cdf, 'stable');
        IU = Irow(ia);
        if numel(cdfU) < 2
            continue;
        end

        q10 = interp1(cdfU, IU, 0.10, 'linear', 'extrap');
        q25 = interp1(cdfU, IU, 0.25, 'linear', 'extrap');
        q50 = interp1(cdfU, IU, 0.50, 'linear', 'extrap');
        q75 = interp1(cdfU, IU, 0.75, 'linear', 'extrap');
        q90 = interp1(cdfU, IU, 0.90, 'linear', 'extrap');

        muI = trapz(Irow, Irow .* p);
        varI = trapz(Irow, ((Irow - muI) .^ 2) .* p);
        sigI = sqrt(max(varI, 0));

        pt_width9010(i) = q90 - q10;
        pt_asym(i) = (q90 - q50) - (q50 - q10);
        pt_stdI(i) = sigI;
        pt_width7525(i) = q75 - q25;
    end

    % -----------------------------
    % Manual T alignment (no join)
    % -----------------------------
    T_al = [];
    k1_al = [];
    k2_al = [];
    f1_al = [];
    f2_al = [];
    f3_al = [];
    f4_al = [];

    for i = 1:numel(Tpt)
        t = Tpt(i);
        ik1 = find(abs(Tk1 - t) <= tolT, 1, 'first');
        ik2 = find(abs(Tk2 - t) <= tolT, 1, 'first');
        if isempty(ik1) || isempty(ik2)
            continue;
        end

        vals = [kappa1(ik1), kappa2(ik2), pt_width9010(i), pt_asym(i), pt_stdI(i), pt_width7525(i)];
        if any(~isfinite(vals))
            continue;
        end

        T_al(end + 1, 1) = t; %#ok<AGROW>
        k1_al(end + 1, 1) = kappa1(ik1); %#ok<AGROW>
        k2_al(end + 1, 1) = kappa2(ik2); %#ok<AGROW>
        f1_al(end + 1, 1) = pt_width9010(i); %#ok<AGROW>
        f2_al(end + 1, 1) = pt_asym(i); %#ok<AGROW>
        f3_al(end + 1, 1) = pt_stdI(i); %#ok<AGROW>
        f4_al(end + 1, 1) = pt_width7525(i); %#ok<AGROW>
    end

    [T_al, ord] = sort(T_al, 'ascend');
    k1_al = k1_al(ord);
    k2_al = k2_al(ord);
    f1_al = f1_al(ord);
    f2_al = f2_al(ord);
    f3_al = f3_al(ord);
    f4_al = f4_al(ord);

    n = numel(T_al);
    assert(n >= 6, 'Need at least 6 aligned rows. Got n=%d', n);

    y = k2_al;

    % z-score predictors
    Xpt = [f1_al, f2_al, f3_al, f4_al];
    for j = 1:size(Xpt, 2)
        mu = mean(Xpt(:, j), 'omitnan');
        sg = std(Xpt(:, j), 'omitnan');
        if ~isfinite(sg) || sg < 1e-12
            sg = 1;
        end
        Xpt(:, j) = (Xpt(:, j) - mu) ./ sg;
    end

    muK1 = mean(k1_al, 'omitnan');
    sgK1 = std(k1_al, 'omitnan');
    if ~isfinite(sgK1) || sgK1 < 1e-12
        sgK1 = 1;
    end
    Xk1 = (k1_al - muK1) ./ sgK1;

    % -----------------------------
    % STEP 1: Base model family
    % -----------------------------
    modelId = [ ...
        "kappa2 ~ mean"; ...
        "kappa2 ~ PT"; ...
        "kappa2 ~ kappa1"; ...
        "kappa2 ~ PT + kappa1"; ...
        "kappa2 ~ PT + kappa1 + small_nonlinear"];

    Xcells = cell(numel(modelId), 1);
    Xcells{1} = zeros(n, 0);
    Xcells{2} = Xpt;
    Xcells{3} = Xk1;
    Xcells{4} = [Xpt, Xk1];
    Xcells{5} = [Xpt, Xk1, Xk1.^2, Xk1 .* Xpt(:, 2)];

    nModels = numel(modelId);
    yhatAll = NaN(n, nModels);
    rmse = NaN(nModels, 1);
    SSE = NaN(nModels, 1);
    R2 = NaN(nModels, 1);
    corrP = NaN(nModels, 1);
    corrS = NaN(nModels, 1);

    yMeanGlobal = mean(y, 'omitnan');
    SST = sum((y - yMeanGlobal) .^ 2, 'omitnan');

    for m = 1:nModels
        X = Xcells{m};
        yhat = NaN(n, 1);
        for i = 1:n
            idxTrain = true(n, 1);
            idxTrain(i) = false;
            ytr = y(idxTrain);

            if isempty(X)
                yhat(i) = mean(ytr, 'omitnan');
            else
                Xtr = [ones(n - 1, 1), X(idxTrain, :)];
                Xte = [1, X(i, :)];
                if any(~isfinite(Xtr(:))) || any(~isfinite(Xte(:))) || any(~isfinite(ytr(:)))
                    continue;
                end
                b = pinv(Xtr) * ytr;
                yhat(i) = Xte * b;
            end
        end

        yhatAll(:, m) = yhat;
        e = y - yhat;
        SSE(m) = sum(e .^ 2, 'omitnan');
        rmse(m) = sqrt(mean(e .^ 2, 'omitnan'));

        if isfinite(SST) && SST > 0
            R2(m) = 1 - SSE(m) / SST;
        end

        mk = isfinite(y) & isfinite(yhat);
        if nnz(mk) >= 3 && std(y(mk), 'omitnan') > 0 && std(yhat(mk), 'omitnan') > 0
            c = corrcoef(y(mk), yhat(mk));
            corrP(m) = c(1, 2);
            corrS(m) = corr(y(mk), yhat(mk), 'Type', 'Spearman', 'Rows', 'complete');
        end
    end

    idxMean = find(modelId == "kappa2 ~ mean", 1, 'first');
    idxPT = find(modelId == "kappa2 ~ PT", 1, 'first');
    idxK1 = find(modelId == "kappa2 ~ kappa1", 1, 'first');
    idxPTK1 = find(modelId == "kappa2 ~ PT + kappa1", 1, 'first');
    idxNL = find(modelId == "kappa2 ~ PT + kappa1 + small_nonlinear", 1, 'first');

    % -----------------------------
    % STEP 0: Data sanity
    % -----------------------------
    kappa2Std = std(y, 'omitnan');
    fracVarExplainedMean = R2(idxMean);
    trivialVarianceFlag = "NO";
    if isfinite(kappa2Std) && kappa2Std < tinyStdThreshold
        trivialVarianceFlag = "YES";
    end

    % -----------------------------
    % STEP 2: Explained variance decomposition
    % -----------------------------
    R2_PT = R2(idxPT);
    R2_k1 = R2(idxK1);
    R2_PTk1 = R2(idxPTK1);
    deltaR2 = R2_PTk1 - max(R2_PT, R2_k1);

    decompTbl = table( ...
        n, kappa2Std, fracVarExplainedMean, ...
        R2_PT, R2_k1, R2_PTk1, deltaR2, ...
        'VariableNames', {'n_aligned', 'kappa2_std', 'R2_mean_model', ...
        'R2_PT', 'R2_kappa1', 'R2_PT_plus_kappa1', 'Delta_R2_PTk1_vs_best_single'});
    writetable(decompTbl, decompOutPath);

    % -----------------------------
    % Choose best model for residual analysis
    % -----------------------------
    if rmse(idxNL) < rmse(idxPTK1)
        idxBest = idxNL;
    else
        idxBest = idxPTK1;
    end

    yhatBest = yhatAll(:, idxBest);
    r = y - yhatBest;

    % -----------------------------
    % STEP 3: Residual structure tests
    % -----------------------------
    corr_r_T = NaN;
    corr_r_T_s = NaN;
    corr_r_k1 = NaN;
    corr_r_k1_s = NaN;
    corr_r_f1 = NaN;
    corr_r_f2 = NaN;
    corr_r_f3 = NaN;
    corr_r_f4 = NaN;

    m = isfinite(r) & isfinite(T_al);
    if nnz(m) >= 3 && std(r(m), 'omitnan') > 0 && std(T_al(m), 'omitnan') > 0
        c = corrcoef(r(m), T_al(m));
        corr_r_T = c(1, 2);
        corr_r_T_s = corr(r(m), T_al(m), 'Type', 'Spearman', 'Rows', 'complete');
    end

    m = isfinite(r) & isfinite(k1_al);
    if nnz(m) >= 3 && std(r(m), 'omitnan') > 0 && std(k1_al(m), 'omitnan') > 0
        c = corrcoef(r(m), k1_al(m));
        corr_r_k1 = c(1, 2);
        corr_r_k1_s = corr(r(m), k1_al(m), 'Type', 'Spearman', 'Rows', 'complete');
    end

    m = isfinite(r) & isfinite(f1_al);
    if nnz(m) >= 3 && std(r(m), 'omitnan') > 0 && std(f1_al(m), 'omitnan') > 0
        c = corrcoef(r(m), f1_al(m));
        corr_r_f1 = c(1, 2);
    end
    m = isfinite(r) & isfinite(f2_al);
    if nnz(m) >= 3 && std(r(m), 'omitnan') > 0 && std(f2_al(m), 'omitnan') > 0
        c = corrcoef(r(m), f2_al(m));
        corr_r_f2 = c(1, 2);
    end
    m = isfinite(r) & isfinite(f3_al);
    if nnz(m) >= 3 && std(r(m), 'omitnan') > 0 && std(f3_al(m), 'omitnan') > 0
        c = corrcoef(r(m), f3_al(m));
        corr_r_f3 = c(1, 2);
    end
    m = isfinite(r) & isfinite(f4_al);
    if nnz(m) >= 3 && std(r(m), 'omitnan') > 0 && std(f4_al(m), 'omitnan') > 0
        c = corrcoef(r(m), f4_al(m));
        corr_r_f4 = c(1, 2);
    end

    varY = var(y, 'omitnan');
    varR = var(r, 'omitnan');
    resVarFraction = varR / max(varY, eps);

    % -----------------------------
    % STEP 4: Transition localization
    % -----------------------------
    isTransition = (T_al >= transitionMinK) & (T_al <= transitionMaxK);
    mIn = isTransition & isfinite(r);
    mOut = (~isTransition) & isfinite(r);

    rmsIn = NaN;
    rmsOut = NaN;
    transitionRatio = NaN;
    if nnz(mIn) >= 1
        rmsIn = sqrt(mean(r(mIn) .^ 2, 'omitnan'));
    end
    if nnz(mOut) >= 1
        rmsOut = sqrt(mean(r(mOut) .^ 2, 'omitnan'));
    end
    if isfinite(rmsIn) && isfinite(rmsOut) && rmsOut > 0
        transitionRatio = rmsIn / rmsOut;
    end

    % -----------------------------
    % STEP 5: Low-dimensionality test (residual trajectory SVD)
    % -----------------------------
    svd_energy1 = NaN;
    svd_energy12 = NaN;
    lag1_corr = NaN;

    mFinR = isfinite(r);
    rFin = r(mFinR);
    nFin = numel(rFin);

    if nFin >= 3 && std(rFin, 'omitnan') > 0
        lag1_corr = corr(rFin(1:end-1), rFin(2:end), 'Type', 'Pearson', 'Rows', 'complete');
    end

    if nFin >= 6
        w = max(3, floor(nFin / 2));
        nRows = nFin - w + 1;
        H = NaN(nRows, w);
        for i = 1:nRows
            H(i, :) = rFin(i:i+w-1);
        end
        [~, Ssvd, ~] = svd(H, 'econ');
        s = diag(Ssvd);
        e = s .^ 2;
        eTot = sum(e);
        if eTot > 0
            svd_energy1 = e(1) / eTot;
            svd_energy12 = sum(e(1:min(2, numel(e)))) / eTot;
        end
    end

    residualModeType = "UNDETERMINED";
    if isfinite(svd_energy1) && isfinite(lag1_corr)
        if svd_energy1 >= 0.75 || abs(lag1_corr) >= 0.50
            residualModeType = "STRUCTURED_LOW_DIMENSIONAL";
        else
            residualModeType = "NOISE_LIKE";
        end
    elseif isfinite(svd_energy1)
        if svd_energy1 >= 0.75
            residualModeType = "STRUCTURED_LOW_DIMENSIONAL";
        else
            residualModeType = "NOISE_LIKE";
        end
    end

    % -----------------------------
    % Models table (expanded)
    % -----------------------------
    relRmseImproveVsMeanPct = 100 * (rmse(idxMean) - rmse) ./ max(rmse(idxMean), eps);

    modelsTbl = table(modelId, repmat(n, nModels, 1), ...
        rmse, R2, corrP, corrS, relRmseImproveVsMeanPct, ...
        'VariableNames', {'model_id', 'n', 'loocv_rmse', 'R2_loocv', ...
        'pearson_y_yhat', 'spearman_y_yhat', 'rmse_improvement_pct_vs_mean'});
    writetable(modelsTbl, modelsOutPath);

    % -----------------------------
    % Residual table (new)
    % -----------------------------
    residTbl = table(T_al, k1_al, y, ...
        yhatAll(:, idxPT), yhatAll(:, idxK1), yhatAll(:, idxPTK1), yhatAll(:, idxNL), ...
        yhatBest, r, isTransition, ...
        f1_al, f2_al, f3_al, f4_al, ...
        'VariableNames', {'T_K', 'kappa1', 'kappa2', ...
        'yhat_PT', 'yhat_kappa1', 'yhat_PT_plus_kappa1', 'yhat_small_nonlinear', ...
        'yhat_best', 'residual_best', 'is_transition_22_24K', ...
        'pt_width_q90_q10', 'pt_asymmetry', 'pt_std_I', 'pt_width_q75_q25'});
    writetable(residTbl, residOutPath);

    % -----------------------------
    % STEP 6: Strict decision logic
    % -----------------------------
    rmseImprovePTk1Pct = 100 * (rmse(idxMean) - rmse(idxPTK1)) / max(rmse(idxMean), eps);

    KAPPA2_HAS_GEOMETRIC_COMPONENT = "NO";
    if (isfinite(R2_PT) && R2_PT >= 0.2) || (isfinite(rmseImprovePTk1Pct) && rmseImprovePTk1Pct >= 10)
        KAPPA2_HAS_GEOMETRIC_COMPONENT = "YES";
    end

    KAPPA2_IS_CLOSED = "NO";
    if isfinite(R2_PTk1) && isfinite(resVarFraction) && R2_PTk1 >= 0.7 && resVarFraction <= 0.30
        KAPPA2_IS_CLOSED = "YES";
    end

    strongT = isfinite(corr_r_T) && abs(corr_r_T) >= strongCorrThreshold;
    strongTransition = isfinite(transitionRatio) && transitionRatio >= 1.5;

    KAPPA2_HAS_REORGANIZATION_RESIDUAL = "NO";
    if (isfinite(resVarFraction) && resVarFraction >= 0.40) || strongT || strongTransition
        KAPPA2_HAS_REORGANIZATION_RESIDUAL = "YES";
    end

    KAPPA2_PARTIALLY_OPENED = "NO";
    if KAPPA2_HAS_GEOMETRIC_COMPONENT == "YES" && KAPPA2_HAS_REORGANIZATION_RESIDUAL == "YES"
        KAPPA2_PARTIALLY_OPENED = "YES";
    end

    mainSummary = sprintf(['R2_PT=%.4f, R2_kappa1=%.4f, R2_PT+kappa1=%.4f, DeltaR2=%.4f, ' ...
        'resVarFrac=%.4f, transitionRatio=%.4f, bestModel=%s'], ...
        R2_PT, R2_k1, R2_PTk1, deltaR2, resVarFraction, transitionRatio, char(modelId(idxBest)));

    statusTbl = table();
    statusTbl.run_timestamp = string(runTimestamp);
    statusTbl.EXECUTION_STATUS = "SUCCESS";
    statusTbl.INPUT_FOUND = "YES";
    statusTbl.ERROR_MESSAGE = "";
    statusTbl.N_T = n;
    statusTbl.MAIN_RESULT_SUMMARY = string(mainSummary);
    statusTbl.n_aligned = n;
    statusTbl.kappa2_std = kappa2Std;
    statusTbl.R2_mean_model = fracVarExplainedMean;
    statusTbl.TRIVIAL_VARIANCE_REGIME = trivialVarianceFlag;
    statusTbl.R2_PT = R2_PT;
    statusTbl.R2_kappa1 = R2_k1;
    statusTbl.R2_PT_plus_kappa1 = R2_PTk1;
    statusTbl.Delta_R2 = deltaR2;
    statusTbl.residual_variance_fraction = resVarFraction;
    statusTbl.corr_residual_T_pearson = corr_r_T;
    statusTbl.corr_residual_T_spearman = corr_r_T_s;
    statusTbl.corr_residual_kappa1_pearson = corr_r_k1;
    statusTbl.corr_residual_kappa1_spearman = corr_r_k1_s;
    statusTbl.corr_residual_pt_width_q90_q10 = corr_r_f1;
    statusTbl.corr_residual_pt_asymmetry = corr_r_f2;
    statusTbl.corr_residual_pt_std_I = corr_r_f3;
    statusTbl.corr_residual_pt_width_q75_q25 = corr_r_f4;
    statusTbl.residual_rms_inside_22_24K = rmsIn;
    statusTbl.residual_rms_outside_22_24K = rmsOut;
    statusTbl.residual_transition_ratio = transitionRatio;
    statusTbl.residual_svd_energy_mode1 = svd_energy1;
    statusTbl.residual_svd_energy_mode1_2 = svd_energy12;
    statusTbl.residual_lag1_corr = lag1_corr;
    statusTbl.residual_mode_type = residualModeType;
    statusTbl.best_model_for_residual_test = modelId(idxBest);
    statusTbl.KAPPA2_HAS_GEOMETRIC_COMPONENT = KAPPA2_HAS_GEOMETRIC_COMPONENT;
    statusTbl.KAPPA2_IS_CLOSED = KAPPA2_IS_CLOSED;
    statusTbl.KAPPA2_HAS_REORGANIZATION_RESIDUAL = KAPPA2_HAS_REORGANIZATION_RESIDUAL;
    statusTbl.KAPPA2_PARTIALLY_OPENED = KAPPA2_PARTIALLY_OPENED;
    statusTbl.source_kappa1 = string(kappa1Path);
    statusTbl.source_kappa2 = string(kappa2Path);
    statusTbl.source_pt = string(ptPath);
    writetable(statusTbl, statusOutPath);

    % -----------------------------
    % Report
    % -----------------------------
    modelBlock = evalc('disp(modelsTbl)');
    decompBlock = evalc('disp(decompTbl)');

    reportLines = {};
    reportLines{end + 1} = '# kappa2 opening test (strict identification)';
    reportLines{end + 1} = '';
    reportLines{end + 1} = '## Canonical inputs';
    reportLines{end + 1} = ['- kappa1: `' strrep(kappa1Path, '\', '/') '`'];
    reportLines{end + 1} = ['- kappa2: `' strrep(kappa2Path, '\', '/') '`'];
    reportLines{end + 1} = ['- PT matrix: `' strrep(ptPath, '\', '/') '`'];
    reportLines{end + 1} = '';
    reportLines{end + 1} = '## STEP 0: Data sanity';
    reportLines{end + 1} = ['- n_aligned = **' num2str(n) '**'];
    reportLines{end + 1} = ['- std(kappa2) = **' num2str(kappa2Std, '%.6g') '**'];
    reportLines{end + 1} = ['- fraction of variance explained by mean model (LOOCV R2) = **' num2str(fracVarExplainedMean, '%.6g') '**'];
    reportLines{end + 1} = ['- trivial variance regime flag = **' char(trivialVarianceFlag) '** (threshold std < ' num2str(tinyStdThreshold) ')'];
    reportLines{end + 1} = '';
    reportLines{end + 1} = '## STEP 1: Base models (LOOCV)';
    reportLines{end + 1} = '```text';
    reportLines{end + 1} = strtrim(modelBlock);
    reportLines{end + 1} = '```';
    reportLines{end + 1} = '';
    reportLines{end + 1} = '## STEP 2: Explained variance decomposition';
    reportLines{end + 1} = '```text';
    reportLines{end + 1} = strtrim(decompBlock);
    reportLines{end + 1} = '```';
    reportLines{end + 1} = ['- Delta R2 = R2(PT+kappa1) - max(R2_PT, R2_kappa1) = **' num2str(deltaR2, '%.6g') '**'];
    reportLines{end + 1} = '';
    reportLines{end + 1} = '## STEP 3: Residual structure (best of PT+kappa1 / nonlinear)';
    reportLines{end + 1} = ['- best model used for residual test: `' char(modelId(idxBest)) '`'];
    reportLines{end + 1} = ['- residual variance fraction var(r)/var(kappa2) = **' num2str(resVarFraction, '%.6g') '**'];
    reportLines{end + 1} = ['- corr(r, T): Pearson = **' num2str(corr_r_T, '%.6g') '**, Spearman = **' num2str(corr_r_T_s, '%.6g') '**'];
    reportLines{end + 1} = ['- corr(r, kappa1): Pearson = **' num2str(corr_r_k1, '%.6g') '**, Spearman = **' num2str(corr_r_k1_s, '%.6g') '**'];
    reportLines{end + 1} = ['- corr(r, PT width q90-q10) = **' num2str(corr_r_f1, '%.6g') '**'];
    reportLines{end + 1} = ['- corr(r, PT asymmetry) = **' num2str(corr_r_f2, '%.6g') '**'];
    reportLines{end + 1} = ['- corr(r, PT std I) = **' num2str(corr_r_f3, '%.6g') '**'];
    reportLines{end + 1} = ['- corr(r, PT width q75-q25) = **' num2str(corr_r_f4, '%.6g') '**'];
    reportLines{end + 1} = '';
    reportLines{end + 1} = '## STEP 4: Transition localization';
    reportLines{end + 1} = ['- RMS residual inside 22-24K = **' num2str(rmsIn, '%.6g') '**'];
    reportLines{end + 1} = ['- RMS residual outside 22-24K = **' num2str(rmsOut, '%.6g') '**'];
    reportLines{end + 1} = ['- transition ratio (inside/outside) = **' num2str(transitionRatio, '%.6g') '**'];
    reportLines{end + 1} = '';
    reportLines{end + 1} = '## STEP 5: Low-dimensionality test (residual trajectory)';
    reportLines{end + 1} = ['- SVD mode-1 energy fraction = **' num2str(svd_energy1, '%.6g') '**'];
    reportLines{end + 1} = ['- SVD mode-(1+2) energy fraction = **' num2str(svd_energy12, '%.6g') '**'];
    reportLines{end + 1} = ['- residual lag-1 correlation = **' num2str(lag1_corr, '%.6g') '**'];
    reportLines{end + 1} = ['- residual mode type = **' char(residualModeType) '**'];
    reportLines{end + 1} = '';
    reportLines{end + 1} = '## STEP 6: Strict decision logic';
    reportLines{end + 1} = ['- geometric criterion: R2_PT >= 0.2 OR RMSE improvement of PT+kappa1 over mean >= 10%%'];
    reportLines{end + 1} = ['  values: R2_PT = ' num2str(R2_PT, '%.6g') ', RMSE improvement = ' num2str(rmseImprovePTk1Pct, '%.6g') '%'];
    reportLines{end + 1} = ['  => KAPPA2_HAS_GEOMETRIC_COMPONENT = **' char(KAPPA2_HAS_GEOMETRIC_COMPONENT) '**'];
    reportLines{end + 1} = ['- closed criterion: R2_PT+kappa1 >= 0.7 AND residual variance <= 0.30'];
    reportLines{end + 1} = ['  values: R2_PT+kappa1 = ' num2str(R2_PTk1, '%.6g') ', residual variance fraction = ' num2str(resVarFraction, '%.6g')];
    reportLines{end + 1} = ['  => KAPPA2_IS_CLOSED = **' char(KAPPA2_IS_CLOSED) '**'];
    reportLines{end + 1} = ['- reorganization criterion: residual variance >= 0.40 OR |corr(r,T)| >= ' num2str(strongCorrThreshold) ' OR transition ratio >= 1.5'];
    reportLines{end + 1} = ['  values: residual variance fraction = ' num2str(resVarFraction, '%.6g') ', |corr(r,T)| = ' num2str(abs(corr_r_T), '%.6g') ', transition ratio = ' num2str(transitionRatio, '%.6g')];
    reportLines{end + 1} = ['  => KAPPA2_HAS_REORGANIZATION_RESIDUAL = **' char(KAPPA2_HAS_REORGANIZATION_RESIDUAL) '**'];
    reportLines{end + 1} = ['- KAPPA2_PARTIALLY_OPENED (geometric YES and residual YES) = **' char(KAPPA2_PARTIALLY_OPENED) '**'];
    reportLines{end + 1} = '';
    reportLines{end + 1} = '## Final answers (required)';
    reportLines{end + 1} = ['1. Explained by PT + kappa1: R2_PT+kappa1 = **' num2str(R2_PTk1, '%.6g') '**, DeltaR2 over best single = **' num2str(deltaR2, '%.6g') '**.'];
    reportLines{end + 1} = ['2. Remaining part structured or noise: residual variance fraction = **' num2str(resVarFraction, '%.6g') '**; residual mode = **' char(residualModeType) '**.'];
    reportLines{end + 1} = ['3. Residual localized near transition: transition ratio = **' num2str(transitionRatio, '%.6g') '** (22-24K vs outside).'];
    reportLines{end + 1} = ['4. Is kappa2 closed: **' char(KAPPA2_IS_CLOSED) '**.'];

    fid = fopen(reportOutPath, 'w');
    assert(fid ~= -1, 'Cannot open report output path: %s', reportOutPath);
    for i = 1:numel(reportLines)
        fprintf(fid, '%s\n', reportLines{i});
    end
    fclose(fid);

    fprintf('\n=== kappa2 opening test complete ===\n');
    fprintf('models: %s\n', modelsOutPath);
    fprintf('decomposition: %s\n', decompOutPath);
    fprintf('residuals: %s\n', residOutPath);
    fprintf('report: %s\n', reportOutPath);
    fprintf('status: %s\n', statusOutPath);
    fprintf('KAPPA2_HAS_GEOMETRIC_COMPONENT: %s\n', char(KAPPA2_HAS_GEOMETRIC_COMPONENT));
    fprintf('KAPPA2_IS_CLOSED: %s\n', char(KAPPA2_IS_CLOSED));
    fprintf('KAPPA2_HAS_REORGANIZATION_RESIDUAL: %s\n', char(KAPPA2_HAS_REORGANIZATION_RESIDUAL));
    fprintf('KAPPA2_PARTIALLY_OPENED: %s\n', char(KAPPA2_PARTIALLY_OPENED));

catch ME
    errMsg = string(ME.message);
    errReport = string(getReport(ME, 'extended', 'hyperlinks', 'off'));

    failModels = table( ...
        "FAILED", 0, NaN, NaN, NaN, NaN, NaN, ...
        'VariableNames', {'model_id', 'n', 'loocv_rmse', 'R2_loocv', ...
        'pearson_y_yhat', 'spearman_y_yhat', 'rmse_improvement_pct_vs_mean'});
    writetable(failModels, modelsOutPath);

    failDecomp = table(0, NaN, NaN, NaN, NaN, NaN, NaN, ...
        'VariableNames', {'n_aligned', 'kappa2_std', 'R2_mean_model', ...
        'R2_PT', 'R2_kappa1', 'R2_PT_plus_kappa1', 'Delta_R2_PTk1_vs_best_single'});
    writetable(failDecomp, decompOutPath);

    failResid = table(NaN(0,1), NaN(0,1), NaN(0,1), NaN(0,1), NaN(0,1), NaN(0,1), NaN(0,1), NaN(0,1), NaN(0,1), false(0,1), ...
        NaN(0,1), NaN(0,1), NaN(0,1), NaN(0,1), ...
        'VariableNames', {'T_K', 'kappa1', 'kappa2', ...
        'yhat_PT', 'yhat_kappa1', 'yhat_PT_plus_kappa1', 'yhat_small_nonlinear', ...
        'yhat_best', 'residual_best', 'is_transition_22_24K', ...
        'pt_width_q90_q10', 'pt_asymmetry', 'pt_std_I', 'pt_width_q75_q25'});
    writetable(failResid, residOutPath);

    failStatus = table();
    failStatus.run_timestamp = string(runTimestamp);
    failStatus.EXECUTION_STATUS = "FAILED";
    failStatus.INPUT_FOUND = "NO";
    failStatus.ERROR_MESSAGE = errMsg;
    failStatus.N_T = 0;
    failStatus.MAIN_RESULT_SUMMARY = "FAILED";
    failStatus.n_aligned = 0;
    failStatus.kappa2_std = NaN;
    failStatus.R2_mean_model = NaN;
    failStatus.TRIVIAL_VARIANCE_REGIME = "UNKNOWN";
    failStatus.R2_PT = NaN;
    failStatus.R2_kappa1 = NaN;
    failStatus.R2_PT_plus_kappa1 = NaN;
    failStatus.Delta_R2 = NaN;
    failStatus.residual_variance_fraction = NaN;
    failStatus.corr_residual_T_pearson = NaN;
    failStatus.corr_residual_T_spearman = NaN;
    failStatus.corr_residual_kappa1_pearson = NaN;
    failStatus.corr_residual_kappa1_spearman = NaN;
    failStatus.corr_residual_pt_width_q90_q10 = NaN;
    failStatus.corr_residual_pt_asymmetry = NaN;
    failStatus.corr_residual_pt_std_I = NaN;
    failStatus.corr_residual_pt_width_q75_q25 = NaN;
    failStatus.residual_rms_inside_22_24K = NaN;
    failStatus.residual_rms_outside_22_24K = NaN;
    failStatus.residual_transition_ratio = NaN;
    failStatus.residual_svd_energy_mode1 = NaN;
    failStatus.residual_svd_energy_mode1_2 = NaN;
    failStatus.residual_lag1_corr = NaN;
    failStatus.residual_mode_type = "UNDETERMINED";
    failStatus.best_model_for_residual_test = "FAILED";
    failStatus.KAPPA2_HAS_GEOMETRIC_COMPONENT = "NO";
    failStatus.KAPPA2_IS_CLOSED = "NO";
    failStatus.KAPPA2_HAS_REORGANIZATION_RESIDUAL = "NO";
    failStatus.KAPPA2_PARTIALLY_OPENED = "NO";
    failStatus.source_kappa1 = "";
    failStatus.source_kappa2 = "";
    failStatus.source_pt = "";
    writetable(failStatus, statusOutPath);

    fid = fopen(reportOutPath, 'w');
    if fid ~= -1
        fprintf(fid, '# kappa2 opening test (strict identification)\n\n');
        fprintf(fid, '## Status\n');
        fprintf(fid, '- FAILED\n\n');
        fprintf(fid, '## Error message\n');
        fprintf(fid, '- `%s`\n\n', char(errMsg));
        fprintf(fid, '## Error report\n');
        fprintf(fid, '```text\n%s\n```\n', char(errReport));
        fclose(fid);
    end

    fprintf(2, '\n=== kappa2 opening test FAILED ===\n');
    fprintf(2, 'models: %s\n', modelsOutPath);
    fprintf(2, 'decomposition: %s\n', decompOutPath);
    fprintf(2, 'residuals: %s\n', residOutPath);
    fprintf(2, 'report: %s\n', reportOutPath);
    fprintf(2, 'status: %s\n', statusOutPath);
    fprintf(2, '%s\n', char(errMsg));
end

