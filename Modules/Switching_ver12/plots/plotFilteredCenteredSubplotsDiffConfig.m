function fig = plotFilteredCenteredSubplotsDiffConfig( ...
    stored_data, meta,dep_type, labels, Normalize_to, active_channels, fontsize)
% plotFilteredCenteredSubplotsDiffConfig
%
% Plots centered ΔR/R [%] for different configurations
% Paper-ready LaTeX formatting everywhere
%
% stored_data{cfg,2} : R_filt  [TIME | ch1 | ch2 | ch3 | ch4]

% -------------------------------------------------
% Layout
% -------------------------------------------------
nCh      = numel(active_channels);
nConfigs = size(stored_data,1);

fig = figure( ...
    'NumberTitle','off', ...
    'Color','w', ...
    'Position',[150 50 1100 750]);
% -------------------------------------------------
% Figure name (window title) using dep_type + meta
% -------------------------------------------------
nameParts = {};

% Dependence type
nameParts{end+1} = sprintf('DeltaR/R, %s dependence', dep_type);

% Meta data (only if exists)
if ~isnan(meta.Temperature_K)
    nameParts{end+1} = sprintf('T = %.3g K', meta.Temperature_K);
end
if ~isnan(meta.Field_T)
    nameParts{end+1} = sprintf('B = %.3g T', meta.Field_T);
end
if ~isnan(meta.PulseWidth_ms)
    nameParts{end+1} = sprintf('\\tau = %.3g ms', meta.PulseWidth_ms);
end
if ~isnan(meta.Current_mA)
    nameParts{end+1} = sprintf('I = %.3g mA', meta.Current_mA);
end

fig.Name = strjoin(nameParts, ' | ');
fig.NumberTitle = 'off';

t = tiledlayout(nCh, nConfigs, ...
    'TileSpacing','none', ...
    'Padding','compact');

t.OuterPosition = [0.03 0.03 0.94 0.94];

% -------------------------------------------------
% Colors
% -------------------------------------------------
soft_colors = {
    [0.80 0.35 0.35];   % ch1
    [0.35 0.35 0.80];   % ch2
    [0.30 0.65 0.30];   % ch3
    [0.60 0.45 0.75];   % ch4
};

bottomBlue = [0.35 0.35 0.80];

% -------------------------------------------------
% Resolve normalization indices
% -------------------------------------------------
keysF = arrayfun(@(c)sprintf('ch%d',c), active_channels, ...
    'UniformOutput', false);

normIdxVec = resolve_norm_indices(Normalize_to, keysF);

% -------------------------------------------------
% PASS 1: global Y-limits
% -------------------------------------------------
y_min = Inf;
y_max = -Inf;
mids  = zeros(nCh, nConfigs);

for cfg = 1:nConfigs
    Rf = stored_data{cfg,2};
    L  = size(Rf,1);

    for ch = 1:nCh
        physCh     = active_channels(ch);
        normPhysCh = active_channels(normIdxVec(ch));

        Rch  = Rf(:,1+physCh);
        Rref = Rf(:,1+normPhysCh);

        trace = (Rch ./ mean(Rref,'omitnan')) * 100;
        mids(ch,cfg) = mean(trace,'omitnan');

        shifted = trace - mids(ch,cfg);
        y_min = min(y_min, min(shifted));
        y_max = max(y_max, max(shifted));
    end
end

y_abs = 1 * max(abs([y_min y_max]));
ylims = [-y_abs y_abs];

% -------------------------------------------------
% PASS 2: plotting
% -------------------------------------------------
cumulative_time = 0;

for cfg = 1:nConfigs

    Rf    = stored_data{cfg,2};
    t_raw = Rf(:,1);

    tt = t_raw + cumulative_time;
    cumulative_time = max(tt);

    for ch = 1:nCh

        ax = nexttile(t, (ch-1)*nConfigs + cfg);

        physCh     = active_channels(ch);
        normPhysCh = active_channels(normIdxVec(ch));

        Rch  = Rf(:,1+physCh);
        Rref = Rf(:,1+normPhysCh);

        trace = (Rch ./ mean(Rref,'omitnan')) * 100;
        shifted = trace - mids(ch,cfg);

        % color
        c = soft_colors{physCh};
        if ch == nCh, c = bottomBlue; end

        plot(ax, tt, shifted, 'Color', c, 'LineWidth', 1.5);
        ylim(ax, ylims);


        % ---- Y label only on first column ----
        if cfg == 1
            labNum = cleanChannelLabel(labels.(sprintf('ch%d',physCh)));
            labDen = cleanChannelLabel(labels.(sprintf('ch%d',normPhysCh)));

            ylabel(ax, sprintf( ...
                '$\\Delta\\,\\mathrm{%s} / \\mathrm{%s}\\,(\\%%)$', ...
                labNum, labDen), ...
                'Interpreter','latex', ...
                'FontSize', fontsize);
        else
            ax.YTick = [];
        end

        % ---- Tick formatting ----
        ax.TickLabelInterpreter = 'latex';
        ax.FontSize = fontsize - 2;

        ax.XTick = [];
        ax.XTickLabel = [];
    end
end

% -------------------------------------------------
% Global X label
% -------------------------------------------------
xlabel(t,'$\mathrm{Time}$', ...
    'Interpreter','latex', ...
    'FontSize', fontsize);

% -------------------------------------------------
% Enforce LaTeX everywhere
% -------------------------------------------------
set(findall(fig,'-property','Interpreter'),'Interpreter','latex');
set(findall(fig,'-property','TickLabelInterpreter'),'TickLabelInterpreter','latex');

end