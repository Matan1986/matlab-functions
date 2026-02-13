function createSwitchingStabilityFigure(stability, dep_type, labels,A, varargin)
% createSwitchingStabilityFigure
% Top:    temporal stability (drift-based, log-orders)
% Bottom: plateau stability (SNR: gap / noise, linear)

% ---------------- parse optional ----------------
p = inputParser;
addParameter(p,'Channel',[]);
parse(p,varargin{:});
forceChannel = p.Results.Channel;

T = stability.summaryTable;

% ---------------- auto-detect channel ----------------
if isempty(forceChannel)
    ch = stability.switching.globalChannel;
else
    ch = forceChannel;
end

% ---------------- SAFE EXIT if no switching channel ----------------
if isempty(ch) || ~isfinite(ch)

    fig = figure('Color','w','NumberTitle','off');

    % -------- meta-data (WINDOW NAME ONLY) --------
    nameParts = {'Switching stability', sprintf('%s dependence', dep_type), ...
                 'No switching channel detected'};

    if isfield(stability,'meta')
        if isfield(stability.meta,'Temperature_K') && ~isnan(stability.meta.Temperature_K)
            nameParts{end+1} = sprintf('T = %.3g K', stability.meta.Temperature_K);
        end
        if isfield(stability.meta,'Field_T') && ~isnan(stability.meta.Field_T)
            nameParts{end+1} = sprintf('B = %.3g T', stability.meta.Field_T);
        end
        if isfield(stability.meta,'Current_mA') && ~isnan(stability.meta.Current_mA)
            nameParts{end+1} = sprintf('I = %.3g mA', stability.meta.Current_mA);
        end
    end

    fig.Name = strjoin(nameParts,' | ');

    % -------- placeholder axis --------
    ax = axes(fig);
    axis(ax,'off');

    text(ax, 0.5, 0.55, ...
        'No switching channel detected', ...
        'HorizontalAlignment','center', ...
        'FontSize',14, ...
        'Interpreter','tex');

    text(ax, 0.5, 0.45, ...
        'Stability metrics were not evaluated for this dataset.', ...
        'HorizontalAlignment','center', ...
        'FontSize',11, ...
        'Interpreter','tex');

    warning('createSwitchingStabilityFigure:NoSwitchingChannel', ...
        'No switching channel detected — stability figure skipped.');

    return;
end


% ---------------- resolve physical label ----------------
lbl = physChannelLabel(ch, labels);

% ---------------- select data ----------------
idx   = (T.channel == ch);
x_raw = T.depValue(idx);

flipX = false;
if all(x_raw <= 0)
    x     = abs(x_raw);
    flipX = true;
else
    x = x_raw;
end

if isfield(stability,'plotAbsDep') && stability.plotAbsDep
    x = abs(x);
end

% ---------------- stability metrics ----------------
eps0 = 1e-6;
stabilityPulse = 1 ./ max(T.driftPerPulseRelToGap(idx), eps0);
stabilityRange = 1 ./ max(T.driftRangeRelToGap(idx), eps0);
stabilityNet   = 1 ./ max(T.driftEndToStartRelToGap(idx), eps0);
plateauStability = T.stabilityIndex(idx);

% ---------------- sort ----------------
[x, ord] = sort(x);
if flipX
    ord = flipud(ord);
    x   = x(ord);
end

stabilityPulse   = stabilityPulse(ord);
stabilityRange   = stabilityRange(ord);
stabilityNet     = stabilityNet(ord);
plateauStability = plateauStability(ord);

% ---------------- axis label (UNCHANGED TEXT) ----------------
opts.abs = isfield(stability,'plotAbsDep') && stability.plotAbsDep;
[convUnits, xlabelStr] = convertDepUnits(dep_type, A, opts);

x = x * convUnits;

% ---------------- figure ----------------
fig = figure('Color','w','NumberTitle','off');

% ---------------- meta-data (WINDOW NAME ONLY) ----------------
nameParts = {};
nameParts{end+1} = 'Switching stability';
nameParts{end+1} = sprintf('%s dependence', dep_type);
nameParts{end+1} = lbl;

if isfield(stability,'meta')
    if isfield(stability.meta,'Temperature_K') && ~isnan(stability.meta.Temperature_K)
        nameParts{end+1} = sprintf('T = %.3g K', stability.meta.Temperature_K);
    end
    if isfield(stability.meta,'Field_T') && ~isnan(stability.meta.Field_T)
        nameParts{end+1} = sprintf('B = %.3g T', stability.meta.Field_T);
    end
    if isfield(stability.meta,'Current_mA') && ~isnan(stability.meta.Current_mA)
        nameParts{end+1} = sprintf('I = %.3g mA', stability.meta.Current_mA);
    end
end

fig.Name = strjoin(nameParts,' | ');

% ---------------- layout ----------------
tl = tiledlayout(fig,2,1,'TileSpacing','compact','Padding','compact');

% ---------------- style constants ----------------
lw_main   = 1.8;
markerSz = 6;
plotColor = [0 0 0];

%% =====================================================
% TOP PANEL — TEMPORAL STABILITY (log-orders)
% ======================================================
ax1 = nexttile(tl,1);
hold(ax1,'on');

yPulse = log10(stabilityPulse);
yRange = log10(stabilityRange);
yNet   = log10(stabilityNet);

plot(ax1,x,yPulse,'o--', ...
    'LineWidth',lw_main, ...
    'MarkerSize',markerSz, ...
    'MarkerFaceColor',plotColor, ...
    'DisplayName','pulse-to-pulse');

plot(ax1,x,yRange,'s-', ...
    'LineWidth',lw_main, ...
    'MarkerSize',markerSz, ...
    'MarkerFaceColor',plotColor, ...
    'DisplayName','global drift');

plot(ax1,x,yNet,'^-', ...
    'LineWidth',lw_main, ...
    'MarkerSize',markerSz, ...
    'MarkerFaceColor',plotColor, ...
    'DisplayName','end-to-start');

yl = [floor(min([yPulse;yRange;yNet]))-0.1, ...
      ceil(max([yPulse;yRange;yNet]))+0.1];
ylim(ax1,yl);

pTicks = floor(yl(1)) : ceil(yl(2));
ax1.YTick      = pTicks;
ax1.YTickLabel = compose('10^{%d}', pTicks);

ylabel(ax1,{'Temporal stability','(gap / drift)'});
set(ax1,'XGrid','off','YGrid','on','GridAlpha',0.15);

legend(ax1, { ...
    'pulse-to-pulse: gap / local drift', ...
    'range: gap / full excursion', ...
    'net: gap / end-to-start drift'}, ...
    'Location','best');

%% =====================================================
% BOTTOM PANEL — PLATEAU STABILITY (LINEAR SNR)
% ======================================================
ax2 = nexttile(tl,2);
hold(ax2,'on');

plot(ax2,x,plateauStability,'d-', ...
    'LineWidth',lw_main, ...
    'MarkerSize',markerSz, ...
    'MarkerFaceColor',plotColor, ...
    'DisplayName','gap / noise');

ax2.YScale = 'linear';
ylabel(ax2,{'Local plateau stability','(gap / noise)'});
xlabel(ax2,xlabelStr);

set(ax2,'XGrid','on','YGrid','on','GridAlpha',0.15);
legend(ax2,'Location','best');

% ---------------- LaTeX finalizer ----------------
forceLatexFigure(fig);

end

% ============================================================
function lbl = physChannelLabel(ch_phys, labels)
    field = sprintf('ch%d', ch_phys);
    if nargin >= 2 && isstruct(labels) && isfield(labels, field) ...
            && ~isempty(labels.(field))
        lbl = labels.(field);
    else
        lbl = sprintf('ch%d', ch_phys);
    end
end
