clear; clc;
% RUN_WIDTH_DECOMPOSITION_TEST
% Decompose switching width into PT + collective contribution using manual
% temperature alignment and LOOCV model comparison.
%
% Inputs (repo-root relative):
%   tables/alpha_structure.csv   -> w(T) = width_mA
%   tables/alpha_from_PT.csv     -> w_PT(T) = std_threshold_mA_PT
%   tables/kappa1_from_PT_aligned.csv -> kappa1(T)
%
% Outputs (repo root):
%   tables/width_decomposition_models.csv
%   reports/width_decomposition.md
%   tables/width_decomposition_status.csv
%
% NOTE: This script is intended to run via eval(fileread(abs_path)).
% Keep it as a pure MATLAB script (no local function definitions).

repoRoot = pwd;
thisFile = fullfile(repoRoot, 'Switching', 'analysis', 'run_width_decomposition_test.m');

widthPath = fullfile(repoRoot, 'tables', 'alpha_structure.csv');
ptPath = fullfile(repoRoot, 'tables', 'alpha_from_PT.csv');
kappa1Path = fullfile(repoRoot, 'tables', 'kappa1_from_PT_aligned.csv');

tablesDir = fullfile(repoRoot, 'tables');
reportsDir = fullfile(repoRoot, 'reports');
if exist(tablesDir, 'dir') ~= 7
    mkdir(tablesDir);
end
if exist(reportsDir, 'dir') ~= 7
    mkdir(reportsDir);
end

modelsCsvPath = fullfile(tablesDir, 'width_decomposition_models.csv');
statusCsvPath = fullfile(tablesDir, 'width_decomposition_status.csv');
reportMdPath = fullfile(reportsDir, 'width_decomposition.md');

modelNames = string(["delta_w ~ kappa1"; "delta_w ~ PT"; "delta_w ~ kappa1 + PT"]);
nModels = numel(modelNames);

modelsTbl = table();
modelsTbl.model = modelNames;
modelsTbl.n_rows_used = zeros(nModels, 1);
modelsTbl.loocv_rmse = nan(nModels, 1);
modelsTbl.pearson_y_yhat = nan(nModels, 1);
modelsTbl.spearman_y_yhat = nan(nModels, 1);
modelsTbl.delta_rmse_vs_delta_const = nan(nModels, 1);
modelsTbl.target_mean = nan(nModels, 1);

WIDTH_HAS_PT_COMPONENT = "NO";
WIDTH_HAS_COLLECTIVE_COMPONENT = "NO";
WIDTH_DECOMPOSITION_PHYSICALLY_MEANINGFUL = "NO";

nRowsUsed = 0;
alignedTemps = [];

rmse_w_const = NaN;
rmse_w_PT = NaN;
corr_w_wPT = NaN;
rmse_delta_const = NaN;
rmse_delta_kappa1 = NaN;
rmse_delta_PT = NaN;
rmse_delta_combined = NaN;
corr_delta_kappa1 = NaN;
corr_delta_PT = NaN;
corr_delta_combined_model = NaN;

analysisOK = "NO";
analysisMessage = "NOT_RUN";

try
    assert(isfile(widthPath), 'Missing width table: %s', widthPath);
    assert(isfile(ptPath), 'Missing PT proxy table: %s', ptPath);
    assert(isfile(kappa1Path), 'Missing kappa1 table: %s', kappa1Path);

    widthTbl = readtable(widthPath, 'VariableNamingRule', 'preserve');
    ptTbl = readtable(ptPath, 'VariableNamingRule', 'preserve');
    kappa1Tbl = readtable(kappa1Path, 'VariableNamingRule', 'preserve');

    assert(all(ismember({'T_K', 'width_mA', 'kappa1'}, widthTbl.Properties.VariableNames)), ...
        'Width table must contain T_K, width_mA, kappa1: %s', widthPath);
    assert(all(ismember({'T_K', 'std_threshold_mA_PT'}, ptTbl.Properties.VariableNames)), ...
        'PT table must contain T_K, std_threshold_mA_PT: %s', ptPath);
    assert(all(ismember({'T_K', 'kappa1'}, kappa1Tbl.Properties.VariableNames)), ...
        'kappa1 table must contain T_K, kappa1: %s', kappa1Path);

    T_width = double(widthTbl.T_K(:));
    w_source = double(widthTbl.width_mA(:));

    T_pt = double(ptTbl.T_K(:));
    wPT_source = double(ptTbl.std_threshold_mA_PT(:));

    T_k1 = double(kappa1Tbl.T_K(:));
    k1_source = double(kappa1Tbl.kappa1(:));

    m = isfinite(T_width);
    T_width = T_width(m);
    w_source = w_source(m);
    [T_width, ord] = sort(T_width);
    w_source = w_source(ord);

    m = isfinite(T_pt);
    T_pt = T_pt(m);
    wPT_source = wPT_source(m);
    [T_pt, ord] = sort(T_pt);
    wPT_source = wPT_source(ord);

    m = isfinite(T_k1);
    T_k1 = T_k1(m);
    k1_source = k1_source(m);
    [T_k1, ord] = sort(T_k1);
    k1_source = k1_source(ord);

    tTol = 1e-9;
    for i = 2:numel(T_width)
        if abs(T_width(i) - T_width(i - 1)) <= tTol
            error('Duplicate T_K in width table near T=%.12g', T_width(i));
        end
    end
    for i = 2:numel(T_pt)
        if abs(T_pt(i) - T_pt(i - 1)) <= tTol
            error('Duplicate T_K in PT table near T=%.12g', T_pt(i));
        end
    end
    for i = 2:numel(T_k1)
        if abs(T_k1(i) - T_k1(i - 1)) <= tTol
            error('Duplicate T_K in kappa1 table near T=%.12g', T_k1(i));
        end
    end

    % Manual alignment by explicit per-temperature lookup.
    alignedTemps = [];
    w = [];
    w_PT = [];
    kappa1 = [];

    for i = 1:numel(T_width)
        Ti = T_width(i);
        idxPT = find(abs(T_pt - Ti) <= tTol);
        idxK1 = find(abs(T_k1 - Ti) <= tTol);

        if numel(idxPT) > 1
            error('Ambiguous PT match for T=%.12g (multiple rows).', Ti);
        end
        if numel(idxK1) > 1
            error('Ambiguous kappa1 match for T=%.12g (multiple rows).', Ti);
        end
        if isempty(idxPT) || isempty(idxK1)
            continue;
        end

        wi = w_source(i);
        wpti = wPT_source(idxPT);
        k1i = k1_source(idxK1);

        if isfinite(wi) && isfinite(wpti) && isfinite(k1i)
            alignedTemps(end + 1, 1) = Ti; %#ok<AGROW>
            w(end + 1, 1) = wi; %#ok<AGROW>
            w_PT(end + 1, 1) = wpti; %#ok<AGROW>
            kappa1(end + 1, 1) = k1i; %#ok<AGROW>
        end
    end

    n = numel(alignedTemps);
    nRowsUsed = n;
    assert(n >= 4, 'Need at least 4 aligned finite rows. Got n=%d.', n);

    delta_w = w - w_PT;

    % Baseline for delta_w: LOOCV constant mean.
    y = delta_w;
    yhat_delta_const = nan(n, 1);
    for i = 1:n
        mask = true(n, 1);
        mask(i) = false;
        yhat_delta_const(i) = mean(y(mask), 'omitnan');
    end
    rmse_delta_const = sqrt(mean((y - yhat_delta_const) .^ 2, 'omitnan'));

    predictors = cell(nModels, 1);
    predictors{1} = kappa1;
    predictors{2} = w_PT;
    predictors{3} = [kappa1, w_PT];

    for mIdx = 1:nModels
        X = double(predictors{mIdx});
        p = size(X, 2);

        yhat = nan(n, 1);
        for i = 1:n
            mask = true(n, 1);
            mask(i) = false;

            Xi = X(mask, :);
            yi = y(mask);

            finiteTrain = all(isfinite(Xi), 2) & isfinite(yi);
            Xi = Xi(finiteTrain, :);
            yi = yi(finiteTrain);

            if numel(yi) < p + 1
                continue;
            end

            Z = [ones(numel(yi), 1), Xi];
            if rank(Z) < size(Z, 2)
                beta = pinv(Z) * yi;
            else
                beta = Z \ yi;
            end

            xTest = X(i, :);
            if any(~isfinite(xTest))
                continue;
            end
            yhat(i) = [1, xTest] * beta;
        end

        modelsTbl.n_rows_used(mIdx) = n;
        modelsTbl.loocv_rmse(mIdx) = sqrt(mean((y - yhat) .^ 2, 'omitnan'));
        modelsTbl.pearson_y_yhat(mIdx) = corr(y, yhat, 'rows', 'complete');
        modelsTbl.spearman_y_yhat(mIdx) = corr(y, yhat, 'type', 'Spearman', 'rows', 'complete');
        modelsTbl.delta_rmse_vs_delta_const(mIdx) = modelsTbl.loocv_rmse(mIdx) - rmse_delta_const;
        modelsTbl.target_mean(mIdx) = mean(y, 'omitnan');
    end

    rmse_delta_kappa1 = modelsTbl.loocv_rmse(1);
    rmse_delta_PT = modelsTbl.loocv_rmse(2);
    rmse_delta_combined = modelsTbl.loocv_rmse(3);

    corr_delta_kappa1 = corr(delta_w, kappa1, 'rows', 'complete');
    corr_delta_PT = corr(delta_w, w_PT, 'rows', 'complete');
    corr_delta_combined_model = modelsTbl.pearson_y_yhat(3);

    % PT component test on full width: w ~ PT (LOOCV), vs constant baseline.
    yW = w;
    yhat_w_const = nan(n, 1);
    for i = 1:n
        mask = true(n, 1);
        mask(i) = false;
        yhat_w_const(i) = mean(yW(mask), 'omitnan');
    end
    rmse_w_const = sqrt(mean((yW - yhat_w_const) .^ 2, 'omitnan'));

    yhat_w_PT = nan(n, 1);
    for i = 1:n
        mask = true(n, 1);
        mask(i) = false;

        Xtr = w_PT(mask);
        ytr = yW(mask);
        finiteTrain = isfinite(Xtr) & isfinite(ytr);
        Xtr = Xtr(finiteTrain);
        ytr = ytr(finiteTrain);

        if numel(ytr) < 2
            continue;
        end

        Ztr = [ones(numel(ytr), 1), Xtr];
        if rank(Ztr) < size(Ztr, 2)
            beta = pinv(Ztr) * ytr;
        else
            beta = Ztr \ ytr;
        end

        xt = w_PT(i);
        if ~isfinite(xt)
            continue;
        end
        yhat_w_PT(i) = [1, xt] * beta;
    end
    rmse_w_PT = sqrt(mean((yW - yhat_w_PT) .^ 2, 'omitnan'));
    corr_w_wPT = corr(w, w_PT, 'rows', 'complete');

    tol = 1e-12;

    hasPT = isfinite(rmse_w_PT) && isfinite(rmse_w_const) && ...
        (rmse_w_PT < rmse_w_const - tol) && isfinite(corr_w_wPT);

    hasCollective = isfinite(rmse_delta_kappa1) && isfinite(rmse_delta_const) && ...
        (rmse_delta_kappa1 < rmse_delta_const - tol) && isfinite(corr_delta_kappa1);

    combinedBest = isfinite(rmse_delta_combined) && isfinite(rmse_delta_kappa1) && ...
        isfinite(rmse_delta_PT) && (rmse_delta_combined < min(rmse_delta_kappa1, rmse_delta_PT) - tol);

    meaningful = hasPT && hasCollective && combinedBest;

    if hasPT
        WIDTH_HAS_PT_COMPONENT = "YES";
    else
        WIDTH_HAS_PT_COMPONENT = "NO";
    end

    if hasCollective
        WIDTH_HAS_COLLECTIVE_COMPONENT = "YES";
    else
        WIDTH_HAS_COLLECTIVE_COMPONENT = "NO";
    end

    if meaningful
        WIDTH_DECOMPOSITION_PHYSICALLY_MEANINGFUL = "YES";
    else
        WIDTH_DECOMPOSITION_PHYSICALLY_MEANINGFUL = "NO";
    end

    analysisOK = "YES";
    analysisMessage = "OK";

catch ME
    analysisOK = "NO";
    analysisMessage = string(getReport(ME, 'extended', 'hyperlinks', 'off'));
end

alignedTempsStr = "[]";
if ~isempty(alignedTemps)
    alignedTempsStr = string(mat2str(alignedTemps(:)', 6));
end

statusTbl = table( ...
    string(WIDTH_HAS_PT_COMPONENT), ...
    string(WIDTH_HAS_COLLECTIVE_COMPONENT), ...
    string(WIDTH_DECOMPOSITION_PHYSICALLY_MEANINGFUL), ...
    nRowsUsed, ...
    rmse_w_const, ...
    rmse_w_PT, ...
    corr_w_wPT, ...
    rmse_delta_const, ...
    rmse_delta_kappa1, ...
    rmse_delta_PT, ...
    rmse_delta_combined, ...
    corr_delta_kappa1, ...
    corr_delta_PT, ...
    corr_delta_combined_model, ...
    string(analysisOK), ...
    string(analysisMessage), ...
    string(widthPath), ...
    string(ptPath), ...
    string(kappa1Path), ...
    string(alignedTempsStr), ...
    'VariableNames', { ...
    'WIDTH_HAS_PT_COMPONENT', ...
    'WIDTH_HAS_COLLECTIVE_COMPONENT', ...
    'WIDTH_DECOMPOSITION_PHYSICALLY_MEANINGFUL', ...
    'n_rows_used', ...
    'rmse_w_constant_loocv', ...
    'rmse_w_PT_loocv', ...
    'corr_w_wPT', ...
    'rmse_delta_w_constant_loocv', ...
    'rmse_delta_w_kappa1_loocv', ...
    'rmse_delta_w_PT_loocv', ...
    'rmse_delta_w_combined_loocv', ...
    'corr_delta_w_kappa1', ...
    'corr_delta_w_PT', ...
    'corr_delta_w_yhat_combined', ...
    'analysis_ok', ...
    'analysis_message', ...
    'source_width_path', ...
    'source_pt_proxy_path', ...
    'source_kappa1_path', ...
    'aligned_temperatures_K'});

writetable(modelsTbl, modelsCsvPath);
writetable(statusTbl, statusCsvPath);

lines = {};
lines{end + 1} = '# Width decomposition: PT + collective';
lines{end + 1} = '';
lines{end + 1} = sprintf('**Run script:** `%s`', strrep(thisFile, '\\', '/'));
lines{end + 1} = sprintf('**Date:** %s', datestr(now, 31));
lines{end + 1} = '';
lines{end + 1} = '## Inputs';
lines{end + 1} = sprintf('- `w(T)` source: `%s` (columns `T_K`, `width_mA`)', strrep(widthPath, '\\', '/'));
lines{end + 1} = sprintf('- `w_PT(T)` source: `%s` (column `std_threshold_mA_PT`)', strrep(ptPath, '\\', '/'));
lines{end + 1} = sprintf('- `kappa1(T)` source: `%s` (column `kappa1`)', strrep(kappa1Path, '\\', '/'));
lines{end + 1} = '';
lines{end + 1} = '## Alignment and decomposition';
lines{end + 1} = '- Manual alignment by temperature (`T_K`) with exact lookup tolerance 1e-9 K.';
lines{end + 1} = '- Decomposition used: `delta_w(T) = w(T) - w_PT(T)`.';
lines{end + 1} = sprintf('- Aligned finite rows: n = %d', nRowsUsed);
lines{end + 1} = sprintf('- Aligned temperatures (K): `%s`', char(alignedTempsStr));
lines{end + 1} = '';
lines{end + 1} = '## LOOCV models for `delta_w`';
lines{end + 1} = '| Model | LOOCV RMSE | Pearson(y,yhat) | Spearman(y,yhat) | RMSE - baseline |';
lines{end + 1} = '|---|---:|---:|---:|---:|';
for i = 1:height(modelsTbl)
    lines{end + 1} = sprintf('| %s | %.6g | %.6g | %.6g | %.6g |', ...
        char(modelsTbl.model(i)), modelsTbl.loocv_rmse(i), modelsTbl.pearson_y_yhat(i), ...
        modelsTbl.spearman_y_yhat(i), modelsTbl.delta_rmse_vs_delta_const(i));
end
lines{end + 1} = '';
lines{end + 1} = '## Component checks';
lines{end + 1} = sprintf('- Width PT check: rmse(w~const)=%.6g, rmse(w~PT)=%.6g, corr(w,w_PT)=%.6g', ...
    rmse_w_const, rmse_w_PT, corr_w_wPT);
lines{end + 1} = sprintf('- Residual collective check: rmse(delta_w~const)=%.6g, rmse(delta_w~kappa1)=%.6g, corr(delta_w,kappa1)=%.6g', ...
    rmse_delta_const, rmse_delta_kappa1, corr_delta_kappa1);
lines{end + 1} = sprintf('- Residual PT coupling: rmse(delta_w~PT)=%.6g, corr(delta_w,PT)=%.6g', ...
    rmse_delta_PT, corr_delta_PT);
lines{end + 1} = sprintf('- Combined residual model: rmse(delta_w~kappa1+PT)=%.6g, corr(delta_w,yhat)=%.6g', ...
    rmse_delta_combined, corr_delta_combined_model);
lines{end + 1} = '';
lines{end + 1} = '## Verdicts';
lines{end + 1} = sprintf('- **WIDTH_HAS_PT_COMPONENT:** **%s**', char(WIDTH_HAS_PT_COMPONENT));
lines{end + 1} = sprintf('- **WIDTH_HAS_COLLECTIVE_COMPONENT:** **%s**', char(WIDTH_HAS_COLLECTIVE_COMPONENT));
lines{end + 1} = sprintf('- **WIDTH_DECOMPOSITION_PHYSICALLY_MEANINGFUL:** **%s**', char(WIDTH_DECOMPOSITION_PHYSICALLY_MEANINGFUL));
lines{end + 1} = '';
lines{end + 1} = '## Output files';
lines{end + 1} = sprintf('- `%s`', strrep(modelsCsvPath, '\\', '/'));
lines{end + 1} = sprintf('- `%s`', strrep(reportMdPath, '\\', '/'));
lines{end + 1} = sprintf('- `%s`', strrep(statusCsvPath, '\\', '/'));
lines{end + 1} = '';
lines{end + 1} = sprintf('**Analysis status:** `%s`', char(analysisOK));
if analysisOK == "NO"
    lines{end + 1} = '';
    lines{end + 1} = '### Error';
    lines{end + 1} = char(analysisMessage);
end

fid = fopen(reportMdPath, 'w', 'n', 'UTF-8');
if fid == -1
    error('Could not open report for writing: %s', reportMdPath);
end
for i = 1:numel(lines)
    fprintf(fid, '%s\n', lines{i});
end
fclose(fid);

fprintf('Wrote models CSV: %s\n', modelsCsvPath);
fprintf('Wrote report MD: %s\n', reportMdPath);
fprintf('Wrote status CSV: %s\n', statusCsvPath);
