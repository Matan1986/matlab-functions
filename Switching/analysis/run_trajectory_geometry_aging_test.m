% run_trajectory_geometry_aging_test
% Test whether aging R(T) depends on trajectory geometry in (kappa1, kappa2).
%
% This is a pure MATLAB script (no local function blocks) so it can run
% under eval(fileread(...)) wrappers used in this repository.

clearvars;
clc;

repoRoot = 'C:\Dev\matlab-functions';
analysisDir = fullfile(repoRoot, 'Switching', 'analysis');
addpath(analysisDir);

% -------------------------------
% Inputs (ABSOLUTE PATHS)
% -------------------------------
% kappa table must contain: T_K, kappa1, kappa2
kappaTablePath = fullfile(repoRoot, 'tables', 'R_vs_state.csv');
% aging table must contain: T_K, and R (or R_T / R_TK)
agingRTablePath = fullfile(repoRoot, 'tables', 'R_vs_state.csv');

% -------------------------------
% Outputs (ABSOLUTE PATHS)
% -------------------------------
outTablesDir = fullfile(repoRoot, 'tables');
outReportsDir = fullfile(repoRoot, 'reports');
ensureDir(outTablesDir);
ensureDir(outReportsDir);

modelsOutPath = fullfile(outTablesDir, 'trajectory_aging_models.csv');
reportOutPath = fullfile(outReportsDir, 'trajectory_geometry_aging.md');
statusOutPath = fullfile(outTablesDir, 'trajectory_aging_status.csv');

% -------------------------------
% Decision thresholds
% -------------------------------
cfg = struct();
cfg.tolT = 1e-9;
cfg.minRelRmseImprovement = 0.08;
cfg.minRelRmseImprovementIndependent = 0.03;
cfg.minPearsonImprovement = 0.02;

% Defaults so outputs are always produced.
runStatus = "SUCCESS";
errorMessage = "";
AGING_DEPENDS_ON_TRAJECTORY_GEOMETRY = "NO";
CURVATURE_BEATS_STATE_ONLY = "NO";
TRAJECTORY_HAS_INDEPENDENT_INFORMATION = "NO";

modelsTbl = table( ...
    string.empty(0, 1), string.empty(0, 1), nan(0, 1), nan(0, 1), nan(0, 1), nan(0, 1), ...
    'VariableNames', {'model', 'category', 'n', 'loocv_rmse', 'pearson_y_yhat', 'spearman_y_yhat'});

report = strings(0, 1);
runStamp = datestr(datetime('now'), 'yyyy-mm-dd HH:MM:SS');

try
    % -------------------------------
    % Load inputs
    % -------------------------------
    assert(exist(kappaTablePath, 'file') == 2, ...
        'Kappa table not found: %s', kappaTablePath);
    assert(exist(agingRTablePath, 'file') == 2, ...
        'Aging R table not found: %s', agingRTablePath);

    fprintf('Reading kappa table:\n%s\n', kappaTablePath);
    kappaTbl = readtable(kappaTablePath, ...
        'TextType', 'string', 'VariableNamingRule', 'preserve');

    fprintf('Reading aging R table:\n%s\n', agingRTablePath);
    agingTbl = readtable(agingRTablePath, ...
        'TextType', 'string', 'VariableNamingRule', 'preserve');

    % -------------------------------
    % Extract required columns
    % -------------------------------
    kappaT = toDoubleColumn(getVarByCandidates(kappaTbl, {'T_K', 'T', 'Tk', 't_k', 't'}));
    kappa1 = toDoubleColumn(getVarByCandidates(kappaTbl, {'kappa1', 'kappa_1'}));
    kappa2 = toDoubleColumn(getVarByCandidates(kappaTbl, {'kappa2', 'kappa_2'}));

    ageT = toDoubleColumn(getVarByCandidates(agingTbl, {'T_K', 'T', 'Tk', 't_k', 't'}));
    ageR = toDoubleColumn(getVarByCandidates(agingTbl, {'R', 'R_T', 'R_TK'}));

    kappaT = kappaT(:);
    kappa1 = kappa1(:);
    kappa2 = kappa2(:);
    ageT = ageT(:);
    ageR = ageR(:);

    validKappa = isfinite(kappaT) & isfinite(kappa1) & isfinite(kappa2);
    kappaT = kappaT(validKappa);
    kappa1 = kappa1(validKappa);
    kappa2 = kappa2(validKappa);

    validAge = isfinite(ageT) & isfinite(ageR);
    ageT = ageT(validAge);
    ageR = ageR(validAge);

    assert(numel(kappaT) == numel(kappa1) && numel(kappaT) == numel(kappa2), ...
        'Kappa table has inconsistent lengths for T_K, kappa1, kappa2.');
    assert(numel(ageT) == numel(ageR), ...
        'Aging table has inconsistent lengths for T_K and R.');

    checkNoDuplicateTemps(kappaT, 'kappa');
    checkNoDuplicateTemps(ageT, 'aging');

    % -------------------------------
    % Manual T_K alignment (no join)
    % -------------------------------
    kappaTUniq = unique(kappaT, 'stable');
    ageTUniq = unique(ageT, 'stable');

    alignedT = [];
    alignedK1 = [];
    alignedK2 = [];
    alignedR = [];

    for i = 1:numel(kappaTUniq)
        t = kappaTUniq(i);
        idxAgeUniq = find(abs(ageTUniq - t) <= cfg.tolT, 1, 'first');
        if isempty(idxAgeUniq)
            continue;
        end

        idxKappa = find(abs(kappaT - t) <= cfg.tolT, 1, 'first');
        idxAge = find(abs(ageT - t) <= cfg.tolT, 1, 'first');
        if isempty(idxKappa) || isempty(idxAge)
            continue;
        end

        alignedT(end + 1, 1) = t; %#ok<AGROW>
        alignedK1(end + 1, 1) = kappa1(idxKappa); %#ok<AGROW>
        alignedK2(end + 1, 1) = kappa2(idxKappa); %#ok<AGROW>
        alignedR(end + 1, 1) = ageR(idxAge); %#ok<AGROW>
    end

    [T_aligned, sortOrder] = sort(alignedT, 'ascend');
    k1_aligned = alignedK1(sortOrder);
    k2_aligned = alignedK2(sortOrder);
    R_aligned = alignedR(sortOrder);

    nAligned = numel(T_aligned);
    assert(nAligned >= 5, ...
        'Need at least 5 aligned temperatures for geometry features. Got n=%d', nAligned);

    % -------------------------------
    % Trajectory geometry features from (kappa1, kappa2)
    % -------------------------------
    % Feature definitions:
    % - arc_length(i): cumulative polyline length from the first point to i.
    % - turning_angle(i): signed direction change at point i between adjacent segments.
    % - direction_change(i): absolute turning angle.
    % - curvature(i): discrete Menger curvature from points (i-1, i, i+1).
    %
    % Boundary rows (i=1 and i=nAligned) do not have full local geometry and
    % remain NaN for turning/curvature/direction-change.

    arc_length = NaN(nAligned, 1);
    turning_angle = NaN(nAligned, 1);
    direction_change = NaN(nAligned, 1);
    curvature = NaN(nAligned, 1);

    dk1 = diff(k1_aligned);
    dk2 = diff(k2_aligned);
    ds = hypot(dk1, dk2);
    segAngle = atan2(dk2, dk1);

    arc_length(1) = 0;
    if ~isempty(ds)
        arc_length(2:end) = cumsum(ds);
    end

    for i = 2:(nAligned - 1)
        prevAngle = segAngle(i - 1);
        nextAngle = segAngle(i);
        dTheta = atan2(sin(nextAngle - prevAngle), cos(nextAngle - prevAngle));
        turning_angle(i) = dTheta;
        direction_change(i) = abs(dTheta);

        a = hypot(k1_aligned(i) - k1_aligned(i - 1), k2_aligned(i) - k2_aligned(i - 1));
        b = hypot(k1_aligned(i + 1) - k1_aligned(i), k2_aligned(i + 1) - k2_aligned(i));
        c = hypot(k1_aligned(i + 1) - k1_aligned(i - 1), k2_aligned(i + 1) - k2_aligned(i - 1));

        if a > 0 && b > 0 && c > 0
            v1x = k1_aligned(i) - k1_aligned(i - 1);
            v1y = k2_aligned(i) - k2_aligned(i - 1);
            v2x = k1_aligned(i + 1) - k1_aligned(i);
            v2y = k2_aligned(i + 1) - k2_aligned(i);
            crossVal = v1x * v2y - v1y * v2x;
            curvature(i) = 2 * abs(crossVal) / (a * b * c);
        end
    end

    % Strict common mask for fair model comparison.
    validMask = isfinite(R_aligned) & isfinite(k1_aligned) & ...
        isfinite(turning_angle) & isfinite(curvature) & ...
        isfinite(arc_length) & isfinite(direction_change);

    T = T_aligned(validMask); %#ok<NASGU>
    y = R_aligned(validMask);
    x_kappa1 = k1_aligned(validMask);
    x_turning = turning_angle(validMask);
    x_curvature = curvature(validMask);
    x_arclen = arc_length(validMask);
    x_dirchg = direction_change(validMask);

    n = numel(y);
    assert(n >= 4, 'Need at least 4 valid rows after strict feature mask. Got n=%d', n);

    fprintf('Aligned rows before geometry mask: %d\n', nAligned);
    fprintf('Rows after strict geometry mask: %d\n', n);

    % -------------------------------
    % Models
    % -------------------------------
    X_state = [ones(n, 1), x_kappa1];
    X_curvature = [ones(n, 1), x_curvature];
    X_trajectory = [ones(n, 1), x_turning, x_curvature, x_arclen, x_dirchg];
    X_combined = [ones(n, 1), x_kappa1, x_turning, x_curvature, x_arclen, x_dirchg];

    modelSpecs = {
        'R ~ kappa1', 'state_only', X_state;
        'R ~ curvature', 'curvature_only', X_curvature;
        'R ~ trajectory', 'trajectory', X_trajectory;
        'R ~ combined', 'combined', X_combined
        };

    results = struct( ...
        'model', '', ...
        'category', '', ...
        'n', NaN, ...
        'loocv_rmse', NaN, ...
        'pearson_r', NaN, ...
        'spearman_r', NaN, ...
        'yhat_loocv', nan(n, 1));

    for m = 1:size(modelSpecs, 1)
        results(m) = results(1); %#ok<SAGROW>
        results(m).model = modelSpecs{m, 1};
        results(m).category = modelSpecs{m, 2};
        results(m).n = n;

        X = modelSpecs{m, 3};
        fprintf('LOOCV fit: %s\n', results(m).model);
        yhat = leaveOneOutPredict(X, y);
        metrics = computeMetrics(y, yhat);

        results(m).loocv_rmse = metrics.rmse;
        results(m).pearson_r = metrics.pearson_r;
        results(m).spearman_r = metrics.spearman_r;
        results(m).yhat_loocv = yhat;
    end

    idx_state = find(strcmp({results.model}, 'R ~ kappa1'), 1, 'first');
    idx_curv = find(strcmp({results.model}, 'R ~ curvature'), 1, 'first');
    idx_traj = find(strcmp({results.model}, 'R ~ trajectory'), 1, 'first');
    idx_comb = find(strcmp({results.model}, 'R ~ combined'), 1, 'first');

    rmse_state = results(idx_state).loocv_rmse;
    rmse_curv = results(idx_curv).loocv_rmse;
    rmse_traj = results(idx_traj).loocv_rmse;
    rmse_comb = results(idx_comb).loocv_rmse;

    pearson_state = results(idx_state).pearson_r;
    pearson_curv = results(idx_curv).pearson_r;
    pearson_traj = results(idx_traj).pearson_r;
    pearson_comb = results(idx_comb).pearson_r;

    relImp_traj_vs_state = relImprovement(rmse_state, rmse_traj);
    relImp_curv_vs_state = relImprovement(rmse_state, rmse_curv);
    relImp_comb_vs_state = relImprovement(rmse_state, rmse_comb);
    relImp_comb_vs_traj = relImprovement(rmse_traj, rmse_comb);

    resid_state = y - results(idx_state).yhat_loocv;
    resid_comb = y - results(idx_comb).yhat_loocv;
    residCorrCurv_state = pearsonCorrelation(resid_state, x_curvature);
    residCorrCurv_comb = pearsonCorrelation(resid_comb, x_curvature);

    corrR_turning = pearsonCorrelation(y, x_turning);
    corrR_curvature = pearsonCorrelation(y, x_curvature);
    corrR_arclen = pearsonCorrelation(y, x_arclen);
    corrR_dirchg = pearsonCorrelation(y, x_dirchg);

    AGING_DEPENDS_ON_TRAJECTORY_GEOMETRY = yesno( ...
        isfinite(relImp_traj_vs_state) && relImp_traj_vs_state >= cfg.minRelRmseImprovement && ...
        isfinite(pearson_state) && isfinite(pearson_traj) && ...
        (pearson_traj - pearson_state) >= cfg.minPearsonImprovement);

    CURVATURE_BEATS_STATE_ONLY = yesno( ...
        isfinite(relImp_curv_vs_state) && relImp_curv_vs_state > 0 && ...
        isfinite(pearson_curv) && isfinite(pearson_state) && ...
        (pearson_curv - pearson_state) >= 0);

    TRAJECTORY_HAS_INDEPENDENT_INFORMATION = yesno( ...
        isfinite(relImp_comb_vs_state) && relImp_comb_vs_state >= cfg.minRelRmseImprovement && ...
        isfinite(relImp_comb_vs_traj) && relImp_comb_vs_traj >= cfg.minRelRmseImprovementIndependent && ...
        isfinite(pearson_comb) && isfinite(pearson_state) && isfinite(pearson_traj) && ...
        (pearson_comb - max(pearson_state, pearson_traj)) >= cfg.minPearsonImprovement);

    modelsTbl = table();
    modelsTbl.model = {results.model}';
    modelsTbl.category = {results.category}';
    modelsTbl.n = [results.n]';
    modelsTbl.loocv_rmse = [results.loocv_rmse]';
    modelsTbl.pearson_y_yhat = [results.pearson_r]';
    modelsTbl.spearman_y_yhat = [results.spearman_r]';

    % -------------------------------
    % Markdown report (success path)
    % -------------------------------
    report(end + 1) = '# Trajectory geometry aging test';
    report(end + 1) = '';
    report(end + 1) = sprintf('- Generated: %s', runStamp);
    report(end + 1) = '';
    report(end + 1) = '## Inputs (absolute paths)';
    report(end + 1) = sprintf('- kappa table: `%s`', kappaTablePath);
    report(end + 1) = sprintf('- aging R table: `%s`', agingRTablePath);
    report(end + 1) = '';
    report(end + 1) = '## Alignment and data flow';
    report(end + 1) = sprintf('- Manual `T_K` alignment with tolerance %.1e (no table join).', cfg.tolT);
    report(end + 1) = sprintf('- Aligned rows before geometry boundary mask: %d.', nAligned);
    report(end + 1) = sprintf('- Rows used for all models after strict common mask: %d.', n);
    report(end + 1) = '';
    report(end + 1) = '## Trajectory features';
    report(end + 1) = '- `turning_angle`: signed direction change between adjacent trajectory segments.';
    report(end + 1) = '- `curvature`: discrete Menger curvature from local triplets in `(kappa1,kappa2)`.';
    report(end + 1) = '- `arc_length`: cumulative polyline distance along temperature-ordered trajectory.';
    report(end + 1) = '- `direction_change`: absolute turning angle.';
    report(end + 1) = '';
    report(end + 1) = '## LOOCV model metrics';
    report(end + 1) = '';
    report(end + 1) = '| Model | LOOCV RMSE | Pearson(y,yhat) | Spearman(y,yhat) |';
    report(end + 1) = '| --- | ---: | ---: | ---: |';

    for m = 1:numel(results)
        report(end + 1) = sprintf('| %s | %s | %s | %s |', ...
            sanitizeMD(results(m).model), ...
            formatNum(results(m).loocv_rmse), ...
            formatNum(results(m).pearson_r), ...
            formatNum(results(m).spearman_r));
    end

    report(end + 1) = '';
    report(end + 1) = '## Relative RMSE improvements';
    report(end + 1) = sprintf('- trajectory vs state-only: %s', formatNum(relImp_traj_vs_state));
    report(end + 1) = sprintf('- curvature-only vs state-only: %s', formatNum(relImp_curv_vs_state));
    report(end + 1) = sprintf('- combined vs state-only: %s', formatNum(relImp_comb_vs_state));
    report(end + 1) = sprintf('- combined vs trajectory: %s', formatNum(relImp_comb_vs_traj));
    report(end + 1) = '';
    report(end + 1) = '## Feature correlations with R';
    report(end + 1) = sprintf('- corr(R, turning_angle): %s', formatNum(corrR_turning));
    report(end + 1) = sprintf('- corr(R, curvature): %s', formatNum(corrR_curvature));
    report(end + 1) = sprintf('- corr(R, arc_length): %s', formatNum(corrR_arclen));
    report(end + 1) = sprintf('- corr(R, direction_change): %s', formatNum(corrR_dirchg));
    report(end + 1) = '';
    report(end + 1) = '## Residual diagnostics (curvature)';
    report(end + 1) = sprintf('- corr(residual_state_only, curvature): %s', formatNum(residCorrCurv_state));
    report(end + 1) = sprintf('- corr(residual_combined, curvature): %s', formatNum(residCorrCurv_comb));
    report(end + 1) = '';
    report(end + 1) = '## Verdicts';
    report(end + 1) = sprintf('- `AGING_DEPENDS_ON_TRAJECTORY_GEOMETRY`: %s', AGING_DEPENDS_ON_TRAJECTORY_GEOMETRY);
    report(end + 1) = sprintf('- `CURVATURE_BEATS_STATE_ONLY`: %s', CURVATURE_BEATS_STATE_ONLY);
    report(end + 1) = sprintf('- `TRAJECTORY_HAS_INDEPENDENT_INFORMATION`: %s', TRAJECTORY_HAS_INDEPENDENT_INFORMATION);

catch ME
    runStatus = "ERROR";
    errorMessage = string(ME.message);

    AGING_DEPENDS_ON_TRAJECTORY_GEOMETRY = "ERROR";
    CURVATURE_BEATS_STATE_ONLY = "ERROR";
    TRAJECTORY_HAS_INDEPENDENT_INFORMATION = "ERROR";

    if isempty(modelsTbl)
        modelsTbl = table( ...
            "ANALYSIS_ERROR", "error", NaN, NaN, NaN, NaN, ...
            'VariableNames', {'model', 'category', 'n', 'loocv_rmse', 'pearson_y_yhat', 'spearman_y_yhat'});
    end

    report = strings(0, 1);
    report(end + 1) = '# Trajectory geometry aging test';
    report(end + 1) = '';
    report(end + 1) = sprintf('- Generated: %s', runStamp);
    report(end + 1) = '- Status: ERROR';
    report(end + 1) = '';
    report(end + 1) = '## Inputs (absolute paths)';
    report(end + 1) = sprintf('- kappa table: `%s`', kappaTablePath);
    report(end + 1) = sprintf('- aging R table: `%s`', agingRTablePath);
    report(end + 1) = '';
    report(end + 1) = '## Error';
    report(end + 1) = sprintf('- `%s`', sanitizeMD(char(errorMessage)));
end

% -------------------------------
% Write outputs (always)
% -------------------------------
fprintf('Writing models CSV:\n%s\n', modelsOutPath);
writetable(modelsTbl, modelsOutPath);

statusTbl = table( ...
    AGING_DEPENDS_ON_TRAJECTORY_GEOMETRY, ...
    CURVATURE_BEATS_STATE_ONLY, ...
    TRAJECTORY_HAS_INDEPENDENT_INFORMATION, ...
    runStatus, ...
    errorMessage, ...
    'VariableNames', { ...
    'AGING_DEPENDS_ON_TRAJECTORY_GEOMETRY', ...
    'CURVATURE_BEATS_STATE_ONLY', ...
    'TRAJECTORY_HAS_INDEPENDENT_INFORMATION', ...
    'run_status', ...
    'error_message'});

fprintf('Writing status CSV:\n%s\n', statusOutPath);
writetable(statusTbl, statusOutPath);

reportText = strjoin(report, newline);
fprintf('Writing markdown report:\n%s\n', reportOutPath);
fid = fopen(reportOutPath, 'w');
assert(fid >= 0, 'Could not open report output for writing: %s', reportOutPath);
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', reportText);

fprintf('Done.\n');
fprintf('Models CSV: %s\n', modelsOutPath);
fprintf('Report MD: %s\n', reportOutPath);
fprintf('Status CSV: %s\n', statusOutPath);
