function debugPlotGeometry(state, cfg)

if ~isfield(state, 'pauseRuns') || isempty(state.pauseRuns)
    return;
end

for i = 1:numel(state.pauseRuns)
    pr = state.pauseRuns(i);

    if ~isfield(pr, 'waitK') || isempty(pr.waitK)
        continue;
    end
    Tp = pr.waitK;

    T_filt = getRunVector(pr, 'T_common');
    if isempty(T_filt)
        T_filt = getRunVector(pr, 'T');
    end
    dM_filt = getRunVector(pr, 'DeltaM');

    if isempty(T_filt) || isempty(dM_filt)
        continue;
    end

    T_raw = T_filt;
    dM_raw = dM_filt;
    if isfield(state, 'pauseRuns_raw') && numel(state.pauseRuns_raw) >= i
        rawRun = state.pauseRuns_raw(i);
        T_raw_tmp = getRunVector(rawRun, 'T_common');
        if isempty(T_raw_tmp)
            T_raw_tmp = getRunVector(rawRun, 'T');
        end
        dM_raw_tmp = getRunVector(rawRun, 'DeltaM');
        if ~isempty(T_raw_tmp) && ~isempty(dM_raw_tmp)
            T_raw = T_raw_tmp;
            dM_raw = dM_raw_tmp;
        end
    end

    fig = figure('Color','w', 'Name', sprintf('Debug Geometry Tp=%.2f K', Tp), 'NumberTitle','off');
    ax = axes(fig);
    hold(ax, 'on');

    hRaw = plot(ax, T_raw, dM_raw, '-', 'Color', [0.8 0.8 0.8], 'LineWidth', 1.2);
    hFilt = plot(ax, T_filt, dM_filt, '-', 'Color', [0 0.4470 0.7410], 'LineWidth', 1.8);

    yl = ylim(ax);

    dipWindow = [Tp - cfg.dip_window_K, Tp + cfg.dip_window_K];
    plateauL = [Tp - cfg.dip_window_K - cfg.FM_buffer_K - cfg.FM_plateau_K, ...
                Tp - cfg.dip_window_K - cfg.FM_buffer_K];
    plateauR = [Tp + cfg.dip_window_K + cfg.FM_buffer_K, ...
                Tp + cfg.dip_window_K + cfg.FM_buffer_K + cfg.FM_plateau_K];

    hDip = patch(ax, [dipWindow(1) dipWindow(2) dipWindow(2) dipWindow(1)], ...
        [yl(1) yl(1) yl(2) yl(2)], [1 0 0], 'FaceAlpha', 0.15, 'EdgeColor', 'none');
    hPL = patch(ax, [plateauL(1) plateauL(2) plateauL(2) plateauL(1)], ...
        [yl(1) yl(1) yl(2) yl(2)], [0 0.6 0], 'FaceAlpha', 0.12, 'EdgeColor', 'none');
    hPR = patch(ax, [plateauR(1) plateauR(2) plateauR(2) plateauR(1)], ...
        [yl(1) yl(1) yl(2) yl(2)], [0 0.6 0], 'FaceAlpha', 0.12, 'EdgeColor', 'none');
    uistack([hDip hPL hPR], 'bottom');

    Tmin = getStoredTmin(state, i, Tp);
    yTmin = NaN;
    if isfinite(Tmin)
        yTmin = interp1(T_filt(:), dM_filt(:), Tmin, 'linear', NaN);
    end

    hTmin = plot(ax, Tmin, yTmin, 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 6);

    dipArea = getStoredMetric(pr, {'Dip_area','AFM_area'});
    fmStep = getStoredMetric(pr, {'FM_step_mag','FM_step_A','FM_step_raw'});

    title(ax, sprintf('Tp=%.2f K | Dip\\_area=%.4g | FM\\_step=%.4g', Tp, dipArea, fmStep));
    xlabel(ax, 'T (K)');
    ylabel(ax, '\DeltaM');
    legend(ax, [hRaw hFilt hDip hPL hPR hTmin], ...
        {'raw', 'filtered', 'dip window', 'plateau L', 'plateau R', 'Tmin'}, ...
        'Location', 'best');
    grid(ax, 'on');
end

end

function v = getRunVector(s, fieldName)
v = [];
if isfield(s, fieldName)
    v = s.(fieldName);
end
end

function val = getStoredMetric(s, candidates)
val = NaN;
for k = 1:numel(candidates)
    f = candidates{k};
    if isfield(s, f)
        x = s.(f);
        if ~isempty(x) && isfinite(x)
            val = x;
            return;
        end
    end
end
end

function Tmin = getStoredTmin(state, idx, Tp)
Tmin = NaN;

if isfield(state.pauseRuns(idx), 'Tmin_dip') && ~isempty(state.pauseRuns(idx).Tmin_dip)
    x = state.pauseRuns(idx).Tmin_dip;
    if isfinite(x)
        Tmin = x;
        return;
    end
end

if isfield(state, 'debug') && isfield(state.debug, 'debugTable') && ~isempty(state.debug.debugTable)
    dt = state.debug.debugTable;
    if istable(dt) && all(ismember({'Tp','Tmin_dip'}, dt.Properties.VariableNames))
        match = abs(dt.Tp - Tp) < 1e-9;
        if any(match)
            x = dt.Tmin_dip(find(match, 1, 'first'));
            if isfinite(x)
                Tmin = x;
            end
        end
    end
end
end
