% diagnose_deltaM_shifted_byTp_waittimes
% Diagnostics-only plot: DeltaM vs (T - Tp) across wait-time datasets.
% No decomposition/reconstruction algorithms are modified.

thisFile = mfilename('fullpath');
thisDir = fileparts(thisFile);
agingRoot = fileparts(thisDir);
repoRoot = fileparts(agingRoot);

addpath(genpath(agingRoot));

outDir = getResultsDir('aging', 'decomposition', 'deltaM_shifted_byTp_waittimes');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

datasets = {
    'MG119_3sec',  '3 s';
    'MG119_36sec', '36 s';
    'MG119_6min',  '6 min';
    'MG119_60min', '60 min'
};

useNormalizedPanel = true;
tpTol = 1e-6;

dataStore = repmat(struct('key', '', 'label', '', 'pauseRuns', [], 'Tp', []), size(datasets, 1), 1);
colorScheme = 'thermal';

for d = 1:size(datasets, 1)
    datasetKey = datasets{d, 1};
    waitLabel = datasets{d, 2};

    cfg = agingConfig(datasetKey);
    cfg.doPlotting = false;
    cfg.saveTableMode = 'none';

    if isfield(cfg, 'color_scheme') && ~isempty(cfg.color_scheme)
        colorScheme = cfg.color_scheme;
    end

    if isfield(cfg, 'debug') && isstruct(cfg.debug)
        cfg.debug.enable = false;
        cfg.debug.plotGeometry = false;
        cfg.debug.plotSwitching = false;
        cfg.debug.saveOutputs = false;
    end

    cfg = stage0_setupPaths(cfg);
    state = stage1_loadData(cfg);
    state = stage2_preprocess(state, cfg);
    state = stage3_computeDeltaM(state, cfg);

    pauseRuns = getPauseRuns(state);
    tpVals = [pauseRuns.waitK];
    tpVals = tpVals(isfinite(tpVals));

    dataStore(d).key = datasetKey;
    dataStore(d).label = waitLabel;
    dataStore(d).pauseRuns = pauseRuns;
    dataStore(d).Tp = tpVals(:).';
end

commonTp = dataStore(1).Tp;
for d = 2:numel(dataStore)
    commonTp = intersectTol(commonTp, dataStore(d).Tp, tpTol);
end
commonTp = sort(commonTp);

if isempty(commonTp)
    warning('No common pause temperatures were found across wait-time datasets.');
    return;
end

cols = pickColors(numel(dataStore), colorScheme);

for k = 1:numel(commonTp)
    TpTarget = commonTp(k);

    if useNormalizedPanel
        figH = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1500 560]);
        tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    else
        figH = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 820 620]);
    end

    if useNormalizedPanel
        axRaw = nexttile;
    else
        axRaw = axes(figH);
    end
    hold(axRaw, 'on');
    grid(axRaw, 'on');

    if useNormalizedPanel
        axNorm = nexttile;
        hold(axNorm, 'on');
        grid(axNorm, 'on');
    else
        axNorm = [];
    end

    for d = 1:numel(dataStore)
        pr = getPauseRunByTp(dataStore(d).pauseRuns, TpTarget, tpTol);
        if isempty(pr)
            continue;
        end

        [T, dM] = extractDeltaMCurve(pr);
        if isempty(T) || isempty(dM)
            continue;
        end

        n = min(numel(T), numel(dM));
        T = T(1:n);
        dM = dM(1:n);

        valid = isfinite(T) & isfinite(dM);
        if ~any(valid)
            continue;
        end

        x = T(valid) - TpTarget;
        y = dM(valid);

        plot(axRaw, x, y, '-', 'Color', cols(d, :), 'LineWidth', 1.8, ...
            'DisplayName', dataStore(d).label);

        if useNormalizedPanel
            yScale = max(abs(y));
            if isfinite(yScale) && yScale > 0
                yNorm = y / yScale;
            else
                yNorm = nan(size(y));
            end
            plot(axNorm, x, yNorm, '-', 'Color', cols(d, :), 'LineWidth', 1.8, ...
                'DisplayName', dataStore(d).label);
        end
    end

    xline(axRaw, 0, '--k', 'LineWidth', 1.1, 'HandleVisibility', 'off');
    xlabel(axRaw, 'T - T_p (K)');
    ylabel(axRaw, '\DeltaM');
    title(axRaw, sprintf('\\DeltaM vs (T - T_p), T_p = %.1f K', TpTarget));
    lgRaw = legend(axRaw, 'Location', 'bestoutside');
    lgRaw.FontSize = 10;
    lgRaw.Box = 'off';

    if useNormalizedPanel
        xline(axNorm, 0, '--k', 'LineWidth', 1.1, 'HandleVisibility', 'off');
        xlabel(axNorm, 'T - T_p (K)');
        ylabel(axNorm, '\DeltaM / max(|\DeltaM|)');
        title(axNorm, sprintf('Normalized, T_p = %.1f K', TpTarget));
        lgNorm = legend(axNorm, 'Location', 'bestoutside');
        lgNorm.FontSize = 10;
        lgNorm.Box = 'off';
    end

    sgtitle(sprintf('Shifted-Temperature Aging Diagnostic | T_p = %.1f K', TpTarget));

    tpTag = formatTpTag(TpTarget);
    outPng = fullfile(outDir, sprintf('DeltaM_shifted_byTp_%s.png', tpTag));
    saveas(figH, outPng);
    close(figH);

    fprintf('Saved %s\n', outPng);
end

fprintf('Shifted-temperature diagnostics saved to: %s\n', outDir);

function [T, dM] = extractDeltaMCurve(pr)
T = [];
dM = [];

if isfield(pr, 'T_common') && ~isempty(pr.T_common)
    T = pr.T_common(:);
elseif isfield(pr, 'T') && ~isempty(pr.T)
    T = pr.T(:);
end

if isfield(pr, 'DeltaM_aligned') && ~isempty(pr.DeltaM_aligned)
    dM = pr.DeltaM_aligned(:);
elseif isfield(pr, 'DeltaM') && ~isempty(pr.DeltaM)
    dM = pr.DeltaM(:);
end
end

function pr = getPauseRunByTp(pauseRuns, tpTarget, tol)
pr = [];
if isempty(pauseRuns)
    return;
end
tpVals = [pauseRuns.waitK];
idx = find(isfinite(tpVals) & abs(tpVals - tpTarget) <= tol, 1, 'first');
if ~isempty(idx)
    pr = pauseRuns(idx);
end
end

function c = intersectTol(a, b, tol)
a = unique(a(:).');
b = unique(b(:).');
c = [];
for i = 1:numel(a)
    if any(abs(b - a(i)) <= tol)
        c(end+1) = a(i); %#ok<AGROW>
    end
end
c = unique(c);
end

function tag = formatTpTag(tp)
tag = sprintf('Tp_%0.1fK', tp);
tag = strrep(tag, '.', 'p');
tag = strrep(tag, '-', 'm');
end

function cols = pickColors(n, scheme)
n = max(n, 3);

switch lower(string(scheme))
    case "parula"
        cols = parula(n);
    case "jet"
        cols = jet(n);
    case "lines"
        cols = lines(n);
    case "thermal"
        try
            cols = cmocean('thermal', n);
        catch
            cols = parula(n);
        end
    otherwise
        cols = parula(n);
end
end

