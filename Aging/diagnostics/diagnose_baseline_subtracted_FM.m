function summaryTbl = diagnose_baseline_subtracted_FM()
% diagnose_baseline_subtracted_FM
% Diagnostics-only test for FM robustness against linear baseline removal.
% No pipeline metric formulas are modified.

thisFile = mfilename('fullpath');
thisDir = fileparts(thisFile);
agingRoot = fileparts(thisDir);
repoRoot = fileparts(agingRoot);

addpath(genpath(agingRoot));

outDir = getResultsDir('aging', 'baseline_tests', 'baseline_subtracted_FM');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

datasets = {
    'MG119_3sec',  '3 s',   '3s';
    'MG119_36sec', '36 s',  '36s';
    'MG119_6min',  '6 min', '6min';
    'MG119_60min', '60 min','60min'
};

summary_wait = strings(0,1);
summary_tp = nan(0,1);
summary_fm_e_orig = nan(0,1);
summary_fm_e_res = nan(0,1);
summary_slope = nan(0,1);

for d = 1:size(datasets, 1)
    datasetKey = datasets{d,1};
    waitLabel = datasets{d,2};
    waitTag = datasets{d,3};

    cfg = agingConfig(datasetKey);
    cfg.doPlotting = false;
    cfg.saveTableMode = 'none';
    if isfield(cfg, 'debug') && isstruct(cfg.debug)
        cfg.debug.enable = false;
        cfg.debug.plotGeometry = false;
        cfg.debug.plotSwitching = false;
        cfg.debug.saveOutputs = false;
    end

    cfg = stage0_setupPaths(cfg);
    stateBase = stage1_loadData(cfg);
    stateBase = stage2_preprocess(stateBase, cfg);
    stateBase = stage3_computeDeltaM(stateBase, cfg);

    stateOrig = stateBase;
    stateOrig = stage4_analyzeAFM_FM(stateOrig, cfg);
    stateOrig = stage5_fitFMGaussian(stateOrig, cfg);
    pauseOrig = getPauseRuns(stateOrig);

    stateRes = stateBase;
    [stateRes.pauseRuns, baseDiag] = subtractLinearBaselineFromRuns(stateRes.pauseRuns);
    [stateRes.pauseRuns_raw, ~] = subtractLinearBaselineFromRuns(stateRes.pauseRuns_raw);
    stateRes = stage4_analyzeAFM_FM(stateRes, cfg);
    stateRes = stage5_fitFMGaussian(stateRes, cfg);
    pauseRes = getPauseRuns(stateRes);

    for i = 1:numel(baseDiag)
        Tp = baseDiag(i).Tp;
        if ~isfinite(Tp)
            continue;
        end

        idxOrig = findRunByTp(pauseOrig, Tp, 1e-6);
        idxRes = findRunByTp(pauseRes, Tp, 1e-6);
        if isempty(idxOrig) || isempty(idxRes)
            continue;
        end

        runOrig = pauseOrig(idxOrig);
        runRes = pauseRes(idxRes);

        summary_wait(end+1,1) = string(waitLabel); %#ok<AGROW>
        summary_tp(end+1,1) = Tp; %#ok<AGROW>
        summary_fm_e_orig(end+1,1) = getScalarOrNaN(runOrig, 'FM_E'); %#ok<AGROW>
        summary_fm_e_res(end+1,1) = getScalarOrNaN(runRes, 'FM_E'); %#ok<AGROW>
        summary_slope(end+1,1) = baseDiag(i).slope; %#ok<AGROW>

        makeComparisonFigure(baseDiag(i), waitTag, outDir);
    end
end

summaryTbl = table( ...
    summary_tp, summary_wait, summary_fm_e_orig, summary_fm_e_res, summary_slope, ...
    'VariableNames', {'Tp','wait_time','FM_E_original','FM_E_baseline_subtracted','baseline_slope'});

csvPath = fullfile(outDir, 'FM_baseline_test.csv');
writetable(summaryTbl, csvPath);
fprintf('Saved %s\n', csvPath);
fprintf('Saved figures in %s\n', outDir);
end

function [runsOut, diagOut] = subtractLinearBaselineFromRuns(runsIn)
runsOut = runsIn;
diagOut = repmat(struct( ...
    'Tp', NaN, ...
    'T', [], ...
    'DeltaM', [], ...
    'baseline', [], ...
    'DeltaM_res', [], ...
    'slope', NaN, ...
    'intercept', NaN), numel(runsIn), 1);

for i = 1:numel(runsIn)
    T = getTempVector(runsIn(i));
    dM = getDeltaMVector(runsIn(i));
    Tp = getScalarOrNaN(runsIn(i), 'waitK');

    diagOut(i).Tp = Tp;
    diagOut(i).T = T;
    diagOut(i).DeltaM = dM;

    n = min(numel(T), numel(dM));
    if n < 2
        continue;
    end

    T = T(1:n);
    dM = dM(1:n);
    valid = isfinite(T) & isfinite(dM);
    if nnz(valid) < 2
        continue;
    end

    p = polyfit(T(valid), dM(valid), 1);
    baseline = polyval(p, T);
    dMres = dM - baseline;

    diagOut(i).T = T;
    diagOut(i).DeltaM = dM;
    diagOut(i).baseline = baseline;
    diagOut(i).DeltaM_res = dMres;
    diagOut(i).slope = p(1);
    diagOut(i).intercept = p(2);

    if isfield(runsOut(i), 'DeltaM') && ~isempty(runsOut(i).DeltaM)
        runsOut(i).DeltaM = dMres;
    end
    if isfield(runsOut(i), 'DeltaM_aligned') && ~isempty(runsOut(i).DeltaM_aligned)
        m = min(numel(runsOut(i).DeltaM_aligned), numel(dMres));
        x = runsOut(i).DeltaM_aligned(:);
        x(1:m) = dMres(1:m);
        runsOut(i).DeltaM_aligned = x;
    end
end
end

function makeComparisonFigure(diagRun, waitTag, outDir)
T = diagRun.T(:);
dM = diagRun.DeltaM(:);
baseline = diagRun.baseline(:);
dMres = diagRun.DeltaM_res(:);
Tp = diagRun.Tp;

n = min([numel(T), numel(dM), numel(baseline), numel(dMres)]);
if n < 2
    return;
end
T = T(1:n);
dM = dM(1:n);
baseline = baseline(1:n);
dMres = dMres(1:n);

figH = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1650 520]);
tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
h1 = gobjects(0);
l1 = {};
h1(end+1) = plot(T, dM, '-', 'Color', [0 0.45 0.74], 'LineWidth', 1.6); hold on;
l1{end+1} = 'DeltaM(T)';
h1(end+1) = plot(T, baseline, '--', 'Color', [0.85 0.33 0.10], 'LineWidth', 1.5);
l1{end+1} = 'Linear baseline';
grid on;
xlabel('T (K)');
ylabel('\DeltaM');
title(sprintf('Original | T_p=%.1f K', Tp));
lg = legend(h1, l1, 'Location', 'bestoutside');
lg.FontSize = 9;
lg.Box = 'off';

nexttile;
h2 = plot(T, dMres, '-', 'Color', [0.1 0.6 0.1], 'LineWidth', 1.6); hold on;
yline(0, ':k', 'LineWidth', 1.0, 'HandleVisibility', 'off');
grid on;
xlabel('T (K)');
ylabel('\DeltaM_{res}');
title('Baseline-subtracted');
lg = legend(h2, {'\DeltaM_{res}(T)'}, 'Location', 'bestoutside');
lg.FontSize = 9;
lg.Box = 'off';

nexttile;
h3 = gobjects(0);
l3 = {};
h3(end+1) = plot(T, dM, '-', 'Color', [0 0.45 0.74], 'LineWidth', 1.5); hold on;
l3{end+1} = 'DeltaM(T)';
h3(end+1) = plot(T, dMres, '-', 'Color', [0.1 0.6 0.1], 'LineWidth', 1.5);
l3{end+1} = 'DeltaM_{res}(T)';
grid on;
xlabel('T (K)');
ylabel('Amplitude');
title('Overlay');
lg = legend(h3, l3, 'Location', 'bestoutside');
lg.FontSize = 9;
lg.Box = 'off';

sgtitle(sprintf('Baseline Subtraction FM Diagnostic | wait=%s | slope=%.4g', waitTag, diagRun.slope));

tpTag = formatTpTag(Tp);
outPng = fullfile(outDir, sprintf('baseline_subtracted_%s_wait_%s.png', tpTag, waitTag));
saveas(figH, outPng);
close(figH);
end

function idx = findRunByTp(pauseRuns, Tp, tol)
idx = [];
if isempty(pauseRuns)
    return;
end
tpVals = arrayfun(@(r) getScalarOrNaN(r, 'waitK'), pauseRuns);
idx = find(isfinite(tpVals) & abs(tpVals - Tp) <= tol, 1, 'first');
end

function T = getTempVector(run)
T = [];
if isfield(run, 'T_common') && ~isempty(run.T_common)
    T = run.T_common(:);
elseif isfield(run, 'T') && ~isempty(run.T)
    T = run.T(:);
end
end

function dM = getDeltaMVector(run)
dM = [];
if isfield(run, 'DeltaM') && ~isempty(run.DeltaM)
    dM = run.DeltaM(:);
elseif isfield(run, 'DeltaM_aligned') && ~isempty(run.DeltaM_aligned)
    dM = run.DeltaM_aligned(:);
end
end

function v = getScalarOrNaN(s, fieldName)
v = NaN;
if isfield(s, fieldName)
    x = s.(fieldName);
    if ~isempty(x) && isscalar(x) && isfinite(x)
        v = x;
    end
end
end

function tpTag = formatTpTag(tp)
tpTag = sprintf('Tp_%0.1fK', tp);
tpTag = strrep(tpTag, '.', 'p');
tpTag = strrep(tpTag, '-', 'm');
end
