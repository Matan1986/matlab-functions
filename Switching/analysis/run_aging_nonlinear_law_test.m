% run_aging_nonlinear_law_test
% Stable alpha-observable modeling pipeline with explicit per-model data guards.
% Pure script (no local function definitions).

clearvars;
clc;

repoRoot = 'C:\Dev\matlab-functions';
thisFile = fullfile(repoRoot, 'Switching', 'analysis', 'run_aging_nonlinear_law_test.m');

% Canonical absolute inputs.
barrierPath = fullfile(repoRoot, 'results', 'cross_experiment', 'runs', ...
    'run_2026_03_25_031904_barrier_to_relaxation_mechanism', 'tables', 'barrier_descriptors.csv');
alphaStructurePath = fullfile(repoRoot, 'tables', 'alpha_structure.csv');
alphaDecompPath = fullfile(repoRoot, 'tables', 'alpha_decomposition.csv');

% Required absolute outputs.
debugCsvPath = fullfile(repoRoot, 'tables', 'alpha_observable_debug_full.csv');
modelsCsvPath = fullfile(repoRoot, 'tables', 'alpha_observable_models.csv');
statusCsvPath = fullfile(repoRoot, 'tables', 'alpha_observable_status.csv');
reportMdPath = fullfile(repoRoot, 'reports', 'alpha_observable_search.md');

if exist(fileparts(debugCsvPath), 'dir') ~= 7, mkdir(fileparts(debugCsvPath)); end
if exist(fileparts(modelsCsvPath), 'dir') ~= 7, mkdir(fileparts(modelsCsvPath)); end
if exist(fileparts(statusCsvPath), 'dir') ~= 7, mkdir(fileparts(statusCsvPath)); end
if exist(fileparts(reportMdPath), 'dir') ~= 7, mkdir(fileparts(reportMdPath)); end

% Defaults for guaranteed outputs.
executionStatus = "FAIL";
inputFound = "NO";
noCrash = "YES";
errorMessage = "";
mainResultSummary = "Pipeline did not complete.";

baselineModelId = "R ~ spread90_50 + kappa1 + alpha";
baselineWorks = "NO";
minRequiredModelsMet = "NO";

nT = 0;
nValidModels = 0;
modelsEvaluated = 0;

debugWritten = "NO";
modelsWritten = "NO";
reportWritten = "NO";
statusWritten = "NO";

tolT = 1e-9;
smallDataThreshold = 5;
nearConstStdThreshold = 1e-10;

% Predefine model catalog.
modelId = string([
    "R ~ spread90_50 + kappa1 + alpha";
    "R ~ spread90_50 + kappa1 + alpha + kappa1^2";
    "R ~ spread90_50 + kappa1 + alpha + alpha^2";
    "R ~ spread90_50 + kappa1 + alpha + kappa1*alpha";
    "R ~ spread90_50 + kappa1 + alpha + log(kappa1)";
    "R ~ spread90_50 + kappa1 + alpha + alpha/kappa1";
    "R ~ spread90_50 + kappa1 + alpha + kappa1/abs(alpha)";
    "R ~ spread90_50 + kappa1 + alpha + I(22<=T<=24)"
    ]);
addedTerm = string([
    "none";
    "kappa1_sq";
    "alpha_sq";
    "kappa1_alpha";
    "log_kappa1";
    "alpha_over_kappa1";
    "kappa1_over_abs_alpha";
    "transition_indicator"
    ]);
nModels = numel(modelId);

% Output schemas are initialized up front so they always exist.
debugTbl = table( ...
    nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
    nan(0,1), nan(0,1), nan(0,1), nan(0,1), false(0,1), ...
    'VariableNames', {'T_K','R','spread90_50','kappa1','alpha','kappa1_sq','alpha_sq', ...
    'kappa1_alpha','log_kappa1','alpha_over_kappa1','kappa1_over_abs_alpha', ...
    'transition_indicator','isfinite_row'});

modelsTbl = table();
modelsTbl.model = modelId;
modelsTbl.added_term = addedTerm;
modelsTbl.n_valid_rows_before = nan(nModels,1);
modelsTbl.n_rows_used = nan(nModels,1);
modelsTbl.n_predictors_raw = nan(nModels,1);
modelsTbl.n_predictors_used = nan(nModels,1);
modelsTbl.n_predictors_dropped_near_constant = nan(nModels,1);
modelsTbl.model_skipped = repmat("YES", nModels, 1);
modelsTbl.model_skipped_small_data = repmat("NO", nModels, 1);
modelsTbl.skip_reason = repmat("NOT_RUN", nModels, 1);
modelsTbl.loocv_rmse = nan(nModels,1);
modelsTbl.pearson_y_yhat = nan(nModels,1);
modelsTbl.spearman_y_yhat = nan(nModels,1);
modelsTbl.mae_resid_22_24K = nan(nModels,1);
modelsTbl.mae_resid_outside_22_24K = nan(nModels,1);

try
    % Load canonical tables.
    if isfile(barrierPath) && isfile(alphaStructurePath) && isfile(alphaDecompPath)
        inputFound = "YES";
    else
        error('Missing canonical input table(s).');
    end

    barrierTbl = readtable(barrierPath, 'VariableNamingRule', 'preserve');
    alphaTbl = readtable(alphaStructurePath, 'VariableNamingRule', 'preserve');
    decompTbl = readtable(alphaDecompPath, 'VariableNamingRule', 'preserve');

    % Column detection via contains() only.
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
    idxAAlpha = find(contains(lower(aNames), 'alpha') & ~contains(lower(aNames), 'res') & ...
        ~contains(lower(aNames), 'geom') & ~contains(lower(aNames), 'abs'), 1, 'first');

    idxDT = find(contains(lower(dNames), 't_k'), 1, 'first');
    idxDPTValid = find(contains(lower(dNames), 'pt_geometry_valid'), 1, 'first');

    if isempty(idxBT) || isempty(idxBRowValid) || isempty(idxBR) || isempty(idxBQ90) || isempty(idxBQ50) || ...
            isempty(idxAT) || isempty(idxAK1) || isempty(idxAAlpha) || isempty(idxDT) || isempty(idxDPTValid)
        error('Required columns not found with contains() matching.');
    end

    barrierT = double(barrierTbl{:, idxBT});
    barrierRowValid = double(barrierTbl{:, idxBRowValid});
    barrierR = double(barrierTbl{:, idxBR});
    barrierSpread = double(barrierTbl{:, idxBQ90}) - double(barrierTbl{:, idxBQ50});

    alphaT = double(alphaTbl{:, idxAT});
    alphaK1 = double(alphaTbl{:, idxAK1});
    alphaVal = double(alphaTbl{:, idxAAlpha});

    decompT = double(decompTbl{:, idxDT});
    decompPTValid = double(decompTbl{:, idxDPTValid});

    % Source-level finite filtering only (no interpolation, no fill).
    mB = isfinite(barrierT) & isfinite(barrierRowValid) & isfinite(barrierR) & isfinite(barrierSpread);
    barrierT = barrierT(mB);
    barrierRowValid = barrierRowValid(mB);
    barrierR = barrierR(mB);
    barrierSpread = barrierSpread(mB);

    mA = isfinite(alphaT) & isfinite(alphaK1) & isfinite(alphaVal);
    alphaT = alphaT(mA);
    alphaK1 = alphaK1(mA);
    alphaVal = alphaVal(mA);

    mD = isfinite(decompT) & isfinite(decompPTValid);
    decompT = decompT(mD);
    decompPTValid = decompPTValid(mD);

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
    spread_aligned = [];
    k1_aligned = [];
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
        if ~(decompPTValid(idxD) ~= 0)
            continue;
        end

        T_aligned(end + 1, 1) = t; %#ok<AGROW>
        R_aligned(end + 1, 1) = barrierR(idxB); %#ok<AGROW>
        spread_aligned(end + 1, 1) = barrierSpread(idxB); %#ok<AGROW>
        k1_aligned(end + 1, 1) = alphaK1(i); %#ok<AGROW>
        alpha_aligned(end + 1, 1) = alphaVal(i); %#ok<AGROW>
    end

    if isempty(T_aligned)
        error('No aligned rows after manual T_K alignment and canonical validity gates.');
    end

    [T_K, ord] = sort(T_aligned, 'ascend');
    R = R_aligned(ord);
    spread90_50 = spread_aligned(ord);
    kappa1 = k1_aligned(ord);
    alpha = alpha_aligned(ord);

    % Feature engineering with strict sanitation.
    kappa1_sq = kappa1 .^ 2;
    alpha_sq = alpha .^ 2;
    kappa1_alpha = kappa1 .* alpha;

    log_kappa1 = nan(size(kappa1));
    mLog = kappa1 > 0;
    log_kappa1(mLog) = log(kappa1(mLog));

    alpha_over_kappa1 = nan(size(kappa1));
    mR1 = abs(kappa1) > 1e-12;
    alpha_over_kappa1(mR1) = alpha(mR1) ./ kappa1(mR1);

    kappa1_over_abs_alpha = nan(size(kappa1));
    mR2 = abs(alpha) > 1e-12;
    kappa1_over_abs_alpha(mR2) = kappa1(mR2) ./ abs(alpha(mR2));

    transition_indicator = double((T_K >= 22) & (T_K <= 24));

    nT = numel(T_K);

    % Required full debug table before any regression.
    debugTbl = table(T_K, R, spread90_50, kappa1, alpha, kappa1_sq, alpha_sq, kappa1_alpha, ...
        log_kappa1, alpha_over_kappa1, kappa1_over_abs_alpha, transition_indicator, ...
        'VariableNames', {'T_K','R','spread90_50','kappa1','alpha','kappa1_sq','alpha_sq', ...
        'kappa1_alpha','log_kappa1','alpha_over_kappa1','kappa1_over_abs_alpha','transition_indicator'});
    debugTbl.isfinite_row = isfinite(debugTbl.T_K) & isfinite(debugTbl.R) & isfinite(debugTbl.spread90_50) & ...
        isfinite(debugTbl.kappa1) & isfinite(debugTbl.alpha) & isfinite(debugTbl.kappa1_sq) & ...
        isfinite(debugTbl.alpha_sq) & isfinite(debugTbl.kappa1_alpha) & isfinite(debugTbl.log_kappa1) & ...
        isfinite(debugTbl.alpha_over_kappa1) & isfinite(debugTbl.kappa1_over_abs_alpha) & ...
        isfinite(debugTbl.transition_indicator);

    try
        writetable(debugTbl, debugCsvPath);
        debugWritten = "YES";
    catch MEdbg
        debugWritten = "NO";
        errorMessage = errorMessage + newline + "Debug CSV write failed: " + string(MEdbg.message);
    end

    % Per-model evaluation (NO global overlap mask).
    twin = (T_K >= 22) & (T_K <= 24);
    mOther = ~twin;

    for m = 1:nModels
        if m == 1
            X_raw = [spread90_50, kappa1, alpha];
        elseif m == 2
            X_raw = [spread90_50, kappa1, alpha, kappa1_sq];
        elseif m == 3
            X_raw = [spread90_50, kappa1, alpha, alpha_sq];
        elseif m == 4
            X_raw = [spread90_50, kappa1, alpha, kappa1_alpha];
        elseif m == 5
            X_raw = [spread90_50, kappa1, alpha, log_kappa1];
        elseif m == 6
            X_raw = [spread90_50, kappa1, alpha, alpha_over_kappa1];
        elseif m == 7
            X_raw = [spread90_50, kappa1, alpha, kappa1_over_abs_alpha];
        else
            X_raw = [spread90_50, kappa1, alpha, transition_indicator];
        end

        y_raw = R;
        modelsTbl.n_valid_rows_before(m) = size(X_raw, 1);
        modelsTbl.n_predictors_raw(m) = size(X_raw, 2);

        % Required sanitation path per model.
        mask = all(isfinite(X_raw), 2) & isfinite(y_raw);
        X = X_raw(mask, :);
        y = y_raw(mask);
        Tm = T_K(mask);
        twinM = twin(mask);
        mOtherM = mOther(mask);

        modelsTbl.n_rows_used(m) = size(X, 1);

        if size(X, 1) < smallDataThreshold
            modelsTbl.model_skipped(m) = "YES";
            modelsTbl.model_skipped_small_data(m) = "YES";
            modelsTbl.skip_reason(m) = "SMALL_DATA_LT5";
            continue;
        end

        % Numerical stability: remove near-constant columns.
        colStd = std(X, 0, 1);
        keepCol = colStd >= nearConstStdThreshold;
        modelsTbl.n_predictors_dropped_near_constant(m) = sum(~keepCol);

        if ~any(keepCol)
            modelsTbl.model_skipped(m) = "YES";
            modelsTbl.model_skipped_small_data(m) = "NO";
            modelsTbl.skip_reason(m) = "ALL_COLUMNS_NEAR_CONSTANT";
            modelsTbl.n_predictors_used(m) = 0;
            continue;
        end

        X = X(:, keepCol);
        modelsTbl.n_predictors_used(m) = size(X, 2);

        % Numerical stability: z-score columns after pruning.
        muX = mean(X, 1);
        sdX = std(X, 0, 1);
        X = (X - muX) ./ sdX;

        Z = [ones(size(X, 1), 1), X];
        if rank(Z) < size(Z, 2)
            modelsTbl.model_skipped(m) = "YES";
            modelsTbl.model_skipped_small_data(m) = "NO";
            modelsTbl.skip_reason(m) = "RANK_DEFICIENT";
            continue;
        end

        % Safe LOOCV regression with pinv.
        n = size(X, 1);
        yhat = nan(n, 1);
        foldFailure = false;
        foldReason = "";
        for i = 1:n
            tr = true(n, 1);
            tr(i) = false;
            Ztr = [ones(nnz(tr), 1), X(tr, :)];
            if rank(Ztr) < size(Ztr, 2)
                foldFailure = true;
                foldReason = "LOOCV_TRAIN_RANK_DEFICIENT";
                break;
            end
            beta = pinv(Ztr) * y(tr);
            yhat(i) = [1, X(i, :)] * beta;
        end

        if foldFailure
            modelsTbl.model_skipped(m) = "YES";
            modelsTbl.model_skipped_small_data(m) = "NO";
            modelsTbl.skip_reason(m) = foldReason;
            continue;
        end

        if any(~isfinite(yhat))
            modelsTbl.model_skipped(m) = "YES";
            modelsTbl.model_skipped_small_data(m) = "NO";
            modelsTbl.skip_reason(m) = "LOOCV_NONFINITE_PRED";
            continue;
        end

        resid = y - yhat;
        modelsTbl.model_skipped(m) = "NO";
        modelsTbl.model_skipped_small_data(m) = "NO";
        modelsTbl.skip_reason(m) = "";
        modelsTbl.loocv_rmse(m) = sqrt(mean((y - yhat) .^ 2, 'omitnan'));
        modelsTbl.pearson_y_yhat(m) = corr(y, yhat, 'rows', 'complete');
        modelsTbl.spearman_y_yhat(m) = corr(y, yhat, 'type', 'Spearman', 'rows', 'complete');
        modelsTbl.mae_resid_22_24K(m) = mean(abs(resid(twinM)), 'omitnan');
        modelsTbl.mae_resid_outside_22_24K(m) = mean(abs(resid(mOtherM)), 'omitnan');

        modelsEvaluated = modelsEvaluated + 1;
    end

    % Stability success criteria.
    validMask = (modelsTbl.model_skipped == "NO") & isfinite(modelsTbl.loocv_rmse);
    nValidModels = nnz(validMask);

    idxBaseline = find(modelsTbl.model == baselineModelId, 1, 'first');
    if ~isempty(idxBaseline) && modelsTbl.model_skipped(idxBaseline) == "NO" && isfinite(modelsTbl.loocv_rmse(idxBaseline))
        baselineWorks = "YES";
    else
        baselineWorks = "NO";
    end

    if nValidModels >= 3
        minRequiredModelsMet = "YES";
    else
        minRequiredModelsMet = "NO";
    end

    if baselineWorks == "YES" && minRequiredModelsMet == "YES" && noCrash == "YES"
        executionStatus = "SUCCESS";
    else
        executionStatus = "FAIL";
    end

    if nValidModels > 0
        idxValid = find(validMask);
        [bestRmse, loc] = min(modelsTbl.loocv_rmse(validMask));
        bestModel = modelsTbl.model(idxValid(loc));
        mainResultSummary = "valid_models=" + string(nValidModels) + ", baseline_works=" + baselineWorks + ...
            ", best_model='" + bestModel + "', best_rmse=" + string(bestRmse);
    else
        mainResultSummary = "No valid models. Check skip_reason in alpha_observable_models.csv";
    end

catch ME
    noCrash = "NO";
    executionStatus = "FAIL";
    errorMessage = errorMessage + newline + string(getReport(ME, 'extended', 'hyperlinks', 'off'));
    if strlength(mainResultSummary) == 0 || mainResultSummary == "Pipeline did not complete."
        mainResultSummary = "Exception encountered before stable model evaluation.";
    end
end

% Always write models CSV.
try
    writetable(modelsTbl, modelsCsvPath);
    modelsWritten = "YES";
catch MEm
    modelsWritten = "NO";
    errorMessage = errorMessage + newline + "Models CSV write failed: " + string(MEm.message);
end

% Ensure debug CSV exists even if try-block failed before writing.
if debugWritten ~= "YES"
    try
        writetable(debugTbl, debugCsvPath);
        debugWritten = "YES";
    catch MEd2
        debugWritten = "NO";
        errorMessage = errorMessage + newline + "Debug CSV fallback write failed: " + string(MEd2.message);
    end
end

% Always write markdown report.
reportLines = {};
reportLines{end + 1} = '# Alpha Observable Modeling Search (Stable Pipeline)';
reportLines{end + 1} = '';
reportLines{end + 1} = sprintf('- Script: `%s`', strrep(thisFile, '\', '/'));
reportLines{end + 1} = sprintf('- Generated: `%s`', datestr(now, 31));
reportLines{end + 1} = '';
reportLines{end + 1} = '## Inputs (Canonical)';
reportLines{end + 1} = sprintf('- `%s`', strrep(barrierPath, '\', '/'));
reportLines{end + 1} = sprintf('- `%s`', strrep(alphaStructurePath, '\', '/'));
reportLines{end + 1} = sprintf('- `%s`', strrep(alphaDecompPath, '\', '/'));
reportLines{end + 1} = '';
reportLines{end + 1} = '## Pipeline Guards';
reportLines{end + 1} = '- Manual `T_K` alignment only (no `innerjoin`).';
reportLines{end + 1} = '- No interpolation / no artificial fill.';
reportLines{end + 1} = '- Per-model finite filtering (`X_raw -> mask -> X_model`).';
reportLines{end + 1} = '- `size(X_model,1) < 5` => model skipped.';
reportLines{end + 1} = '- Near-constant columns removed (`std < 1e-10`).';
reportLines{end + 1} = '- Safe regression uses `pinv` in LOOCV.';
reportLines{end + 1} = '';
reportLines{end + 1} = '## Stability Outcome';
reportLines{end + 1} = sprintf('- EXECUTION_STATUS: **%s**', char(executionStatus));
reportLines{end + 1} = sprintf('- BASELINE_WORKS: **%s**', char(baselineWorks));
reportLines{end + 1} = sprintf('- N_VALID_MODELS: `%d`', nValidModels);
reportLines{end + 1} = sprintf('- MAIN_RESULT_SUMMARY: `%s`', char(mainResultSummary));
reportLines{end + 1} = '';
reportLines{end + 1} = '## Artifacts';
reportLines{end + 1} = sprintf('- Debug table: `%s`', strrep(debugCsvPath, '\', '/'));
reportLines{end + 1} = sprintf('- Models table: `%s`', strrep(modelsCsvPath, '\', '/'));
reportLines{end + 1} = sprintf('- Status table: `%s`', strrep(statusCsvPath, '\', '/'));
reportLines{end + 1} = sprintf('- Report: `%s`', strrep(reportMdPath, '\', '/'));

if strlength(errorMessage) > 0
    reportLines{end + 1} = '';
    reportLines{end + 1} = '## Error Message';
    reportLines{end + 1} = '```';
    reportLines{end + 1} = char(errorMessage);
    reportLines{end + 1} = '```';
end

try
    fid = fopen(reportMdPath, 'w');
    if fid >= 0
        for i = 1:numel(reportLines)
            fprintf(fid, '%s\n', reportLines{i});
        end
        fclose(fid);
        reportWritten = "YES";
    else
        reportWritten = "NO";
        errorMessage = errorMessage + newline + "Report open failed.";
    end
catch MEr
    reportWritten = "NO";
    errorMessage = errorMessage + newline + "Report write failed: " + string(MEr.message);
end

% Always write status CSV last with final write flags.
statusTbl = table( ...
    string(executionStatus), ...
    string(inputFound), ...
    string(errorMessage), ...
    double(nT), ...
    string(mainResultSummary), ...
    string(baselineWorks), ...
    double(nValidModels), ...
    string(minRequiredModelsMet), ...
    string(noCrash), ...
    string(debugWritten), ...
    string(modelsWritten), ...
    string(reportWritten), ...
    'VariableNames', {'EXECUTION_STATUS','INPUT_FOUND','ERROR_MESSAGE','N_T','MAIN_RESULT_SUMMARY', ...
    'BASELINE_WORKS','N_VALID_MODELS','MIN_REQUIRED_MODELS_MET','NO_CRASH', ...
    'DEBUG_TABLE_WRITTEN','MODELS_TABLE_WRITTEN','REPORT_WRITTEN'});

try
    writetable(statusTbl, statusCsvPath);
    statusWritten = "YES";
catch MEs
    statusWritten = "NO";
    fid2 = fopen(reportMdPath, 'a');
    if fid2 >= 0
        fprintf(fid2, '\n## Status Write Failure\n');
        fprintf(fid2, '\n`%s`\n', char(string(MEs.message)));
        fclose(fid2);
    end
end


