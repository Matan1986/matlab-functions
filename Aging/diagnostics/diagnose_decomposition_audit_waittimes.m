% diagnose_decomposition_audit_waittimes
% Diagnostics-only audit of AFM/FM decomposition across wait-time datasets.
% No pipeline/reconstruction logic is modified.

% ------------------------------
% Setup
% ------------------------------
thisFile = mfilename('fullpath');
thisDir = fileparts(thisFile);
agingRoot = fileparts(thisDir);
repoRoot = fileparts(agingRoot);

addpath(genpath(agingRoot));

outDir = getResultsDir('aging', 'decomposition', 'decomposition_audit');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

datasets = {
    'MG119_3sec',  '3s';
    'MG119_36sec', '36s';
    'MG119_6min',  '6min';
    'MG119_60min', '60min'
};

% Keep consistent with stage5 fit window settings
fitWindowFactor = 4;
fitMinWindowK = 25;

for d = 1:size(datasets,1)
    datasetKey = datasets{d,1};
    tag = datasets{d,2};

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
    state = stage1_loadData(cfg);
    state = stage2_preprocess(state, cfg);
    state = stage3_computeDeltaM(state, cfg);
    state = stage4_analyzeAFM_FM(state, cfg);
    state = stage5_fitFMGaussian(state, cfg);

    pauseRuns = getPauseRuns(state);
    nPauses = numel(pauseRuns);

    % ------------------------------
    % Build CSV rows
    % ------------------------------
    wait_time_col = strings(0,1);
    pause_col = nan(0,1);
    T_col = nan(0,1);
    DeltaM_col = nan(0,1);
    AFM_col = nan(0,1);
    FM_col = nan(0,1);
    Recon_col = nan(0,1);

    left_col = false(0,1);
    right_col = false(0,1);
    afm_fit_col = false(0,1);
    fm_fit_col = false(0,1);
    valid_col = false(0,1);

    % ------------------------------
    % Figure: one row per pause, 4 panels
    % ------------------------------
    figH = figure('Color', 'w', 'Visible', 'off', ...
        'Position', [50 50 1900 max(420, 280*nPauses)]);
    tl = tiledlayout(nPauses, 4, 'TileSpacing', 'compact', 'Padding', 'compact'); %#ok<NASGU>

    for i = 1:nPauses
        pr = pauseRuns(i);

        T = getFieldOrEmpty(pr, 'T_common');
        if isempty(T)
            T = getFieldOrEmpty(pr, 'T');
        end
        T = T(:);

        dM = getFieldOrEmpty(pr, 'DeltaM');
        dM = dM(:);

        dM_smooth = getFieldOrEmpty(pr, 'DeltaM_smooth');
        dM_smooth = dM_smooth(:);

        dM_sharp = getFieldOrEmpty(pr, 'DeltaM_sharp');
        dM_sharp = dM_sharp(:);

        fit_curve = getFieldOrEmpty(pr, 'fit_curve');
        fit_curve = fit_curve(:);

        n = min([numel(T), numel(dM), numel(dM_smooth), numel(dM_sharp)]);
        if n == 0
            continue;
        end

        T = T(1:n);
        dM = dM(1:n);
        dM_smooth = dM_smooth(1:n);
        dM_sharp = dM_sharp(1:n);

        % Raw DeltaM from pauseRuns_raw if available
        dM_raw = dM;
        if isfield(state, 'pauseRuns_raw') && numel(state.pauseRuns_raw) >= i
            rawRun = state.pauseRuns_raw(i);
            rawT = getFieldOrEmpty(rawRun, 'T_common');
            rawDM = getFieldOrEmpty(rawRun, 'DeltaM');
            if numel(rawT) == numel(rawDM) && numel(rawT) == n
                if all(abs(rawT(:) - T(:)) < 1e-9 | (~isfinite(rawT(:)) & ~isfinite(T(:))))
                    dM_raw = rawDM(:);
                end
            end
        end

        % Stage5 Gaussian dip fit and FM fit (derived)
        if numel(fit_curve) >= n
            fit_curve = fit_curve(1:n);
        else
            fit_curve = nan(n,1);
        end

        DipA = getScalarOrNaN(pr, 'Dip_A');
        DipSigma = getScalarOrNaN(pr, 'Dip_sigma');
        DipT0 = getScalarOrNaN(pr, 'Dip_T0');

        AFM_fit = nan(n,1);
        FM_fit = nan(n,1);
        if isfinite(DipA) && isfinite(DipSigma) && DipSigma > 0 && isfinite(DipT0) && any(isfinite(fit_curve))
            AFM_fit = -DipA * exp(-(T - DipT0).^2 ./ (2*DipSigma^2));
            FM_fit = fit_curve - AFM_fit;
        end

        recon_sum = fit_curve;
        if ~any(isfinite(recon_sum))
            recon_sum = dM_smooth + dM_sharp;
        end

        Tp = getScalarOrNaN(pr, 'waitK');

        [dipWin, baseLWin, baseRWin, gaussWin] = computeWindows(T, Tp, cfg, fitWindowFactor, fitMinWindowK);

        is_left_baseline = inWindow(T, baseLWin);
        is_right_baseline = inWindow(T, baseRWin);
        is_AFM_fit_region = inWindow(T, dipWin);
        is_FM_fit_region = is_left_baseline | is_right_baseline;
        is_valid_region = isfinite(dM) & isfinite(dM_sharp) & isfinite(dM_smooth);

        % CSV accumulation
        m = numel(T);
        wait_time_col = [wait_time_col; repmat(string(tag), m, 1)]; %#ok<AGROW>
        pause_col = [pause_col; repmat(Tp, m, 1)]; %#ok<AGROW>
        T_col = [T_col; T]; %#ok<AGROW>
        DeltaM_col = [DeltaM_col; dM]; %#ok<AGROW>
        AFM_col = [AFM_col; dM_sharp]; %#ok<AGROW>
        FM_col = [FM_col; dM_smooth]; %#ok<AGROW>
        Recon_col = [Recon_col; recon_sum]; %#ok<AGROW>

        left_col = [left_col; logical(is_left_baseline)]; %#ok<AGROW>
        right_col = [right_col; logical(is_right_baseline)]; %#ok<AGROW>
        afm_fit_col = [afm_fit_col; logical(is_AFM_fit_region)]; %#ok<AGROW>
        fm_fit_col = [fm_fit_col; logical(is_FM_fit_region)]; %#ok<AGROW>
        valid_col = [valid_col; logical(is_valid_region)]; %#ok<AGROW>

        % ------------------------------
        % Panel 1: raw DeltaM
        % ------------------------------
        nexttile;
        plot(T, dM_raw, 'k.-', 'LineWidth', 1.0, 'MarkerSize', 9); hold on;
        plot(T, dM, '-', 'Color', [0 0.45 0.74], 'LineWidth', 1.2);
        grid on;
        xlabel('T (K)'); ylabel('\DeltaM');
        title(sprintf('Raw | Tp=%.1f K', Tp));
        legend({'raw','filtered'}, 'Location', 'best');

        % ------------------------------
        % Panel 2: decomposition overlays
        % ------------------------------
        nexttile;
        h2 = gobjects(0);
        l2 = {};
        h2(end+1) = plot(T, dM, 'k-', 'LineWidth', 1.1); hold on;
        l2{end+1} = '\DeltaM';
        h2(end+1) = plot(T, dM_sharp, '-', 'Color', [0.85 0.33 0.10], 'LineWidth', 1.1);
        l2{end+1} = 'AFM component';
        h2(end+1) = plot(T, dM_smooth, '-', 'Color', [0 0.6 0], 'LineWidth', 1.1);
        l2{end+1} = 'FM component';
        h2(end+1) = plot(T, recon_sum, '--', 'Color', [0.49 0.18 0.56], 'LineWidth', 1.5);
        l2{end+1} = 'AFM+FM sum';
        if any(isfinite(AFM_fit))
            h2(end+1) = plot(T, AFM_fit, ':', 'Color', [0.85 0.33 0.10], 'LineWidth', 1.2);
            l2{end+1} = 'AFM fit';
        end
        if any(isfinite(FM_fit))
            h2(end+1) = plot(T, FM_fit, ':', 'Color', [0 0.6 0], 'LineWidth', 1.2);
            l2{end+1} = 'FM fit';
        end
        grid on;
        xlabel('T (K)'); ylabel('Component amplitude');
        title('DeltaM + AFM/FM overlays');
        legend(h2, l2, 'Location', 'best');

        % ------------------------------
        % Panel 3: AFM and FM together
        % ------------------------------
        nexttile;
        plot(T, dM_sharp, 'o-', 'Color', [0.85 0.33 0.10], 'LineWidth', 1.1, 'MarkerSize', 4); hold on;
        plot(T, dM_smooth, 's-', 'Color', [0 0.6 0], 'LineWidth', 1.1, 'MarkerSize', 4);
        grid on;
        xlabel('T (K)'); ylabel('Amplitude');
        title('AFM(T) vs FM(T)');
        legend({'AFM component','FM component'}, 'Location', 'best');

        % ------------------------------
        % Panel 4: decomposition regions
        % ------------------------------
        nexttile;
        h4 = gobjects(0);
        l4 = {};
        h4(end+1) = plot(T, dM, 'k-', 'LineWidth', 1.1); hold on;
        l4{end+1} = '\DeltaM';
        yl = ylim;

        hTmp = patchWindow(baseLWin, yl, [0.2 0.8 0.2], 0.16);
        if isgraphics(hTmp)
            h4(end+1) = hTmp; l4{end+1} = 'left baseline';
        end
        hTmp = patchWindow(baseRWin, yl, [0.2 0.8 0.2], 0.16);
        if isgraphics(hTmp)
            h4(end+1) = hTmp; l4{end+1} = 'right baseline';
        end
        hTmp = patchWindow(dipWin, yl, [0.95 0.2 0.2], 0.14);
        if isgraphics(hTmp)
            h4(end+1) = hTmp; l4{end+1} = 'AFM fit window';
        end
        hTmp = patchWindow(gaussWin, yl, [0.2 0.4 0.95], 0.10);
        if isgraphics(hTmp)
            h4(end+1) = hTmp; l4{end+1} = 'Gaussian fit window';
        end

        if isfield(cfg, 'excludeLowT_FM') && cfg.excludeLowT_FM && isfield(cfg, 'excludeLowT_K')
            exWin = [min(T(isfinite(T))), cfg.excludeLowT_K];
            hTmp = patchWindow(exWin, yl, [0.5 0.5 0.5], 0.10);
            if isgraphics(hTmp)
                h4(end+1) = hTmp; l4{end+1} = 'excluded/masked';
            end
        end

        h4(end+1) = xline(Tp, ':k', 'Tp');
        l4{end+1} = 'Tp';
        grid on;
        xlabel('T (K)'); ylabel('\DeltaM');
        title('Regions/masks used for decomposition');
        legend(h4, l4, 'Location', 'best');
    end

    sgtitle(sprintf('Decomposition Audit | %s', datasetKey), 'Interpreter', 'none');

    figPath = fullfile(outDir, sprintf('decomposition_audit_%s.png', tag));
    saveas(figH, figPath);
    close(figH);

    tbl = table( ...
        wait_time_col, pause_col, T_col, DeltaM_col, AFM_col, FM_col, Recon_col, ...
        left_col, right_col, afm_fit_col, fm_fit_col, valid_col, ...
        'VariableNames', { ...
        'wait_time','pause_K','T','DeltaM','AFM_component','FM_component','reconstructed_sum', ...
        'is_left_baseline','is_right_baseline','is_AFM_fit_region','is_FM_fit_region','is_valid_region'});

    csvPath = fullfile(outDir, sprintf('decomposition_audit_%s.csv', tag));
    writetable(tbl, csvPath);

    fprintf('Saved %s and %s\n', figPath, csvPath);
end

% ------------------------------
% Local helpers
% ------------------------------
function x = getFieldOrEmpty(s, fieldName)
if isfield(s, fieldName)
    x = s.(fieldName);
else
    x = [];
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

function [dipWin, baseLWin, baseRWin, gaussWin] = computeWindows(T, Tp, cfg, fitWindowFactor, fitMinWindowK)
Tfin = T(isfinite(T));
if isempty(Tfin)
    Tmin = -inf;
    Tmax = inf;
else
    Tmin = min(Tfin);
    Tmax = max(Tfin);
end

if ~isfinite(Tp)
    dipWin = [NaN NaN];
    baseLWin = [NaN NaN];
    baseRWin = [NaN NaN];
    gaussWin = [NaN NaN];
    return;
end

dipWin = [Tp - cfg.dip_window_K, Tp + cfg.dip_window_K];
baseLWin = [Tp - cfg.dip_window_K - cfg.FM_buffer_K - cfg.FM_plateau_K, ...
            Tp - cfg.dip_window_K - cfg.FM_buffer_K];

if isfield(cfg, 'FM_rightPlateauMode') && strcmpi(cfg.FM_rightPlateauMode, 'fixed')
    baseRWin = cfg.FM_rightPlateauFixedWindow_K(:).';
else
    baseRWin = [Tp + cfg.dip_window_K + cfg.FM_buffer_K, ...
                Tp + cfg.dip_window_K + cfg.FM_buffer_K + cfg.FM_plateau_K];
end

W = max(fitMinWindowK, fitWindowFactor * cfg.dip_window_K);
gaussWin = [Tp - W, Tp + W];

% Clamp to available data range for robust plotting/masks
dipWin = clampWindow(dipWin, Tmin, Tmax);
baseLWin = clampWindow(baseLWin, Tmin, Tmax);
baseRWin = clampWindow(baseRWin, Tmin, Tmax);
gaussWin = clampWindow(gaussWin, Tmin, Tmax);
end

function mask = inWindow(T, win)
if isempty(win) || numel(win) ~= 2 || any(~isfinite(win))
    mask = false(size(T));
    return;
end
lo = min(win);
hi = max(win);
mask = isfinite(T) & (T >= lo) & (T <= hi);
end

function win = clampWindow(win, Tmin, Tmax)
if isempty(win) || numel(win) ~= 2 || any(~isfinite(win)) || ~isfinite(Tmin) || ~isfinite(Tmax)
    return;
end
lo = max(min(win), Tmin);
hi = min(max(win), Tmax);
win = [lo hi];
end

function h = patchWindow(win, yl, colorRGB, alphaVal)
h = gobjects(0);
if isempty(win) || numel(win) ~= 2 || any(~isfinite(win)) || win(2) <= win(1)
    return;
end
h = patch([win(1) win(2) win(2) win(1)], [yl(1) yl(1) yl(2) yl(2)], colorRGB, ...
      'FaceAlpha', alphaVal, 'EdgeColor', 'none');
end




