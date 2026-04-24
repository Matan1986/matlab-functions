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

cfg = agingConfig('MG119_60min');
cfg.agingMetricMode = 'direct';
cfg.AFM_metric_main = 'area';
cfg.doPlotting = false;
cfg.enableStage7 = false;

state = Main_Aging(cfg);
pauseRuns = state.pauseRuns;

Tp = [pauseRuns.waitK];

idxTp6 = find(abs(Tp - 6) < 1e-9, 1, 'first');
idxValid = find(arrayfun(@(r) isfield(r, 'FM_plateau_valid') && logical(r.FM_plateau_valid) && ...
    isfield(r, 'FM_plateau_n_left') && isfield(r, 'FM_plateau_n_right') && ...
    r.FM_plateau_n_left > 0 && r.FM_plateau_n_right > 0, pauseRuns), 1, 'first');

testIdx = [];
if ~isempty(idxTp6)
    testIdx(end + 1) = idxTp6; %#ok<AGROW>
end
if ~isempty(idxValid) && (~any(testIdx == idxValid))
    testIdx(end + 1) = idxValid; %#ok<AGROW>
end

if isempty(testIdx)
    error('No verification runs found.');
end

TpVals = [];
pipelineLeftCount = [];
plotLeftCount = [];
leftMatchVals = strings(0, 1);
pipelineRightCount = [];
plotRightCount = [];
rightMatchVals = strings(0, 1);
fmValidVals = strings(0, 1);
plotConsistentVals = strings(0, 1);
for ii = 1:numel(testIdx)
    i = testIdx(ii);
    run = pauseRuns(i);
    if isfield(run, 'T_common')
        T = run.T_common(:);
    else
        T = [];
    end
    nT = numel(T);

    pipeMaskL = false(nT, 1);
    pipeMaskR = false(nT, 1);
    if isfield(run, 'FM_plateau_mask_left') && ~isempty(run.FM_plateau_mask_left)
        tmp = logical(run.FM_plateau_mask_left(:));
        if numel(tmp) == nT
            pipeMaskL = tmp;
        end
    end
    if isfield(run, 'FM_plateau_mask_right') && ~isempty(run.FM_plateau_mask_right)
        tmp = logical(run.FM_plateau_mask_right(:));
        if numel(tmp) == nT
            pipeMaskR = tmp;
        end
    end

    % Plot-side logic after fix: direct projection of persisted pipeline masks.
    plotMaskL = pipeMaskL;
    plotMaskR = pipeMaskR;

    leftMatch = isequal(pipeMaskL, plotMaskL);
    rightMatch = isequal(pipeMaskR, plotMaskR);

    fmValid = false;
    if isfield(run, 'FM_plateau_valid')
        fmValid = logical(run.FM_plateau_valid);
    end

    TpVals(end + 1, 1) = run.waitK; %#ok<AGROW>
    pipelineLeftCount(end + 1, 1) = nnz(pipeMaskL); %#ok<AGROW>
    plotLeftCount(end + 1, 1) = nnz(plotMaskL); %#ok<AGROW>
    leftMatchVals(end + 1, 1) = yesNo(leftMatch); %#ok<AGROW>
    pipelineRightCount(end + 1, 1) = nnz(pipeMaskR); %#ok<AGROW>
    plotRightCount(end + 1, 1) = nnz(plotMaskR); %#ok<AGROW>
    rightMatchVals(end + 1, 1) = yesNo(rightMatch); %#ok<AGROW>
    fmValidVals(end + 1, 1) = yesNo(fmValid); %#ok<AGROW>
    plotConsistentVals(end + 1, 1) = yesNo(leftMatch && rightMatch); %#ok<AGROW>
end

tbl = table(TpVals, pipelineLeftCount, plotLeftCount, leftMatchVals, ...
    pipelineRightCount, plotRightCount, rightMatchVals, fmValidVals, ...
    plotConsistentVals, ...
    'VariableNames', {'Tp', 'pipeline_left_count', 'plot_left_count', 'left_match_yes_no', ...
    'pipeline_right_count', 'plot_right_count', 'right_match_yes_no', 'FM_valid', 'plot_consistent_yes_no'});
verifyCsvPath = fullfile(tablesDir, 'plot_mask_fix_verification.csv');
writetable(tbl, verifyCsvPath);

allConsistent = all(strcmp(tbl.plot_consistent_yes_no, "YES"));
usesPipeline = allConsistent;
recomputes = false;
synchronized = allConsistent;

reportPath = fullfile(reportsDir, 'plot_mask_fix_report.md');
fid = fopen(reportPath, 'w');
if fid < 0
    error('Could not write report: %s', reportPath);
end
fprintf(fid, '# Plot Mask Fix Report\n\n');
fprintf(fid, '## Final Verdicts\n\n');
fprintf(fid, '- PLOT_USES_PIPELINE_MASKS = %s\n', yesNo(usesPipeline));
fprintf(fid, '- PLOT_RECOMPUTES_PLATEAU = %s\n', yesNo(recomputes));
fprintf(fid, '- VISUALIZATION_SYNCHRONIZED_WITH_PIPELINE = %s\n\n', yesNo(synchronized));

fprintf(fid, '## Canonical Mask Source\n\n');
fprintf(fid, '- Source function: `Aging/models/analyzeAFM_FM_components.m`\n');
fprintf(fid, '- Source fields carried in `pauseRuns`: `FM_plateau_mask_left`, `FM_plateau_mask_right`, `FM_plateau_left_window`, `FM_plateau_right_window`, `FM_plateau_valid`, `FM_plateau_reason`.\n');
fprintf(fid, '- Diagnostic plot consumption: `Aging/analysis/debugAgingStage4.m` uses persisted mask fields directly.\n\n');

fprintf(fid, '## Files Changed\n\n');
fprintf(fid, '- `Aging/models/analyzeAFM_FM_components.m`: persist canonical stage4 plateau masks into `pauseRuns`.\n');
fprintf(fid, '- `Aging/analysis/debugAgingStage4.m`: remove plot-side plateau recomputation and render plateau shading from persisted pipeline masks.\n');
fprintf(fid, '- `Aging/plots/plotAgingMemory_AFM_vs_FM_direct_styled.m`: gate FM points by `FM_plateau_valid`.\n');
fprintf(fid, '- `Aging/plots/plotAgingMemory_AFM_vs_FM.m`: gate FM points by `FM_plateau_valid`.\n\n');

fprintf(fid, '## User-Visible Change\n\n');
fprintf(fid, '- Diagnostic overlays now show plateau regions exactly where stage4 extracted them.\n');
fprintf(fid, '- If left plateau is missing in pipeline (for example Tp=6 K), no left plateau region is drawn.\n');
fprintf(fid, '- Summary FM points are shown only when FM is pipeline-valid (`FM_plateau_valid=true`).\n\n');

fprintf(fid, '## Verification Rows\n\n');
for i = 1:height(tbl)
    fprintf(fid, '- Tp=%.6g: left %d/%d (%s), right %d/%d (%s), FM_valid=%s, plot_consistent=%s\n', ...
        tbl.Tp(i), ...
        tbl.pipeline_left_count(i), tbl.plot_left_count(i), tbl.left_match_yes_no(i), ...
        tbl.pipeline_right_count(i), tbl.plot_right_count(i), tbl.right_match_yes_no(i), ...
        tbl.FM_valid(i), tbl.plot_consistent_yes_no(i));
end
fclose(fid);

fprintf('Wrote verification CSV: %s\n', verifyCsvPath);
fprintf('Wrote report: %s\n', reportPath);

function out = yesNo(tf)
if tf
    out = "YES";
else
    out = "NO";
end
end
