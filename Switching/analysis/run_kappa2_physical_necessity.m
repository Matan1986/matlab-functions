clear; clc;
% run_kappa2_physical_necessity
% Determine whether kappa2 is physically required for aging or only empirical.
% Pure script (no function definitions).

clearvars;
clc;

repoRoot = 'C:\Dev\matlab-functions';
thisFile = fullfile(repoRoot, 'Switching', 'analysis', 'run_kappa2_physical_necessity.m');

% Canonical absolute inputs.
barrierPath = fullfile(repoRoot, 'results', 'cross_experiment', 'runs', ...
    'run_2026_03_25_031904_barrier_to_relaxation_mechanism', 'tables', 'barrier_descriptors.csv');
alphaStructurePath = fullfile(repoRoot, 'tables', 'alpha_structure.csv');
alphaDecompPath = fullfile(repoRoot, 'tables', 'alpha_decomposition.csv');

% Required outputs.
comparisonCsvPath = fullfile(repoRoot, 'tables', 'aging_model_comparison_strict.csv');
reportMdPath = fullfile(repoRoot, 'reports', 'kappa2_physical_necessity.md');

% Additional explicit status artifact (repo rule).
statusCsvPath = fullfile(repoRoot, 'tables', 'kappa2_physical_necessity_status.csv');

if exist(fileparts(comparisonCsvPath), 'dir') ~= 7, mkdir(fileparts(comparisonCsvPath)); end
if exist(fileparts(reportMdPath), 'dir') ~= 7, mkdir(fileparts(reportMdPath)); end
if exist(fileparts(statusCsvPath), 'dir') ~= 7, mkdir(fileparts(statusCsvPath)); end

% Defaults for always-write behavior.
executionStatus = "FAIL";
inputFound = "NO";
errorMessage = "";
mainSummary = "Not completed.";

KAPPA2_REQUIRED_FOR_AGING = "NO";
ALPHA_BETTER_THAN_KAPPA2 = "NO";
KAPPA1_SUFFICIENT = "NO";

nAligned = 0;

tolT = 1e-9;
tol = 1e-12;
smallDataThreshold = 5;
nearConstStdThreshold = 1e-10;

% Model definitions.
modelLabel = string([
    "R ~ PT";
    "R ~ PT + kappa1";
    "R ~ PT + kappa1 + alpha";
    "R ~ PT + kappa1 + kappa2"
    ]);
modelTerms = string([
    "PT";
    "PT,kappa1";
    "PT,kappa1,alpha";
    "PT,kappa1,kappa2"
    ]);
nModels = numel(modelLabel);

% Predefine model result table schema.
modelTbl = table();
modelTbl.row_type = repmat("model", nModels, 1);
modelTbl.label = modelLabel;
modelTbl.terms = modelTerms;
modelTbl.n_valid_rows_before = nan(nModels, 1);
modelTbl.n_rows_used = nan(nModels, 1);
modelTbl.n_predictors_raw = nan(nModels, 1);
modelTbl.n_predictors_used = nan(nModels, 1);
modelTbl.n_predictors_dropped_near_constant = nan(nModels, 1);
modelTbl.model_skipped = repmat("YES", nModels, 1);
modelTbl.skip_reason = repmat("NOT_RUN", nModels, 1);
modelTbl.loocv_rmse = nan(nModels, 1);
modelTbl.pearson_y_yhat = nan(nModels, 1);
modelTbl.transition_mae_22_24K = nan(nModels, 1);
modelTbl.mae_outside_22_24K = nan(nModels, 1);
modelTbl.jackknife_rmse_std = nan(nModels, 1);
modelTbl.jackknife_rmse_range = nan(nModels, 1);
modelTbl.prediction_variance_mean = nan(nModels, 1);
modelTbl.prediction_variance_max = nan(nModels, 1);
modelTbl.contribution_rmse = nan(nModels, 1);
modelTbl.contribution_transition = nan(nModels, 1);

comparisonTbl = modelTbl;

try
    % Validate canonical inputs.
    if isfile(barrierPath) && isfile(alphaStructurePath) && isfile(alphaDecompPath)
        inputFound = "YES";
    else
        error('Missing canonical input files.');
    end

    barrierTbl = readtable(barrierPath, 'VariableNamingRule', 'preserve');
    alphaTbl = readtable(alphaStructurePath, 'VariableNamingRule', 'preserve');
    decompTbl = readtable(alphaDecompPath, 'VariableNamingRule', 'preserve');

    % Column detection by contains() only.
    bNames = string(barrierTbl.Properties.VariableNames);
    aNames = string(alphaTbl.Properties.VariableNames);
    dNames = string(decompTbl.Properties.VariableNames);

    idxBT = find(contains(lower(bNames), 't_k'), 1, 'first');
    idxBRowValid = find(contains(lower(bNames), 'row_valid'), 1, 'first');
    idxBR = find(contains(lower(bNames), 'r_t_interp'), 1, 'first');
    idxBQ90 = find(contains(lower(bNames), 'q90') & contains(lower(bNames), 'i_ma'), 1, 'first');
    idxBQ50 = find(contains(lower(bNames), 'q50') & contains(lower(bNames), 'i_ma'), 1, 'first');

    idxAT = find(contains(lower(aNames), 't_k'), 1, 'first');
    idxAK1 = find(contains(lower(aNames), 'kappa1'), 1, 'first');
    idxAK2 = find(contains(lower(aNames), 'kappa2'), 1, 'first');
    idxAAlpha = find(contains(lower(aNames), 'alpha') & ~contains(lower(aNames), 'res') & ...
        ~contains(lower(aNames), 'geom') & ~contains(lower(aNames), 'abs'), 1, 'first');

    idxDT = find(contains(lower(dNames), 't_k'), 1, 'first');
    idxDPTValid = find(contains(lower(dNames), 'pt_geometry_valid'), 1, 'first');

    if isempty(idxBT) || isempty(idxBRowValid) || isempty(idxBR) || isempty(idxBQ90) || isempty(idxBQ50) || ...
            isempty(idxAT) || isempty(idxAK1) || isempty(idxAK2) || isempty(idxAAlpha) || ...
            isempty(idxDT) || isempty(idxDPTValid)
        error('Required columns not found by contains() matching.');
    end

    barrierT = double(barrierTbl{:, idxBT});
    barrierRowValid = double(barrierTbl{:, idxBRowValid});
    barrierR = double(barrierTbl{:, idxBR});
    PT = double(barrierTbl{:, idxBQ90}) - double(barrierTbl{:, idxBQ50});

    alphaT = double(alphaTbl{:, idxAT});
    kappa1 = double(alphaTbl{:, idxAK1});
    kappa2 = double(alphaTbl{:, idxAK2});
    alpha = double(alphaTbl{:, idxAAlpha});

    decompT = double(decompTbl{:, idxDT});
    ptGeomValid = double(decompTbl{:, idxDPTValid});

    % Finite source filtering only (no filling).
    mB = isfinite(barrierT) & isfinite(barrierRowValid) & isfinite(barrierR) & isfinite(PT);
    barrierT = barrierT(mB);
    barrierRowValid = barrierRowValid(mB);
    barrierR = barrierR(mB);
    PT = PT(mB);

    mA = isfinite(alphaT) & isfinite(kappa1) & isfinite(kappa2) & isfinite(alpha);
    alphaT = alphaT(mA);
    kappa1 = kappa1(mA);
    kappa2 = kappa2(mA);
    alpha = alpha(mA);

    mD = isfinite(decompT) & isfinite(ptGeomValid);
    decompT = decompT(mD);
    ptGeomValid = ptGeomValid(mD);

    if numel(unique(barrierT)) ~= numel(barrierT)
        error('Duplicate T_K in barrier table after finite filtering.');
    end
    if numel(unique(alphaT)) ~= numel(alphaT)
        error('Duplicate T_K in alpha table after finite filtering.');
    end
    if numel(unique(decompT)) ~= numel(decompT)
        error('Duplicate T_K in decomp table after finite filtering.');
    end

    % Manual T_K alignment only.
    T_aligned = [];
    R_aligned = [];
    PT_aligned = [];
    k1_aligned = [];
    k2_aligned = [];
    alpha_aligned = [];

    for i = 1:numel(alphaT)
        t = alphaT(i);
        idxB = find(abs(barrierT - t) <= tolT, 1, 'first');
        idxD = find(abs(decompT - t) <= tolT, 1, 'first');
        if isempty(idxB) || isempty(idxD)
            continue;
        end
        if ~(barrierRowValid(idxB) ~= 0)
            continue;
        end
        if ~(ptGeomValid(idxD) ~= 0)
            continue;
        end

        T_aligned(end + 1, 1) = t; %#ok<AGROW>
        R_aligned(end + 1, 1) = barrierR(idxB); %#ok<AGROW>
        PT_aligned(end + 1, 1) = PT(idxB); %#ok<AGROW>
        k1_aligned(end + 1, 1) = kappa1(i); %#ok<AGROW>
        k2_aligned(end + 1, 1) = kappa2(i); %#ok<AGROW>
        alpha_aligned(end + 1, 1) = alpha(i); %#ok<AGROW>
    end

    if isempty(T_aligned)
        error('No aligned rows after canonical gates.');
    end

    [T_K, ord] = sort(T_aligned, 'ascend');
    Rv = R_aligned(ord);
    PTv = PT_aligned(ord);
    k1v = k1_aligned(ord);
    k2v = k2_aligned(ord);
    alphav = alpha_aligned(ord);

    nAligned = numel(T_K);

    % Constant baseline for term-contribution reference.
    rmseConst = NaN;
    transConst = NaN;
    mY = isfinite(Rv);
    if nnz(mY) >= 2
        yb = Rv(mY);
        Tb = T_K(mY);
        nb = numel(yb);
        yhatB = nan(nb,1);
        for i = 1:nb
            tr = true(nb,1);
            tr(i) = false;
            yhatB(i) = mean(yb(tr), 'omitnan');
        end
        rmseConst = sqrt(mean((yb - yhatB).^2, 'omitnan'));
        twinB = (Tb >= 22) & (Tb <= 24);
        transConst = mean(abs(yb(twinB) - yhatB(twinB)), 'omitnan');
    end

    for m = 1:nModels
        if m == 1
            X_raw = [PTv];
        elseif m == 2
            X_raw = [PTv, k1v];
        elseif m == 3
            X_raw = [PTv, k1v, alphav];
        else
            X_raw = [PTv, k1v, k2v];
        end

        y_raw = Rv;

        modelTbl.n_valid_rows_before(m) = size(X_raw, 1);
        modelTbl.n_predictors_raw(m) = size(X_raw, 2);

        mask = all(isfinite(X_raw), 2) & isfinite(y_raw);
        X = X_raw(mask, :);
        y = y_raw(mask);
        Tm = T_K(mask);

        modelTbl.n_rows_used(m) = size(X, 1);

        if size(X, 1) < smallDataThreshold
            modelTbl.model_skipped(m) = "YES";
            modelTbl.skip_reason(m) = "SMALL_DATA_LT5";
            continue;
        end

        colStd = std(X, 0, 1);
        keepCol = colStd >= nearConstStdThreshold;
        modelTbl.n_predictors_dropped_near_constant(m) = sum(~keepCol);

        if ~any(keepCol)
            modelTbl.model_skipped(m) = "YES";
            modelTbl.skip_reason(m) = "ALL_COLUMNS_NEAR_CONSTANT";
            modelTbl.n_predictors_used(m) = 0;
            continue;
        end

        X = X(:, keepCol);
        modelTbl.n_predictors_used(m) = size(X, 2);

        muX = mean(X, 1);
        sdX = std(X, 0, 1);
        X = (X - muX) ./ sdX;

        Z = [ones(size(X,1),1), X];
        if rank(Z) < size(Z, 2)
            modelTbl.model_skipped(m) = "YES";
            modelTbl.skip_reason(m) = "RANK_DEFICIENT";
            continue;
        end

        n = size(X, 1);
        yhat = nan(n, 1);
        loocvFail = false;
        loocvReason = "";

        for i = 1:n
            tr = true(n, 1);
            tr(i) = false;
            Ztr = [ones(nnz(tr),1), X(tr,:)];
            if rank(Ztr) < size(Ztr, 2)
                loocvFail = true;
                loocvReason = "LOOCV_TRAIN_RANK_DEFICIENT";
                break;
            end
            beta = pinv(Ztr) * y(tr);
            yhat(i) = [1, X(i,:)] * beta;
        end

        if loocvFail
            modelTbl.model_skipped(m) = "YES";
            modelTbl.skip_reason(m) = loocvReason;
            continue;
        end

        if any(~isfinite(yhat))
            modelTbl.model_skipped(m) = "YES";
            modelTbl.skip_reason(m) = "LOOCV_NONFINITE_PRED";
            continue;
        end

        resid = y - yhat;
        twin = (Tm >= 22) & (Tm <= 24);
        mOther = ~twin;

        modelTbl.model_skipped(m) = "NO";
        modelTbl.skip_reason(m) = "";
        modelTbl.loocv_rmse(m) = sqrt(mean((y - yhat).^2, 'omitnan'));
        modelTbl.pearson_y_yhat(m) = corr(y, yhat, 'rows', 'complete');
        modelTbl.transition_mae_22_24K(m) = mean(abs(resid(twin)), 'omitnan');
        modelTbl.mae_outside_22_24K(m) = mean(abs(resid(mOther)), 'omitnan');

        % Stability: sensitivity to removing one point and prediction variance.
        predMatrix = nan(n, n);
        rmseJack = nan(n, 1);
        for j = 1:n
            tr = true(n, 1);
            tr(j) = false;
            Ztr = [ones(nnz(tr),1), X(tr,:)];
            if rank(Ztr) < size(Ztr, 2)
                continue;
            end
            betaJ = pinv(Ztr) * y(tr);
            predJ = [ones(n,1), X] * betaJ;
            predMatrix(:, j) = predJ;
            rmseJack(j) = sqrt(mean((y - predJ).^2, 'omitnan'));
        end

        modelTbl.jackknife_rmse_std(m) = std(rmseJack, 'omitnan');
        modelTbl.jackknife_rmse_range(m) = max(rmseJack, [], 'omitnan') - min(rmseJack, [], 'omitnan');

        predVar = var(predMatrix, 0, 2, 'omitnan');
        modelTbl.prediction_variance_mean(m) = mean(predVar, 'omitnan');
        modelTbl.prediction_variance_max(m) = max(predVar, [], 'omitnan');
    end

    % Term contribution metrics.
    rmsePT = modelTbl.loocv_rmse(1);
    rmsePTK1 = modelTbl.loocv_rmse(2);
    rmsePTK1A = modelTbl.loocv_rmse(3);
    rmsePTK1K2 = modelTbl.loocv_rmse(4);

    trPT = modelTbl.transition_mae_22_24K(1);
    trPTK1 = modelTbl.transition_mae_22_24K(2);
    trPTK1A = modelTbl.transition_mae_22_24K(3);
    trPTK1K2 = modelTbl.transition_mae_22_24K(4);

    c_pt_rmse = rmseConst - rmsePT;
    c_k1_rmse = rmsePT - rmsePTK1;
    c_alpha_rmse = rmsePTK1 - rmsePTK1A;
    c_k2_rmse = rmsePTK1 - rmsePTK1K2;

    c_pt_tr = transConst - trPT;
    c_k1_tr = trPT - trPTK1;
    c_alpha_tr = trPTK1 - trPTK1A;
    c_k2_tr = trPTK1 - trPTK1K2;

    contribTbl = table();
    contribTbl.row_type = repmat("contribution", 4, 1);
    contribTbl.label = string(["PT"; "kappa1"; "alpha"; "kappa2"]);
    contribTbl.terms = repmat("", 4, 1);
    contribTbl.n_valid_rows_before = nan(4,1);
    contribTbl.n_rows_used = nan(4,1);
    contribTbl.n_predictors_raw = nan(4,1);
    contribTbl.n_predictors_used = nan(4,1);
    contribTbl.n_predictors_dropped_near_constant = nan(4,1);
    contribTbl.model_skipped = repmat("NO", 4, 1);
    contribTbl.skip_reason = repmat("", 4, 1);
    contribTbl.loocv_rmse = nan(4,1);
    contribTbl.pearson_y_yhat = nan(4,1);
    contribTbl.transition_mae_22_24K = nan(4,1);
    contribTbl.mae_outside_22_24K = nan(4,1);
    contribTbl.jackknife_rmse_std = nan(4,1);
    contribTbl.jackknife_rmse_range = nan(4,1);
    contribTbl.prediction_variance_mean = nan(4,1);
    contribTbl.prediction_variance_max = nan(4,1);
    contribTbl.contribution_rmse = [c_pt_rmse; c_k1_rmse; c_alpha_rmse; c_k2_rmse];
    contribTbl.contribution_transition = [c_pt_tr; c_k1_tr; c_alpha_tr; c_k2_tr];

    comparisonTbl = [modelTbl; contribTbl];

    % Verdict logic.
    valid3 = modelTbl.model_skipped(3) == "NO" && isfinite(rmsePTK1A);
    valid4 = modelTbl.model_skipped(4) == "NO" && isfinite(rmsePTK1K2);
    valid2 = modelTbl.model_skipped(2) == "NO" && isfinite(rmsePTK1);
    valid1 = modelTbl.model_skipped(1) == "NO" && isfinite(rmsePT);

    if valid4 && valid3 && (rmsePTK1K2 < rmsePTK1A - tol) && (trPTK1K2 < trPTK1A - tol)
        KAPPA2_REQUIRED_FOR_AGING = "YES";
    end

    if valid3 && valid4 && (rmsePTK1A < rmsePTK1K2 - tol) && (trPTK1A <= trPTK1K2 + tol)
        ALPHA_BETTER_THAN_KAPPA2 = "YES";
    end

    if valid2
        condAlphaNoNeed = (~valid3) || ((rmsePTK1A >= rmsePTK1 - tol) && (trPTK1A >= trPTK1 - tol));
        condK2NoNeed = (~valid4) || ((rmsePTK1K2 >= rmsePTK1 - tol) && (trPTK1K2 >= trPTK1 - tol));
        condBeatsPT = (~valid1) || (rmsePTK1 < rmsePT - tol);
        if condAlphaNoNeed && condK2NoNeed && condBeatsPT
            KAPPA1_SUFFICIENT = "YES";
        end
    end

    mainSummary = "valid_models=" + string(nnz(modelTbl.model_skipped == "NO")) + ...
        ", KAPPA2_REQUIRED_FOR_AGING=" + KAPPA2_REQUIRED_FOR_AGING + ...
        ", ALPHA_BETTER_THAN_KAPPA2=" + ALPHA_BETTER_THAN_KAPPA2 + ...
        ", KAPPA1_SUFFICIENT=" + KAPPA1_SUFFICIENT;

    executionStatus = "SUCCESS";

catch ME
    executionStatus = "FAIL";
    errorMessage = string(getReport(ME, 'extended', 'hyperlinks', 'off'));
    if strlength(mainSummary) == 0 || mainSummary == "Not completed."
        mainSummary = "Exception before completing strict model comparison.";
    end
end

% Always write comparison CSV.
try
    writetable(comparisonTbl, comparisonCsvPath);
catch MEw
    errorMessage = errorMessage + newline + "Failed writing comparison CSV: " + string(MEw.message);
end

% Always write report.
lines = {};
lines{end + 1} = '# kappa2 Physical Necessity (Strict LOOCV)';
lines{end + 1} = '';
lines{end + 1} = sprintf('- Script: `%s`', strrep(thisFile, '\', '/'));
lines{end + 1} = sprintf('- Generated: `%s`', datestr(now, 31));
lines{end + 1} = '';
lines{end + 1} = '## Inputs (Canonical)';
lines{end + 1} = sprintf('- `%s`', strrep(barrierPath, '\', '/'));
lines{end + 1} = sprintf('- `%s`', strrep(alphaStructurePath, '\', '/'));
lines{end + 1} = sprintf('- `%s`', strrep(alphaDecompPath, '\', '/'));
lines{end + 1} = '';
lines{end + 1} = '## Step 1: Models';
lines{end + 1} = '- 1) R ~ PT';
lines{end + 1} = '- 2) R ~ PT + kappa1';
lines{end + 1} = '- 3) R ~ PT + kappa1 + alpha';
lines{end + 1} = '- 4) R ~ PT + kappa1 + kappa2';
lines{end + 1} = '';
lines{end + 1} = '## Step 2: Strict LOOCV Metrics';
lines{end + 1} = '| Model | n_rows | RMSE | Pearson | transition MAE (22-24K) |';
lines{end + 1} = '|---|---:|---:|---:|---:|';
for i = 1:nModels
    lines{end + 1} = sprintf('| %s | %d | %.6g | %.6g | %.6g |', ...
        char(modelTbl.label(i)), ...
        modelTbl.n_rows_used(i), ...
        modelTbl.loocv_rmse(i), ...
        modelTbl.pearson_y_yhat(i), ...
        modelTbl.transition_mae_22_24K(i));
end
lines{end + 1} = '';
lines{end + 1} = '## Step 3: Stability';
lines{end + 1} = '| Model | jackknife RMSE std | jackknife RMSE range | mean prediction variance | max prediction variance |';
lines{end + 1} = '|---|---:|---:|---:|---:|';
for i = 1:nModels
    lines{end + 1} = sprintf('| %s | %.6g | %.6g | %.6g | %.6g |', ...
        char(modelTbl.label(i)), ...
        modelTbl.jackknife_rmse_std(i), ...
        modelTbl.jackknife_rmse_range(i), ...
        modelTbl.prediction_variance_mean(i), ...
        modelTbl.prediction_variance_max(i));
end
lines{end + 1} = '';
lines{end + 1} = '## Step 4: Term Contribution';
lines{end + 1} = '| Term | contribution RMSE | contribution transition MAE |';
lines{end + 1} = '|---|---:|---:|';
lines{end + 1} = sprintf('| PT | %.6g | %.6g |', c_pt_rmse, c_pt_tr);
lines{end + 1} = sprintf('| kappa1 | %.6g | %.6g |', c_k1_rmse, c_k1_tr);
lines{end + 1} = sprintf('| alpha | %.6g | %.6g |', c_alpha_rmse, c_alpha_tr);
lines{end + 1} = sprintf('| kappa2 | %.6g | %.6g |', c_k2_rmse, c_k2_tr);
lines{end + 1} = '';
lines{end + 1} = '## Verdicts';
lines{end + 1} = sprintf('- **KAPPA2_REQUIRED_FOR_AGING:** **%s**', char(KAPPA2_REQUIRED_FOR_AGING));
lines{end + 1} = sprintf('- **ALPHA_BETTER_THAN_KAPPA2:** **%s**', char(ALPHA_BETTER_THAN_KAPPA2));
lines{end + 1} = sprintf('- **KAPPA1_SUFFICIENT:** **%s**', char(KAPPA1_SUFFICIENT));
lines{end + 1} = '';
lines{end + 1} = sprintf('- Aligned rows used (pre-model filtering): `%d`', nAligned);
lines{end + 1} = sprintf('- Summary: `%s`', char(mainSummary));
lines{end + 1} = '';
lines{end + 1} = '## Artifacts';
lines{end + 1} = sprintf('- Comparison CSV: `%s`', strrep(comparisonCsvPath, '\', '/'));
lines{end + 1} = sprintf('- Report MD: `%s`', strrep(reportMdPath, '\', '/'));
lines{end + 1} = sprintf('- Status CSV: `%s`', strrep(statusCsvPath, '\', '/'));

if strlength(errorMessage) > 0
    lines{end + 1} = '';
    lines{end + 1} = '## Error Message';
    lines{end + 1} = '```';
    lines{end + 1} = char(errorMessage);
    lines{end + 1} = '```';
end

fid = fopen(reportMdPath, 'w');
if fid >= 0
    for i = 1:numel(lines)
        fprintf(fid, '%s\n', lines{i});
    end
    fclose(fid);
else
    errorMessage = errorMessage + newline + "Failed opening report for write.";
end

% Always write status CSV.
statusTbl = table( ...
    string(executionStatus), ...
    string(inputFound), ...
    double(nAligned), ...
    string(mainSummary), ...
    string(KAPPA2_REQUIRED_FOR_AGING), ...
    string(ALPHA_BETTER_THAN_KAPPA2), ...
    string(KAPPA1_SUFFICIENT), ...
    string(errorMessage), ...
    'VariableNames', {'EXECUTION_STATUS','INPUT_FOUND','N_ALIGNED','MAIN_RESULT_SUMMARY', ...
    'KAPPA2_REQUIRED_FOR_AGING','ALPHA_BETTER_THAN_KAPPA2','KAPPA1_SUFFICIENT','ERROR_MESSAGE'});

try
    writetable(statusTbl, statusCsvPath);
catch
    % Do not throw: keep always-output behavior best-effort.
end
