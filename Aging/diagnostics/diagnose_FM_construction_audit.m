% diagnose_FM_construction_audit
% Diagnostics-only transparency audit of FM component construction.
% No pipeline/decomposition/reconstruction logic is modified.

% ------------------------------
% Setup
% ------------------------------
thisFile = mfilename('fullpath');
thisDir = fileparts(thisFile);
agingRoot = fileparts(thisDir);
repoRoot = fileparts(agingRoot);

addpath(genpath(agingRoot));

outDir = getResultsDir('aging', 'decomposition', 'FM_construction_audit');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

datasets = {
    'MG119_3sec',  '3 s',   '3s';
    'MG119_36sec', '36 s',  '36s';
    'MG119_6min',  '6 min', '6min';
    'MG119_60min', '60 min','60min'
};

fitWindowFactor = 4;  % stage5 default
fitMinWindowK = 25;   % stage5 default

% ------------------------------
% Global accumulators
% ------------------------------
main_wait = strings(0,1);
main_pauseT = nan(0,1);
main_T = nan(0,1);
main_DeltaM = nan(0,1);
main_DeltaM_smooth = nan(0,1);
main_AFM = nan(0,1);
main_FM = nan(0,1);
main_recon = nan(0,1);

main_is_left = false(0,1);
main_is_right = false(0,1);
main_is_afm = false(0,1);
main_is_fm = false(0,1);
main_is_valid = false(0,1);

main_left_mean = nan(0,1);
main_left_std = nan(0,1);
main_left_tmin = nan(0,1);
main_left_tmax = nan(0,1);

main_right_mean = nan(0,1);
main_right_std = nan(0,1);
main_right_tmin = nan(0,1);
main_right_tmax = nan(0,1);

main_FM_raw = nan(0,1);
main_FM_interp = nan(0,1);
main_FM_method = strings(0,1);

amp_wait = strings(0,1);
amp_pauseT = nan(0,1);
amp_low = nan(0,1);
amp_high = nan(0,1);
amp_step = nan(0,1);
amp_method = strings(0,1);

reg_wait = strings(0,1);
reg_pauseT = nan(0,1);
reg_left_exists = false(0,1);
reg_left_tmin = nan(0,1);
reg_left_tmax = nan(0,1);
reg_right_exists = false(0,1);
reg_right_tmin = nan(0,1);
reg_right_tmax = nan(0,1);
reg_afm_tmin = nan(0,1);
reg_afm_tmax = nan(0,1);
reg_gauss_tmin = nan(0,1);
reg_gauss_tmax = nan(0,1);
reg_excl_tmin = nan(0,1);
reg_excl_tmax = nan(0,1);

for d = 1:size(datasets,1)
    datasetKey = datasets{d,1};
    waitLabel = datasets{d,2};
    tag = datasets{d,3};

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
    % Per-wait-time figure (one row per pause, five panels)
    % ------------------------------
    figH = figure('Color', 'w', 'Visible', 'off', ...
        'Position', [30 30 2800 max(520, 330*nPauses)]);
    tiledlayout(nPauses, 5, 'TileSpacing', 'compact', 'Padding', 'compact');

    for i = 1:nPauses
        pr = pauseRuns(i);

        T = getFieldOrEmpty(pr, 'T_common');
        if isempty(T), T = getFieldOrEmpty(pr, 'T'); end
        T = T(:);

        dM = getFieldOrEmpty(pr, 'DeltaM'); dM = dM(:);
        dM_smooth = getFieldOrEmpty(pr, 'DeltaM_smooth'); dM_smooth = dM_smooth(:);
        dM_sharp = getFieldOrEmpty(pr, 'DeltaM_sharp'); dM_sharp = dM_sharp(:);
        fit_curve = getFieldOrEmpty(pr, 'fit_curve'); fit_curve = fit_curve(:);

        n = min([numel(T), numel(dM), numel(dM_smooth), numel(dM_sharp)]);
        if n == 0
            continue;
        end

        T = T(1:n);
        dM = dM(1:n);
        dM_smooth = dM_smooth(1:n);
        dM_sharp = dM_sharp(1:n);

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

        if numel(fit_curve) >= n
            fit_curve = fit_curve(1:n);
        else
            fit_curve = nan(n,1);
        end

        Tp = getScalarOrNaN(pr, 'waitK');
        [dipWin, baseLWin, baseRWin, gaussWin, exclWin] = computeWindows(T, Tp, cfg, fitWindowFactor, fitMinWindowK);

        is_left = inWindow(T, baseLWin);
        is_right = inWindow(T, baseRWin);
        is_afm = inWindow(T, dipWin);
        is_fm = is_left | is_right;
        is_valid = isfinite(T) & isfinite(dM) & isfinite(dM_smooth) & isfinite(dM_sharp);

        [left_mean, left_std, left_tmin, left_tmax, left_exists, left_center] = baselineStats(T, dM_smooth, is_left);
        [right_mean, right_std, right_tmin, right_tmax, right_exists, right_center] = baselineStats(T, dM_smooth, is_right);

        FM_low_ref = left_mean;
        FM_high_ref = right_mean;
        FM_step = FM_high_ref - FM_low_ref;

        if left_exists && right_exists
            FM_method = "left_right_baseline_interp";
        elseif ~left_exists && right_exists
            FM_method = "right_only_extrapolation";
        elseif any(isfinite(fit_curve))
            FM_method = "fit_curve_background";
        else
            FM_method = "other";
        end

        FM_raw = dM_smooth;
        FM_interp = computeFMInterpolated(T, FM_method, left_center, right_center, left_mean, right_mean, fit_curve, pr);

        recon_sum = dM_sharp + dM_smooth;

        m = numel(T);
        main_wait = [main_wait; repmat(string(waitLabel), m, 1)]; %#ok<AGROW>
        main_pauseT = [main_pauseT; repmat(Tp, m, 1)]; %#ok<AGROW>
        main_T = [main_T; T]; %#ok<AGROW>
        main_DeltaM = [main_DeltaM; dM]; %#ok<AGROW>
        main_DeltaM_smooth = [main_DeltaM_smooth; dM_smooth]; %#ok<AGROW>
        main_AFM = [main_AFM; dM_sharp]; %#ok<AGROW>
        main_FM = [main_FM; dM_smooth]; %#ok<AGROW>
        main_recon = [main_recon; recon_sum]; %#ok<AGROW>

        main_is_left = [main_is_left; is_left]; %#ok<AGROW>
        main_is_right = [main_is_right; is_right]; %#ok<AGROW>
        main_is_afm = [main_is_afm; is_afm]; %#ok<AGROW>
        main_is_fm = [main_is_fm; is_fm]; %#ok<AGROW>
        main_is_valid = [main_is_valid; is_valid]; %#ok<AGROW>

        main_left_mean = [main_left_mean; repmat(left_mean, m, 1)]; %#ok<AGROW>
        main_left_std = [main_left_std; repmat(left_std, m, 1)]; %#ok<AGROW>
        main_left_tmin = [main_left_tmin; repmat(left_tmin, m, 1)]; %#ok<AGROW>
        main_left_tmax = [main_left_tmax; repmat(left_tmax, m, 1)]; %#ok<AGROW>

        main_right_mean = [main_right_mean; repmat(right_mean, m, 1)]; %#ok<AGROW>
        main_right_std = [main_right_std; repmat(right_std, m, 1)]; %#ok<AGROW>
        main_right_tmin = [main_right_tmin; repmat(right_tmin, m, 1)]; %#ok<AGROW>
        main_right_tmax = [main_right_tmax; repmat(right_tmax, m, 1)]; %#ok<AGROW>

        main_FM_raw = [main_FM_raw; FM_raw]; %#ok<AGROW>
        main_FM_interp = [main_FM_interp; FM_interp]; %#ok<AGROW>
        main_FM_method = [main_FM_method; repmat(FM_method, m, 1)]; %#ok<AGROW>

        amp_wait = [amp_wait; string(waitLabel)]; %#ok<AGROW>
        amp_pauseT = [amp_pauseT; Tp]; %#ok<AGROW>
        amp_low = [amp_low; FM_low_ref]; %#ok<AGROW>
        amp_high = [amp_high; FM_high_ref]; %#ok<AGROW>
        amp_step = [amp_step; FM_step]; %#ok<AGROW>
        amp_method = [amp_method; FM_method]; %#ok<AGROW>

        reg_wait = [reg_wait; string(waitLabel)]; %#ok<AGROW>
        reg_pauseT = [reg_pauseT; Tp]; %#ok<AGROW>
        reg_left_exists = [reg_left_exists; left_exists]; %#ok<AGROW>
        reg_left_tmin = [reg_left_tmin; left_tmin]; %#ok<AGROW>
        reg_left_tmax = [reg_left_tmax; left_tmax]; %#ok<AGROW>
        reg_right_exists = [reg_right_exists; right_exists]; %#ok<AGROW>
        reg_right_tmin = [reg_right_tmin; right_tmin]; %#ok<AGROW>
        reg_right_tmax = [reg_right_tmax; right_tmax]; %#ok<AGROW>
        reg_afm_tmin = [reg_afm_tmin; dipWin(1)]; %#ok<AGROW>
        reg_afm_tmax = [reg_afm_tmax; dipWin(2)]; %#ok<AGROW>
        reg_gauss_tmin = [reg_gauss_tmin; gaussWin(1)]; %#ok<AGROW>
        reg_gauss_tmax = [reg_gauss_tmax; gaussWin(2)]; %#ok<AGROW>
        reg_excl_tmin = [reg_excl_tmin; exclWin(1)]; %#ok<AGROW>
        reg_excl_tmax = [reg_excl_tmax; exclWin(2)]; %#ok<AGROW>

        % ------------------------------
        % Panel 1: raw + smoothed
        % ------------------------------
        nexttile;
        h1 = gobjects(0); l1 = {};
        h1(end+1) = plot(T, dM_raw, 'k.-', 'LineWidth', 1.0, 'MarkerSize', 7); hold on;
        l1{end+1} = 'DeltaM raw';
        h1(end+1) = plot(T, dM, '-', 'Color', [0 0.45 0.74], 'LineWidth', 1.2);
        l1{end+1} = 'DeltaM';
        h1(end+1) = plot(T, dM_smooth, '-', 'Color', [0.1 0.6 0.1], 'LineWidth', 1.3);
        l1{end+1} = 'DeltaM smooth';
        grid on;
        xlabel('T (K)'); ylabel('\DeltaM');
        title(sprintf('Raw+Smooth | Tp=%.1f K', Tp));
        if i == 1
            lg = legend(h1, l1, 'Location', 'bestoutside'); lg.FontSize = 8;
        end

        % ------------------------------
        % Panel 2: AFM/FM/reconstruction
        % ------------------------------
        nexttile;
        h2 = gobjects(0); l2 = {};
        h2(end+1) = plot(T, dM, 'k-', 'LineWidth', 1.0); hold on; l2{end+1} = 'DeltaM';
        h2(end+1) = plot(T, dM_sharp, '-', 'Color', [0.85 0.33 0.10], 'LineWidth', 1.2); l2{end+1} = 'AFM component';
        h2(end+1) = plot(T, dM_smooth, '-', 'Color', [0 0.6 0], 'LineWidth', 1.2); l2{end+1} = 'FM component';
        h2(end+1) = plot(T, recon_sum, '--', 'Color', [0.49 0.18 0.56], 'LineWidth', 1.4); l2{end+1} = 'AFM+FM sum';
        grid on;
        xlabel('T (K)'); ylabel('Amplitude');
        title('Decomposition');
        if i == 1
            lg = legend(h2, l2, 'Location', 'bestoutside'); lg.FontSize = 8;
        end

        % ------------------------------
        % Panel 3: AFM(T) vs FM(T)
        % ------------------------------
        nexttile;
        h3 = gobjects(0); l3 = {};
        h3(end+1) = plot(T, dM_sharp, 'o-', 'Color', [0.85 0.33 0.10], 'LineWidth', 1.1, 'MarkerSize', 3); hold on;
        l3{end+1} = 'AFM(T)';
        h3(end+1) = plot(T, dM_smooth, 's-', 'Color', [0 0.6 0], 'LineWidth', 1.1, 'MarkerSize', 3);
        l3{end+1} = 'FM(T)';
        h3(end+1) = plot(T, FM_interp, ':', 'Color', [0 0 0], 'LineWidth', 1.2);
        l3{end+1} = 'FM interpolated';
        grid on;
        xlabel('T (K)'); ylabel('Amplitude');
        title('AFM vs FM');
        if i == 1
            lg = legend(h3, l3, 'Location', 'bestoutside'); lg.FontSize = 8;
        end

        % ------------------------------
        % Panel 4: geometry regions
        % ------------------------------
        nexttile;
        h4 = gobjects(0); l4 = {};
        h4(end+1) = plot(T, dM, 'k-', 'LineWidth', 1.0); hold on; l4{end+1} = 'DeltaM';
        yl = ylim;
        hTmp = patchWindow(baseLWin, yl, [0.2 0.8 0.2], 0.14); if isgraphics(hTmp), h4(end+1)=hTmp; l4{end+1}='left baseline'; end
        hTmp = patchWindow(baseRWin, yl, [0.2 0.8 0.2], 0.14); if isgraphics(hTmp), h4(end+1)=hTmp; l4{end+1}='right baseline'; end
        hTmp = patchWindow(dipWin, yl, [0.95 0.2 0.2], 0.12); if isgraphics(hTmp), h4(end+1)=hTmp; l4{end+1}='AFM window'; end
        hTmp = patchWindow(gaussWin, yl, [0.2 0.4 0.95], 0.08); if isgraphics(hTmp), h4(end+1)=hTmp; l4{end+1}='Gaussian window'; end
        hTmp = patchWindow(exclWin, yl, [0.5 0.5 0.5], 0.10); if isgraphics(hTmp), h4(end+1)=hTmp; l4{end+1}='excluded'; end
        h4(end+1) = xline(Tp, ':k', 'Tp'); l4{end+1} = 'Tp';
        grid on;
        xlabel('T (K)'); ylabel('\DeltaM');
        title('Region geometry');
        if i == 1
            lg = legend(h4, l4, 'Location', 'bestoutside'); lg.FontSize = 8;
        end

        % ------------------------------
        % Panel 5: baseline and FM refs
        % ------------------------------
        nexttile;
        h5 = gobjects(0); l5 = {};
        h5(end+1) = plot(T, dM_smooth, '-', 'Color', [0 0.6 0], 'LineWidth', 1.2); hold on;
        l5{end+1} = 'FM component (smooth)';

        if isfinite(left_center) && isfinite(left_mean)
            h5(end+1) = plot(left_center, left_mean, 'o', 'Color', [0 0 0], 'MarkerFaceColor', [0 0 0], 'MarkerSize', 6);
            l5{end+1} = 'left baseline mean';
            h5(end+1) = plot(left_center, FM_low_ref, 'x', 'Color', [0.1 0.1 0.1], 'LineWidth', 1.5, 'MarkerSize', 7);
            l5{end+1} = 'FM low reference';
        end
        if isfinite(right_center) && isfinite(right_mean)
            h5(end+1) = plot(right_center, right_mean, 's', 'Color', [0 0 0], 'MarkerFaceColor', [0 0 0], 'MarkerSize', 6);
            l5{end+1} = 'right baseline mean';
            h5(end+1) = plot(right_center, FM_high_ref, '+', 'Color', [0.1 0.1 0.1], 'LineWidth', 1.5, 'MarkerSize', 8);
            l5{end+1} = 'FM high reference';
        end

        txt = sprintf('FM step = %.3g\nmethod: %s', FM_step, FM_method);
        text(0.03, 0.96, txt, 'Units', 'normalized', 'VerticalAlignment', 'top', 'FontSize', 8, ...
             'BackgroundColor', 'w', 'EdgeColor', [0.8 0.8 0.8], 'Margin', 4);
        grid on;
        xlabel('T (K)'); ylabel('FM amplitude');
        title('FM reference extraction');
        if i == 1 && ~isempty(h5)
            lg = legend(h5, l5, 'Location', 'bestoutside'); lg.FontSize = 8;
        end
    end

    sgtitle(sprintf('FM Construction Audit | %s', datasetKey), 'Interpreter', 'none');
    figPath = fullfile(outDir, sprintf('FM_construction_%s.png', tag));
    saveas(figH, figPath);
    close(figH);

    fprintf('Saved %s\n', figPath);
end

% ------------------------------
% Write CSV outputs
% ------------------------------
mainTbl = table( ...
    main_wait, main_pauseT, main_T, main_DeltaM, main_DeltaM_smooth, ...
    main_AFM, main_FM, main_recon, ...
    main_is_left, main_is_right, main_is_afm, main_is_fm, main_is_valid, ...
    main_left_mean, main_left_std, main_left_tmin, main_left_tmax, ...
    main_right_mean, main_right_std, main_right_tmin, main_right_tmax, ...
    main_FM_raw, main_FM_interp, main_FM_method, ...
    'VariableNames', { ...
    'wait_time','pause_T','T','DeltaM','DeltaM_smooth', ...
    'AFM_component','FM_component','reconstructed_sum', ...
    'is_left_baseline','is_right_baseline','is_AFM_fit_region','is_FM_fit_region','is_valid_region', ...
    'left_baseline_mean','left_baseline_std','left_baseline_Tmin','left_baseline_Tmax', ...
    'right_baseline_mean','right_baseline_std','right_baseline_Tmin','right_baseline_Tmax', ...
    'FM_raw_value','FM_interpolated_value','FM_source_method'});

ampTbl = table( ...
    amp_wait, amp_pauseT, amp_low, amp_high, amp_step, amp_method, ...
    'VariableNames', {'wait_time','pause_T','FM_low_reference','FM_high_reference','FM_step','FM_method'});

regTbl = table( ...
    reg_wait, reg_pauseT, ...
    reg_left_exists, reg_left_tmin, reg_left_tmax, ...
    reg_right_exists, reg_right_tmin, reg_right_tmax, ...
    reg_afm_tmin, reg_afm_tmax, ...
    reg_gauss_tmin, reg_gauss_tmax, ...
    reg_excl_tmin, reg_excl_tmax, ...
    'VariableNames', { ...
    'wait_time','pause_T', ...
    'left_baseline_exists','left_Tmin','left_Tmax', ...
    'right_baseline_exists','right_Tmin','right_Tmax', ...
    'AFM_window_Tmin','AFM_window_Tmax', ...
    'Gaussian_window_Tmin','Gaussian_window_Tmax', ...
    'excluded_region_Tmin','excluded_region_Tmax'});

writetable(mainTbl, fullfile(outDir, 'FM_construction_audit.csv'));
writetable(ampTbl, fullfile(outDir, 'FM_amplitude_summary.csv'));
writetable(regTbl, fullfile(outDir, 'decomposition_regions_summary.csv'));

fprintf('Saved CSVs in %s\n', outDir);

% ------------------------------
% Helpers
% ------------------------------
function x = getFieldOrEmpty(s, f)
if isfield(s, f), x = s.(f); else, x = []; end
end

function v = getScalarOrNaN(s, f)
v = NaN;
if isfield(s, f)
    x = s.(f);
    if ~isempty(x) && isscalar(x) && isfinite(x), v = x; end
end
end

function [dipWin, baseLWin, baseRWin, gaussWin, exclWin] = computeWindows(T, Tp, cfg, fitWindowFactor, fitMinWindowK)
Tfin = T(isfinite(T));
if isempty(Tfin)
    Tmin = -inf; Tmax = inf;
else
    Tmin = min(Tfin); Tmax = max(Tfin);
end

if ~isfinite(Tp)
    dipWin = [NaN NaN]; baseLWin = [NaN NaN]; baseRWin = [NaN NaN]; gaussWin = [NaN NaN]; exclWin = [NaN NaN];
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

if isfield(cfg, 'excludeLowT_FM') && cfg.excludeLowT_FM && isfield(cfg, 'excludeLowT_K')
    exclWin = [Tmin, cfg.excludeLowT_K];
else
    exclWin = [NaN NaN];
end

dipWin = clampWindow(dipWin, Tmin, Tmax);
baseLWin = clampWindow(baseLWin, Tmin, Tmax);
baseRWin = clampWindow(baseRWin, Tmin, Tmax);
gaussWin = clampWindow(gaussWin, Tmin, Tmax);
exclWin = clampWindow(exclWin, Tmin, Tmax);
end

function mask = inWindow(T, win)
if isempty(win) || numel(win) ~= 2 || any(~isfinite(win))
    mask = false(size(T));
    return;
end
lo = min(win); hi = max(win);
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

function [mu, sd, tmin, tmax, existsFlag, tcenter] = baselineStats(T, y, mask)
mu = NaN; sd = NaN; tmin = NaN; tmax = NaN; tcenter = NaN; existsFlag = false;
valid = mask & isfinite(T) & isfinite(y);
if nnz(valid) >= 3
    existsFlag = true;
    vals = y(valid);
    tt = T(valid);
    mu = mean(vals, 'omitnan');
    sd = std(vals, 0, 'omitnan');
    tmin = min(tt);
    tmax = max(tt);
    tcenter = mean(tt);
end
end

function FM_interp = computeFMInterpolated(T, method, tL, tR, yL, yR, fit_curve, pr)
FM_interp = nan(size(T));

switch string(method)
    case "left_right_baseline_interp"
        if isfinite(tL) && isfinite(tR) && isfinite(yL) && isfinite(yR) && abs(tR - tL) > eps
            FM_interp = yL + (yR - yL) .* ((T - tL) ./ (tR - tL));
        elseif isfinite(yL)
            FM_interp(:) = yL;
        end

    case "right_only_extrapolation"
        if isfinite(yR)
            FM_interp(:) = yR;
        end

    case "fit_curve_background"
        n = min(numel(T), numel(fit_curve));
        if n > 0
            Tloc = T(1:n);
            fitloc = fit_curve(1:n);
            dipA = getScalarOrNaN(pr, 'Dip_A');
            dipS = getScalarOrNaN(pr, 'Dip_sigma');
            dipT0 = getScalarOrNaN(pr, 'Dip_T0');
            if isfinite(dipA) && isfinite(dipS) && dipS > 0 && isfinite(dipT0)
                AFM_fit = -dipA * exp(-(Tloc - dipT0).^2 ./ (2*dipS^2));
                FM_interp(1:n) = fitloc - AFM_fit;
            else
                FM_interp(1:n) = fitloc;
            end
        end

    otherwise
        % keep NaN
end
end

function h = patchWindow(win, yl, colorRGB, alphaVal)
h = gobjects(0);
if isempty(win) || numel(win) ~= 2 || any(~isfinite(win)) || win(2) <= win(1)
    return;
end
h = patch([win(1) win(2) win(2) win(1)], [yl(1) yl(1) yl(2) yl(2)], colorRGB, ...
      'FaceAlpha', alphaVal, 'EdgeColor', 'none');
end

