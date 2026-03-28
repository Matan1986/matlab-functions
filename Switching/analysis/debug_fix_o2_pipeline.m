% debug_fix_o2_pipeline
% Fix and verify the O2 observable pipeline:
%  - compute antisymmetric_integral, slope_difference, local_curvature_window
%  - save raw + aligned tables
%  - manual T_K alignment (no innerjoin)
%  - hard validation + minimal regression sanity check

repoRoot = 'C:/Dev/matlab-functions';

outRawCsvPath = fullfile(repoRoot, 'tables', 'o2_observables_raw.csv');
outAlignedCsvPath = fullfile(repoRoot, 'tables', 'o2_observables_aligned.csv');
outStatusCsvPath = fullfile(repoRoot, 'tables', 'o2_pipeline_status.csv');
outReportMdPath = fullfile(repoRoot, 'reports', 'o2_pipeline_debug.md');

requiredO2Vars = {'antisymmetric_integral', 'slope_difference', 'local_curvature_window'};

executionStatus = "FAIL";
O2_COMPUTED = "NO";
O2_ALIGNED = "NO";
O2_AVAILABLE_FOR_MODELING = "NO";
N_VALID_POINTS = 0;
ANY_COLUMN_MISSING = "NO";
ANY_COLUMN_ALL_NAN = "NO";
O2_PIPELINE_FIXED = "NO";
O2_READY_FOR_CLOSURE_TEST = "NO";
errorText = "";

% Ensure output directories exist.
outRawDir = fileparts(outRawCsvPath);
outAlignedDir = fileparts(outAlignedCsvPath);
outStatusDir = fileparts(outStatusCsvPath);
outReportDir = fileparts(outReportMdPath);
if exist(outRawDir, 'dir') ~= 7, mkdir(outRawDir); end
if exist(outAlignedDir, 'dir') ~= 7, mkdir(outAlignedDir); end
if exist(outStatusDir, 'dir') ~= 7, mkdir(outStatusDir); end
if exist(outReportDir, 'dir') ~= 7, mkdir(outReportDir); end

T_o2 = table();
T_aligned = table();

try
    % --------------------------
    % Step 1 — Locate source data
    % --------------------------
    runsRoot = fullfile(repoRoot, 'results', 'switching', 'runs');
    if exist(runsRoot, 'dir') ~= 7
        error('debug_fix_o2_pipeline:MissingRunsRoot', 'Missing runs root: %s', runsRoot);
    end

    runDirs = dir(fullfile(runsRoot, 'run_*'));
    runDirs = runDirs([runDirs.isdir]);

    % Sort by datenum desc (latest first).
    [~, ord] = sort([runDirs.datenum], 'descend');
    runDirs = runDirs(ord);

    alignmentRunId = "";
    fullScalingRunId = "";

    % Locate latest alignment run containing `switching_alignment_core_data.mat`.
    for i = 1:numel(runDirs)
        candAlignmentRunId = string(runDirs(i).name);
        candAlignmentCorePath = fullfile(runsRoot, candAlignmentRunId, 'switching_alignment_core_data.mat');
        if exist(candAlignmentCorePath, 'file') == 2
            alignmentRunId = candAlignmentRunId;
            break;
        end
    end

    % Locate latest full-scaling run containing `switching_full_scaling_parameters.csv`.
    for i = 1:numel(runDirs)
        candFullScalingRunId = string(runDirs(i).name);
        candScalingParamsPath = fullfile(runsRoot, candFullScalingRunId, 'tables', 'switching_full_scaling_parameters.csv');
        if exist(candScalingParamsPath, 'file') == 2
            fullScalingRunId = candFullScalingRunId;
            break;
        end
    end

    if strlength(string(alignmentRunId)) == 0 || strlength(string(fullScalingRunId)) == 0
        error('debug_fix_o2_pipeline:MissingSourceMap', ...
            'Could not locate alignment core map + scaling parameters (need both %s and %s).', ...
            'switching_alignment_core_data.mat', 'switching_full_scaling_parameters.csv');
    end

    % Kappa table (kappa1, kappa2 vs T_K).
    % Prefer repository-level table if present.
    kappaTablePreferred = fullfile(repoRoot, 'tables', 'closure_metrics_per_temperature.csv');
    kappaTablePath = "";
    if exist(kappaTablePreferred, 'file') == 2
        kappaTablePath = kappaTablePreferred;
    else
        % Otherwise pick the latest under results.
        kappaTablePath = "";
        for i = 1:numel(runDirs)
            candRunId = string(runDirs(i).name);
            candPath = fullfile(runsRoot, candRunId, 'tables', 'closure_metrics_per_temperature.csv');
            if exist(candPath, 'file') == 2
                kappaTablePath = candPath;
                break;
            end
        end
        if strlength(string(kappaTablePath)) == 0
            error('debug_fix_o2_pipeline:MissingKappaTable', 'Missing kappa table: %s', kappaTablePreferred);
        end
    end

    % --------------------------
    % Step 2 — Compute O2 observables explicitly
    % --------------------------
    % We compute deltaS(x,T) from the switching map using the existing residual decomposition machinery.
    % Then we compute O2 directly from deltaS(x,T) using the specified formulas.
    addpath(genpath(repoRoot));

    decCfg = struct();
    decCfg.runLabel = "o2_pipeline_debug_decomposition";
    decCfg.alignmentRunId = char(alignmentRunId);
    decCfg.fullScalingRunId = char(fullScalingRunId);
    decCfg.ptRunId = ""; % allow decomposition to pick latest PT matrix; fallback is handled inside
    decCfg.canonicalMaxTemperatureK = 30;
    decCfg.nXGrid = 220;
    decCfg.maxModes = 2;
    decCfg.skipFigures = true;
    outDec = switching_residual_decomposition_analysis(decCfg);

    if ~isfield(outDec, 'xGrid') || ~isfield(outDec, 'Rall') || ~isfield(outDec, 'temperaturesK')
        error('debug_fix_o2_pipeline:DecompositionOutputMissing', ...
            'Decomposition output missing xGrid/Rall/temperaturesK.');
    end

    xGrid = double(outDec.xGrid(:));
    Rall = double(outDec.Rall);
    T_all = double(outDec.temperaturesK(:));

    if size(Rall, 1) ~= numel(T_all)
        error('debug_fix_o2_pipeline:ShapeMismatch', ...
            'Rall rows (%d) do not match temperaturesK (%d).', size(Rall, 1), numel(T_all));
    end

    % Choose curvature / slope windows in x = (I-Ipeak)/w units.
    xMaxAbs = max(abs(xGrid), [], 'omitnan');
    if ~(isfinite(xMaxAbs) && xMaxAbs > 0)
        xMaxAbs = 1;
    end
    x0Curv = min(0.25, 0.4 * xMaxAbs);
    xHalfSlope = min(0.15, 0.4 * xMaxAbs);

    signx = sign(xGrid);
    signx(~isfinite(signx)) = 0;

    nT = numel(T_all);
    antisymmetric_integral = NaN(nT, 1);
    slope_difference = NaN(nT, 1);
    local_curvature_window = NaN(nT, 1);

    for it = 1:nT
        deltaCol = Rall(it, :).';
        if all(~isfinite(deltaCol))
            continue;
        end

        % 1) antisymmetric_integral = ∫ sign(x) * ΔS(x) dx
        antisymmetric_integral(it) = trapz(xGrid, signx .* deltaCol);

        % 2) slope_difference = slope(right of peak) - slope(left of peak)
        maskLeft = (xGrid < 0) & (xGrid >= -xHalfSlope);
        maskRight = (xGrid > 0) & (xGrid <= xHalfSlope);
        if nnz(maskLeft) >= 2 && nnz(maskRight) >= 2
            pL = polyfit(xGrid(maskLeft), deltaCol(maskLeft), 1);
            pR = polyfit(xGrid(maskRight), deltaCol(maskRight), 1);
            slopeLeft = pL(1);
            slopeRight = pR(1);
            slope_difference(it) = slopeRight - slopeLeft;
        else
            slope_difference(it) = NaN;
        end

        % 3) local_curvature_window = mean(d2/dx2) over |x| < x0
        % Use numerical differentiation along xGrid.
        d1 = gradient(deltaCol, xGrid);
        d2 = gradient(d1, xGrid);
        maskCurv = abs(xGrid) < x0Curv;
        if nnz(maskCurv) >= 3
            local_curvature_window(it) = mean(d2(maskCurv), 'omitnan');
        else
            local_curvature_window(it) = NaN;
        end
    end

    T_o2 = table( ...
        T_all, ...
        antisymmetric_integral, ...
        slope_difference, ...
        local_curvature_window, ...
        'VariableNames', {'T_K', 'antisymmetric_integral', 'slope_difference', 'local_curvature_window'});

    writetable(T_o2, outRawCsvPath);

    O2_COMPUTED = "YES";

    % --------------------------
    % Step 3 — Hard validation (CRITICAL)
    % --------------------------
    disp('O2 RAW TABLE COLUMNS:')
    disp(T_o2.Properties.VariableNames)
    disp('Number of valid rows:')
    disp(sum(all(~ismissing(T_o2),2)))

    % If raw table is empty or all NaN in all O2 columns, fail.
    if height(T_o2) == 0
        error('debug_fix_o2_pipeline:EmptyO2Raw', 'Computed O2 raw table is empty.');
    end
    validRaw = all(isfinite(T_o2{:, requiredO2Vars}), 2);
    if nnz(validRaw) == 0
        error('debug_fix_o2_pipeline:O2RawAllNaN', 'All O2 rows are NaN in computed raw table.');
    end

    % --------------------------
    % Step 4 — Align with kappa table
    % --------------------------
    T_k = readtable(kappaTablePath, 'VariableNamingRule', 'preserve');
    vnK = string(T_k.Properties.VariableNames);

    % Detect T_K column.
    tIdx = find(contains(lower(vnK), lower('T_K')), 1, 'first');
    if isempty(tIdx)
        tIdx = find(contains(lower(vnK), 't') & contains(lower(vnK), 'k'), 1, 'first');
    end
    if isempty(tIdx)
        % Fallback: exact 'T'
        tIdx = find(vnK == "T", 1, 'first');
    end
    if isempty(tIdx)
        error('debug_fix_o2_pipeline:KappaTableMissingT', 'Could not detect temperature column (T_K/T).');
    end
    T_k_T = double(T_k.(vnK(tIdx))(:));

    % Detect kappa2 column via contains().
    k2Cands = vnK(contains(lower(vnK), 'kappa2'));
    if isempty(k2Cands)
        error('debug_fix_o2_pipeline:KappaTableMissingKappa2', 'Could not detect kappa2 column in kappa table.');
    end
    % Prefer the "M3" variant if present.
    k2Pick = k2Cands(contains(lower(k2Cands), 'm3'));
    if isempty(k2Pick)
        k2Pick = k2Cands(1);
    else
        k2Pick = k2Pick(1);
    end
    kappa2 = double(T_k.(k2Pick)(:));

    % Detect kappa1 column (optional for regression; keep for completeness).
    k1Cands = vnK(contains(lower(vnK), 'kappa1'));
    if isempty(k1Cands)
        kappa1 = NaN(size(kappa2));
        k1Pick = "";
    else
        k1Pick = k1Cands(contains(lower(k1Cands), 'm2'));
        if isempty(k1Pick)
            k1Pick = k1Cands(1);
        else
            k1Pick = k1Pick(1);
        end
        kappa1 = double(T_k.(k1Pick)(:));
    end

    T_k_T = T_k_T(:);
    kappa2 = kappa2(:);
    if ~isempty(k1Pick)
        kappa1 = kappa1(:);
    end

    % Manual align on intersect of T_K values.
    T_common = intersect(T_o2.T_K(:), T_k_T(:), 'stable');
    T_common = T_common(isfinite(T_common));
    if isempty(T_common) || numel(T_common) < 4
        error('debug_fix_o2_pipeline:TooFewAlignedPoints', 'Too few common T_K values: %d', numel(T_common));
    end

    T_aligned = table(T_common, 'VariableNames', {'T_K'});

    [~, locO2] = ismember(T_common, T_o2.T_K);
    for j = 1:numel(requiredO2Vars)
        v = requiredO2Vars{j};
        T_aligned.(v) = double(T_o2.(v)(locO2));
    end

    [~, locK] = ismember(T_common, T_k_T);
    T_aligned.kappa2 = double(kappa2(locK));
    T_aligned.kappa1 = double(kappa1(locK));

    writetable(T_aligned, outAlignedCsvPath);
    O2_ALIGNED = "YES";

    % --------------------------
    % Step 5 — Post-alignment validation (CRITICAL)
    % --------------------------
    disp('ALIGNED TABLE COLUMNS:')
    disp(T_aligned.Properties.VariableNames)

    disp('NaN counts per column:')
    for i = 1:numel(T_aligned.Properties.VariableNames)
        col = T_aligned{:, i};
        fprintf('%s: %d NaNs\n', T_aligned.Properties.VariableNames{i}, sum(isnan(col)));
    end

    % --------------------------
    % Step 6 — Guarantee availability
    % --------------------------
    missingAny = false;
    allNaNAny = false;
    for j = 1:numel(requiredO2Vars)
        v = requiredO2Vars{j};
        if ~any(strcmp(T_aligned.Properties.VariableNames, v))
            missingAny = true;
            continue;
        end
        col = T_aligned.(v);
        if all(~isfinite(col))
            allNaNAny = true;
        end
    end
    if missingAny
        ANY_COLUMN_MISSING = "YES";
    end
    if allNaNAny
        ANY_COLUMN_ALL_NAN = "YES";
    end

    validModel = isfinite(T_aligned.kappa2) & isfinite(T_aligned.antisymmetric_integral);
    % Additionally require all O2 vars finite for "usable" modeling.
    for j = 1:numel(requiredO2Vars)
        validModel = validModel & isfinite(T_aligned.(requiredO2Vars{j}));
    end
    N_VALID_POINTS = nnz(validModel);

    if ANY_COLUMN_MISSING == "NO" && ANY_COLUMN_ALL_NAN == "NO" && N_VALID_POINTS > 0
        O2_AVAILABLE_FOR_MODELING = "YES";
    end

    % --------------------------
    % Step 7 — Minimal sanity test
    % --------------------------
    if ANY_COLUMN_MISSING == "YES" || ANY_COLUMN_ALL_NAN == "YES" || N_VALID_POINTS <= 0
        % Explicit FAIL condition: O2 columns are present but not usable.
        error('debug_fix_o2_pipeline:O2NotUsable', 'O2 observables not usable for modeling (missing or all-NaN).');
    end

    if O2_AVAILABLE_FOR_MODELING == "YES"
        x = T_aligned.antisymmetric_integral(validModel);
        y = T_aligned.kappa2(validModel);

        n = numel(x);
        if n < 4
            error('debug_fix_o2_pipeline:TooFewForRegression', 'Need >=4 valid points for regression; got %d', n);
        end

        % LOOCV for linear regression with intercept: y ~ a + b*x
        yhat = NaN(n, 1);
        for i = 1:n
            tr = true(n, 1);
            tr(i) = false;
            Xtr = [ones(nnz(tr), 1), x(tr)];
            b = Xtr \ y(tr);
            yhat(i) = [1, x(i)] * b;
        end

        pearsonR = corr(y, yhat, 'Rows', 'complete', 'Type', 'Pearson');
        loocvRmse = sqrt(mean((y - yhat).^2, 'omitnan'));

        % Required verdicts for status file.
        O2_PIPELINE_FIXED = "YES";
        if N_VALID_POINTS >= 6
            O2_READY_FOR_CLOSURE_TEST = "YES";
        end
    else
        O2_PIPELINE_FIXED = "NO";
        O2_READY_FOR_CLOSURE_TEST = "NO";
        pearsonR = NaN;
        loocvRmse = NaN;
    end

catch ME
    errorText = string(getReport(ME));

    executionStatus = "FAIL";
    O2_COMPUTED = "NO";
    O2_ALIGNED = "NO";
    O2_AVAILABLE_FOR_MODELING = "NO";
    ANY_COLUMN_MISSING = "YES";
    ANY_COLUMN_ALL_NAN = "YES";
    O2_PIPELINE_FIXED = "NO";
    O2_READY_FOR_CLOSURE_TEST = "NO";

    % ALWAYS write outputs even on failure.
    % Raw table (correct schema, may be empty).
    if isempty(T_o2) || ~istable(T_o2)
        T_o2 = table( ...
            NaN(0, 1), NaN(0, 1), NaN(0, 1), NaN(0, 1), ...
            'VariableNames', {'T_K', 'antisymmetric_integral', 'slope_difference', 'local_curvature_window'});
    end
    try
        writetable(T_o2, outRawCsvPath);
    catch
        % ignore write errors (best effort)
    end

    % Aligned table (correct schema, may be empty).
    if isempty(T_aligned) || ~istable(T_aligned)
        T_aligned = table();
        T_aligned.T_K = NaN(0, 1);
        for j = 1:numel(requiredO2Vars)
            T_aligned.(requiredO2Vars{j}) = NaN(0, 1);
        end
        T_aligned.kappa2 = NaN(0, 1);
        T_aligned.kappa1 = NaN(0, 1);
    end
    try
        writetable(T_aligned, outAlignedCsvPath);
    catch
        % ignore write errors (best effort)
    end
end

% Execution status set after try/catch.
if executionStatus == "FAIL"
    % If we reached this point without errorText being populated by catch, mark success.
    if strlength(errorText) == 0 && ~isempty(T_o2) && istable(T_o2) && height(T_o2) > 0
        executionStatus = "SUCCESS";
    end
end

% --------------------------
% Write status CSV (MANDATORY)
% --------------------------
statusTbl = table( ...
    string(executionStatus), ...
    string(O2_COMPUTED), ...
    string(O2_ALIGNED), ...
    string(O2_AVAILABLE_FOR_MODELING), ...
    double(N_VALID_POINTS), ...
    string(ANY_COLUMN_MISSING), ...
    string(ANY_COLUMN_ALL_NAN), ...
    string(O2_PIPELINE_FIXED), ...
    string(O2_READY_FOR_CLOSURE_TEST), ...
    string(errorText), ...
    'VariableNames', { ...
        'EXECUTION_STATUS', ...
        'O2_COMPUTED', ...
        'O2_ALIGNED', ...
        'O2_AVAILABLE_FOR_MODELING', ...
        'N_VALID_POINTS', ...
        'ANY_COLUMN_MISSING', ...
        'ANY_COLUMN_ALL_NAN', ...
        'O2_PIPELINE_FIXED', ...
        'O2_READY_FOR_CLOSURE_TEST', ...
        'ERROR_TEXT'} );
writetable(statusTbl, outStatusCsvPath);

% --------------------------
% Write markdown report (MANDATORY)
% --------------------------
fid = fopen(outReportMdPath, 'w');
if fid < 0
    error('debug_fix_o2_pipeline:ReportWriteFail', 'Cannot write report: %s', outReportMdPath);
end
cleanupObj = onCleanup(@() fclose(fid));

fprintf(fid, '# O2 pipeline debug + fix report\n\n');
fprintf(fid, '## Execution status\n\n');
fprintf(fid, '- `EXECUTION_STATUS`: **%s**\n', char(executionStatus));
fprintf(fid, '- `O2_PIPELINE_FIXED`: **%s**\n', char(O2_PIPELINE_FIXED));
fprintf(fid, '- `O2_READY_FOR_CLOSURE_TEST`: **%s**\n', char(O2_READY_FOR_CLOSURE_TEST));

fprintf(fid, '\n## Key artifacts\n\n');
fprintf(fid, '- Raw: `%s`\n', outRawCsvPath);
fprintf(fid, '- Aligned: `%s`\n', outAlignedCsvPath);
fprintf(fid, '- Status: `%s`\n', outStatusCsvPath);
fprintf(fid, '- This report: `%s`\n', outReportMdPath);

fprintf(fid, '\n## Verdicts / availability\n\n');
fprintf(fid, '- `O2_COMPUTED`: **%s**\n', char(O2_COMPUTED));
fprintf(fid, '- `O2_ALIGNED`: **%s**\n', char(O2_ALIGNED));
fprintf(fid, '- `O2_AVAILABLE_FOR_MODELING`: **%s**\n', char(O2_AVAILABLE_FOR_MODELING));
fprintf(fid, '- `N_VALID_POINTS`: **%d**\n', N_VALID_POINTS);
fprintf(fid, '- `ANY_COLUMN_MISSING`: **%s**\n', char(ANY_COLUMN_MISSING));
fprintf(fid, '- `ANY_COLUMN_ALL_NAN`: **%s**\n', char(ANY_COLUMN_ALL_NAN));

fprintf(fid, '\n## Windows / formulas used\n\n');
fprintf(fid, '- `antisymmetric_integral`: `integral_x sign(x) * deltaS(x,T)` (trapz)\n');
fprintf(fid, '- `slope_difference`: linear-fit slope in `x in [-xHalfSlope,0)` and `(0,xHalfSlope]`\n');
fprintf(fid, '- `local_curvature_window`: mean second derivative over `abs(x) < x0Curv`\n');

fprintf(fid, '\n## Minimal sanity test\n\n');
if exist('pearsonR', 'var') && exist('loocvRmse', 'var') && isfinite(pearsonR)
    fprintf(fid, '- Regression: `kappa2 ~ antisymmetric_integral`\n');
    fprintf(fid, '- Pearson (kappa2 vs LOOCV prediction): **%.6g**\n', pearsonR);
    fprintf(fid, '- LOOCV RMSE: **%.6g**\n', loocvRmse);
else
    fprintf(fid, '- Regression not executed (O2 not available for modeling) or metrics unavailable.\n');
end

if strlength(errorText) > 0
    fprintf(fid, '\n## Error text\n\n');
    fprintf(fid, '```\n%s\n```\n', char(errorText));
end

