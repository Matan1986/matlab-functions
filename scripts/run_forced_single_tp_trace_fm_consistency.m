clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
cd(repoRoot);

tablesDir = fullfile(repoRoot, 'tables', 'aging');
reportsDir = fullfile(repoRoot, 'reports', 'aging');
if exist(tablesDir, 'dir') ~= 7
    mkdir(tablesDir);
end
if exist(reportsDir, 'dir') ~= 7
    mkdir(reportsDir);
end

addpath(fullfile(repoRoot, 'Aging'));
addpath(fullfile(repoRoot, 'Aging', 'pipeline'));
addpath(fullfile(repoRoot, 'Aging', 'analysis'));
addpath(fullfile(repoRoot, 'Aging', 'models'));

cfg = agingConfig('MG119_60min');
cfg.agingMetricMode = 'direct';
cfg.AFM_metric_main = 'area';
cfg.doPlotting = false;
cfg.showAllPauses_AFmFM = false;
cfg.enableStage7 = false;

state = Main_Aging(cfg);
pauseRuns = state.pauseRuns;

nRuns = numel(pauseRuns);
TpAll = nan(nRuns, 1);
fmAll = nan(nRuns, 1);
nLeftAll = nan(nRuns, 1);
nRightAll = nan(nRuns, 1);
for i = 1:nRuns
    pr = pauseRuns(i);
    if isfield(pr, 'waitK')
        TpAll(i) = pr.waitK;
    end
    if isfield(pr, 'FM_signed')
        fmAll(i) = pr.FM_signed;
    elseif isfield(pr, 'FM_step_raw')
        fmAll(i) = pr.FM_step_raw;
    end
    if isfield(pr, 'FM_plateau_n_left')
        nLeftAll(i) = pr.FM_plateau_n_left;
    end
    if isfield(pr, 'FM_plateau_n_right')
        nRightAll(i) = pr.FM_plateau_n_right;
    end
end

candidate = find(~isfinite(fmAll) & (nRightAll >= 3) & (nLeftAll < 3), 1, 'first');
if isempty(candidate)
    candidate = find(~isfinite(fmAll) & (nRightAll >= 3), 1, 'first');
end
if isempty(candidate)
    candidate = find(~isfinite(fmAll), 1, 'first');
end
if isempty(candidate)
    error('No run with FM NaN found; cannot perform forced single-Tp trace.');
end

pr = pauseRuns(candidate);
TpSelected = pr.waitK;
tpTag = strrep(sprintf('%.6g', TpSelected), '.', 'p');
fprintf('Tp_selected = %.6g K (index %d)\n', TpSelected, candidate);

if ~isfield(pr, 'T_common') || ~isfield(pr, 'DeltaM')
    error('Selected run missing T_common or DeltaM.');
end

T = pr.T_common(:);
dM = pr.DeltaM(:);
if isfield(pr, 'DeltaM_smooth') && ~isempty(pr.DeltaM_smooth)
    dM_smooth = pr.DeltaM_smooth(:);
else
    dM_smooth = nan(size(dM));
end

n = min([numel(T), numel(dM), numel(dM_smooth)]);
T = T(1:n);
dM = dM(1:n);
dM_smooth = dM_smooth(1:n);

if isfield(pr, 'I_common') && ~isempty(pr.I_common)
    I = pr.I_common(:);
    I = I(1:min(numel(I), n));
    if numel(I) < n
        I(end+1:n, 1) = NaN;
    end
    iSource = "I_common";
elseif isfield(pr, 'I') && ~isempty(pr.I)
    I = pr.I(:);
    I = I(1:min(numel(I), n));
    if numel(I) < n
        I(end+1:n, 1) = NaN;
    end
    iSource = "I";
else
    I = T;
    iSource = "fallback_T_common";
end

% STEP 1 - raw table
rawTbl = table((1:n)', I, T, dM, dM_smooth, ...
    'VariableNames', {'idx', 'I', 'T_K', 'DeltaM', 'DeltaM_smooth'});
rawPath = fullfile(tablesDir, sprintf('trace_Tp_%s_raw.csv', tpTag));
writetable(rawTbl, rawPath);

% STEP 2 - extraction masks (reconstruct stage4 logic)
if isfield(pr, 'FM_plateau_left_window') && numel(pr.FM_plateau_left_window) == 2
    leftWin = pr.FM_plateau_left_window(:)';
else
    leftWin = [NaN NaN];
end
if isfield(pr, 'FM_plateau_right_window') && numel(pr.FM_plateau_right_window) == 2
    rightWin = pr.FM_plateau_right_window(:)';
else
    rightWin = [NaN NaN];
end

useFixedRight = isfield(cfg, 'FM_rightPlateauMode') && strcmpi(string(cfg.FM_rightPlateauMode), "fixed");
maskFiniteT = isfinite(T);
if all(isfinite(rightWin))
    if useFixedRight
        maskRightExtraction = maskFiniteT & (T >= rightWin(1)) & (T <= rightWin(2));
    else
        maskRightExtraction = maskFiniteT & (T > rightWin(1)) & (T < rightWin(2));
    end
else
    maskRightExtraction = false(size(T));
end
if all(isfinite(leftWin))
    maskLeftExtraction = maskFiniteT & (T > leftWin(1)) & (T < leftWin(2));
else
    maskLeftExtraction = false(size(T));
end

maskTbl = table((1:n)', T, dM, maskLeftExtraction, maskRightExtraction, ...
    'VariableNames', {'idx', 'T_K', 'DeltaM', 'mask_left_extraction', 'mask_right_extraction'});
maskPath = fullfile(tablesDir, sprintf('trace_Tp_%s_extraction_masks.csv', tpTag));
writetable(maskTbl, maskPath);

% STEP 3 - forced computation (no validity checks)
leftValuesForced = dM(maskLeftExtraction);
rightValuesForced = dM(maskRightExtraction);
FM_forced = median(leftValuesForced, 'omitnan') - median(rightValuesForced, 'omitnan');

forcedTbl = table( ...
    repmat(TpSelected, n, 1), (1:n)', T, dM, maskLeftExtraction, maskRightExtraction, ...
    repmat(numel(leftValuesForced), n, 1), repmat(numel(rightValuesForced), n, 1), ...
    repmat(median(leftValuesForced, 'omitnan'), n, 1), repmat(median(rightValuesForced, 'omitnan'), n, 1), ...
    repmat(FM_forced, n, 1), ...
    'VariableNames', {'Tp_K', 'idx', 'T_K', 'DeltaM', 'mask_left_extraction', 'mask_right_extraction', ...
    'n_left', 'n_right', 'left_median', 'right_median', 'FM_forced'});
forcedPath = fullfile(tablesDir, sprintf('trace_Tp_%s_forced_computation.csv', tpTag));
writetable(forcedTbl, forcedPath);

% STEP 4 - actual pipeline computation
leftValuesPipeline = dM_smooth(maskLeftExtraction);
rightValuesPipeline = dM_smooth(maskRightExtraction);
fmConvention = string(cfg.FMConvention);
if lower(fmConvention) == "leftminusright"
    FM_pipeline_reconstructed = mean(leftValuesPipeline, 'omitnan') - mean(rightValuesPipeline, 'omitnan');
else
    FM_pipeline_reconstructed = mean(rightValuesPipeline, 'omitnan') - mean(leftValuesPipeline, 'omitnan');
end
if isfield(pr, 'FM_step_raw')
    FM_pipeline_actual = pr.FM_step_raw;
else
    FM_pipeline_actual = NaN;
end
if isfield(pr, 'FM_plateau_valid')
    pipelineRejected = ~logical(pr.FM_plateau_valid);
else
    pipelineRejected = ~isfinite(FM_pipeline_actual);
end
if isfield(pr, 'FM_plateau_reason') && ~isempty(pr.FM_plateau_reason)
    fmReason = string(pr.FM_plateau_reason);
else
    fmReason = "";
end

pipelineTbl = table( ...
    repmat(TpSelected, n, 1), (1:n)', T, dM_smooth, maskLeftExtraction, maskRightExtraction, ...
    repmat(numel(leftValuesPipeline), n, 1), repmat(numel(rightValuesPipeline), n, 1), ...
    repmat(mean(leftValuesPipeline, 'omitnan'), n, 1), repmat(mean(rightValuesPipeline, 'omitnan'), n, 1), ...
    repmat(FM_pipeline_reconstructed, n, 1), repmat(FM_pipeline_actual, n, 1), ...
    repmat(pipelineRejected, n, 1), repmat(fmReason, n, 1), ...
    repmat("mean(left)-mean(right) on DeltaM_smooth", n, 1), ...
    'VariableNames', {'Tp_K', 'idx', 'T_K', 'DeltaM_smooth', 'mask_left_computation', 'mask_right_computation', ...
    'n_left', 'n_right', 'left_stat_value', 'right_stat_value', ...
    'FM_pipeline_reconstructed', 'FM_pipeline_actual', 'FM_rejected', 'FM_plateau_reason', 'pipeline_statistic'});
pipelinePath = fullfile(tablesDir, sprintf('trace_Tp_%s_pipeline_computation.csv', tpTag));
writetable(pipelineTbl, pipelinePath);

% STEP 5 - visualization masks (what direct styled summary actually plots)
% For a single Tp point, the summary plot includes it only when FM is finite.
% For left/right plateau overlays used in diagnostics, use debug window builder logic.
debugCfg = cfg.debug;
windows = localBuildDebugWindows(TpSelected, cfg, debugCfg, T);
if all(isfinite(windows.fmPlateauL))
    maskLeftPlot = isfinite(T) & (T >= windows.fmPlateauL(1)) & (T <= windows.fmPlateauL(2));
else
    maskLeftPlot = false(size(T));
end
if all(isfinite(windows.fmPlateauR))
    maskRightPlot = isfinite(T) & (T >= windows.fmPlateauR(1)) & (T <= windows.fmPlateauR(2));
else
    maskRightPlot = false(size(T));
end

plotTbl = table((1:n)', T, dM, maskLeftPlot, maskRightPlot, maskLeftExtraction, maskRightExtraction, ...
    (maskLeftPlot == maskLeftExtraction), (maskRightPlot == maskRightExtraction), ...
    'VariableNames', {'idx', 'T_K', 'DeltaM', 'mask_left_plot', 'mask_right_plot', ...
    'mask_left_extraction', 'mask_right_extraction', 'left_plot_equals_extraction', 'right_plot_equals_extraction'});
plotPath = fullfile(tablesDir, sprintf('trace_Tp_%s_plot_masks.csv', tpTag));
writetable(plotTbl, plotPath);

% STEP 6 - consistency table
leftExtractionSig = localMaskSignature(maskLeftExtraction);
rightExtractionSig = localMaskSignature(maskRightExtraction);
leftCompSig = leftExtractionSig;
rightCompSig = rightExtractionSig;
leftPlotSig = localMaskSignature(maskLeftPlot);
rightPlotSig = localMaskSignature(maskRightPlot);

consistencyTbl = table( ...
    ["extraction"; "computation"; "plot"], ...
    [leftExtractionSig; leftCompSig; leftPlotSig], ...
    [rightExtractionSig; rightCompSig; rightPlotSig], ...
    ["YES"; string(localBoolToYN(strcmp(leftCompSig, leftPlotSig) && strcmp(rightCompSig, rightPlotSig))); ""], ...
    'VariableNames', {'stage', 'left_mask', 'right_mask', 'matches_next_stage'});
consistencyPath = fullfile(tablesDir, sprintf('trace_Tp_%s_consistency.csv', tpTag));
writetable(consistencyTbl, consistencyPath);

% STEP 7 - verdicts
extractionEqualsComputation = localBoolToYN(isequal(maskLeftExtraction, maskLeftExtraction) && isequal(maskRightExtraction, maskRightExtraction));
computationEqualsPlot = localBoolToYN(isequal(maskLeftExtraction, maskLeftPlot) && isequal(maskRightExtraction, maskRightPlot));

if nnz(maskLeftExtraction) > 0 && pipelineRejected
    leftPlateauStatus = "EXISTS_BUT_REJECTED";
elseif nnz(maskLeftExtraction) == 0
    leftPlateauStatus = "NOT_DETECTED";
elseif nnz(maskLeftExtraction) < 3
    leftPlateauStatus = "TOO_SMALL";
elseif nnz(maskLeftPlot) == 0
    leftPlateauStatus = "NOT_PLOTTED";
else
    leftPlateauStatus = "EXISTS";
end

if pipelineRejected
    FM_NAN_REASON = sprintf('Rejected by pipeline: FM_plateau_valid=false, reason=%s, n_left=%d, n_right=%d, left_window=[%.6g %.6g], right_window=[%.6g %.6g].', ...
        fmReason, nnz(maskLeftExtraction), nnz(maskRightExtraction), leftWin(1), leftWin(2), rightWin(1), rightWin(2));
else
    FM_NAN_REASON = 'FM is finite for selected run.';
end

if nnz(maskLeftExtraction) > 0
    criticalAnswer = "present but suppressed by the pipeline";
else
    criticalAnswer = "physically absent (not detected in extraction masks)";
end

reportPath = fullfile(reportsDir, sprintf('trace_Tp_%s_audit_report.md', tpTag));
fid = fopen(reportPath, 'w');
if fid < 0
    error('Failed to open report for writing: %s', reportPath);
end
fprintf(fid, '# Forced Single-Tp Trace Audit (FM Consistency)\n\n');
fprintf(fid, '- Tp_selected = %.6g K\n', TpSelected);
fprintf(fid, '- I source = %s\n', iSource);
fprintf(fid, '- FM_forced = %.12g\n', FM_forced);
fprintf(fid, '- FM_pipeline_actual = %.12g\n\n', FM_pipeline_actual);

fprintf(fid, '## Plain explanation\n\n');
fprintf(fid, 'Mismatch trace: extraction -> computation -> plot.\n\n');
fprintf(fid, '- Extraction masks (stage4 windows): left n=%d, right n=%d.\n', nnz(maskLeftExtraction), nnz(maskRightExtraction));
fprintf(fid, '- Computation uses DeltaM_smooth with mean statistics and requires validity gate FM_plateau_valid.\n');
fprintf(fid, '- Plot masks (debug overlay) come from debug baseline window builder and can differ from extraction windows.\n\n');

fprintf(fid, '## Forced vs actual comparison\n\n');
fprintf(fid, '- FM_forced (median raw DeltaM, no checks) = %.12g\n', FM_forced);
fprintf(fid, '- FM_pipeline_reconstructed (mean smoothed DeltaM) = %.12g\n', FM_pipeline_reconstructed);
fprintf(fid, '- FM_pipeline_actual (stored) = %.12g\n', FM_pipeline_actual);
fprintf(fid, '- FM_rejected = %s\n\n', localBoolToYN(pipelineRejected));

fprintf(fid, '## Final verdicts\n\n');
fprintf(fid, '- EXTRACTION_EQUALS_COMPUTATION = %s\n', extractionEqualsComputation);
fprintf(fid, '- COMPUTATION_EQUALS_PLOT = %s\n', computationEqualsPlot);
fprintf(fid, '- LEFT_PLATEAU_STATUS = %s\n', leftPlateauStatus);
fprintf(fid, '- FM_NAN_REASON = %s\n\n', FM_NAN_REASON);

fprintf(fid, '## Critical answer\n\n');
fprintf(fid, 'Is the left plateau physically absent OR present but suppressed by the pipeline?\n\n');
fprintf(fid, '**%s**\n\n', criticalAnswer);

fprintf(fid, '## Output artifacts\n\n');
fprintf(fid, '- %s\n', rawPath);
fprintf(fid, '- %s\n', maskPath);
fprintf(fid, '- %s\n', forcedPath);
fprintf(fid, '- %s\n', pipelinePath);
fprintf(fid, '- %s\n', plotPath);
fprintf(fid, '- %s\n', consistencyPath);
fclose(fid);

fprintf('Wrote report: %s\n', reportPath);

function windows = localBuildDebugWindows(Tp, cfg, debugCfg, T)
T = T(:);
windows = struct();
windows.dip = [Tp - cfg.dip_window_K, Tp + cfg.dip_window_K];
windows.fmPlateauL = [NaN NaN];
windows.fmPlateauR = [NaN NaN];
if isempty(T) || ~all(isfinite(T))
    return;
end

cfg_baseline = struct();
cfg_baseline.dip_halfwidth_K = cfg.dip_window_K;
if isfield(cfg, 'dip_margin_K')
    cfg_baseline.dip_margin_K = cfg.dip_margin_K;
else
    cfg_baseline.dip_margin_K = 2;
end
if isfield(cfg, 'plateau_nPoints')
    cfg_baseline.plateau_nPoints = cfg.plateau_nPoints;
else
    cfg_baseline.plateau_nPoints = 6;
end

Y_dummy = zeros(size(T));
baselineOut = estimateRobustBaseline(T, Y_dummy, Tp, cfg_baseline);
if strcmp(baselineOut.status, 'ok')
    baseL = [baselineOut.TL - 0.1, baselineOut.TL + 0.1];
    if isfield(cfg, 'FM_rightPlateauMode') && strcmpi(cfg.FM_rightPlateauMode, 'fixed')
        baseR = cfg.FM_rightPlateauFixedWindow_K(:).';
    else
        baseR = [baselineOut.TR - 0.1, baselineOut.TR + 0.1];
    end
else
    finiteT = T(isfinite(T));
    if isempty(finiteT)
        return;
    end
    Tmin = min(finiteT);
    Tmax = max(finiteT);
    dT = (Tmax - Tmin) / 4;
    baseL = [Tmin, Tmin + dT];
    if isfield(cfg, 'FM_rightPlateauMode') && strcmpi(cfg.FM_rightPlateauMode, 'fixed')
        baseR = cfg.FM_rightPlateauFixedWindow_K(:).';
    else
        baseR = [Tmax - dT, Tmax];
    end
end
windows.fmPlateauL = baseL;
windows.fmPlateauR = baseR;
if nargin >= 3 && ~isempty(debugCfg) %#ok<INUSD>
end
end

function s = localMaskSignature(mask)
idx = find(mask(:));
if isempty(idx)
    s = "[]";
    return;
end
s = sprintf('[%d..%d] (n=%d)', idx(1), idx(end), numel(idx));
end

function yn = localBoolToYN(tf)
if tf
    yn = "YES";
else
    yn = "NO";
end
end
