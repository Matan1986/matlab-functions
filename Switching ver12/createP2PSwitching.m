function createP2PSwitching(tableData, sortedValues, A, dep_type, ...
    plot_std, labels, plotChannels, ...
    Normalize_to, negativeP2P, ...
    plot_std_as_errors_on_p2p, pulseScheme, meta)

% =================================================
% createP2PSwitching
%
% Peak-to-peak switching summary plots (ΔR/R [%])
% One paper-ready figure per active channel
% Fully consistent with createPlotsSwitching
% =================================================

% ---------------- VISUAL CONSTANTS ----------------
axisFS   = 20;
labelFS  = 20;
lw_main  = 1.8;
lw_err   = 1.3;
markerSz = 6;
plotColor = [0 0 0];

% -------------------------------------------------
% Detect categorical dependence
% -------------------------------------------------
isCategorical = ismember(dep_type, ...
    {'Field cool','Configuration','Pulse direction and order'});

% -------------------------------------------------
% X-axis units (SINGLE SOURCE OF TRUTH)
% -------------------------------------------------
[convUnits, xlabelStr] = convertDepUnits(dep_type, A);
log_scale = strcmp(dep_type,'Width');

% -------------------------------------------------
% Build X vector
% -------------------------------------------------
if isCategorical
    X = 1:numel(sortedValues);
    X_labels = sortedValues;
else
    firstCh = get_first_existing_channel(tableData);
    X = tableData.(firstCh)(:,1) * convUnits;
end

% purely negative sweep → flip visually
flipX = false;
if ~isCategorical && all(X <= 0)
    X = abs(X);
    flipX = true;
end

% -------------------------------------------------
% Enabled channels
% -------------------------------------------------
enabledKeys   = get_enabled_keys(plotChannels);
enabledChNums = cellfun(@(c) sscanf(c,'ch%d'), enabledKeys);

if isscalar(Normalize_to)
    Normalize_to_use = repmat(Normalize_to, 1, numel(enabledChNums));
else
    Normalize_to_use = Normalize_to(:).';
end

assert(numel(Normalize_to_use) == numel(enabledChNums), ...
    'Normalize_to length must match enabled channels');

% -------------------------------------------------
% Figure base name (dep + meta)
% -------------------------------------------------
nameParts = {};
nameParts{end+1} = sprintf('%s dependence', dep_type);

if exist('meta','var') && isstruct(meta)
    if isfield(meta,'Temperature_K') && ~isnan(meta.Temperature_K)
        nameParts{end+1} = sprintf('T = %.3g K', meta.Temperature_K);
    end
    if isfield(meta,'Field_T') && ~isnan(meta.Field_T)
        nameParts{end+1} = sprintf('B = %.3g T', meta.Field_T);
    end
    if isfield(meta,'Current_mA') && ~isnan(meta.Current_mA)
        nameParts{end+1} = sprintf('I = %.3g mA', meta.Current_mA);
    end
    if isfield(meta,'PulseWidth_ms') && ~isnan(meta.PulseWidth_ms)
        nameParts{end+1} = sprintf('\tau = %.3g ms', meta.PulseWidth_ms);
    end
end

baseFigName = strjoin(nameParts, ' | ');

% -------------------------------------------------
% Main loop over channels
% -------------------------------------------------
for ch = 1:4

    chName = sprintf('ch%d', ch);
    if ~isfield(tableData,chName), continue; end
    if ~plotChannels.(chName), continue; end
    if isempty(tableData.(chName)), continue; end

    tbl = tableData.(chName);

    % Columns:
    % (1) dep value
    % (2) avg_p2p
    % (3) baseline
    % (4) ΔR/R [%]
    % (5) std_rel
    % (6) σ(ΔR)
    % (7) reference baseline

    y_change = tbl(:,4);
    if negativeP2P
        y_change = -y_change;
    end

    uncert_dR = tbl(:,6);
    refBase   = tbl(:,7);
    y_err     = 100 * (uncert_dR ./ refBase);

    % -------------------------------------------------
    % Y-label (USING labels + cleanChannelLabel)
    % -------------------------------------------------
    if pulseScheme.mode == "repeated"
        yLabelStr = '$\Delta {\mathrm{block}}/\,(\%)$';
    else
        raw_i   = labels.(chName);
        clean_i = cleanChannelLabel(raw_i);

        idx = find(enabledChNums == ch, 1);
        j   = Normalize_to_use(idx);

        raw_j   = labels.(sprintf('ch%d', j));
        clean_j = cleanChannelLabel(raw_j);


        yLabelStr = sprintf( ...
            '$\\mathrm{\\Delta %s/%s\\ (\\%%)}$', ...
            clean_i, clean_j);

    end

    % ================= FIGURE =================
    fig = figure( ...
        'Name', sprintf('%s | %s', baseFigName, labels.(chName)), ...
        'NumberTitle','off', ...
        'Color','w');

    ax = axes(fig);
    hold(ax,'on');
    set(ax,'FontSize',axisFS,'Layer','top','Box','on');

    % ----- data ordering -----
    Xplot = X(:);
    yplot = y_change(:);
    yerrp = y_err(:);

    if flipX
        Xplot = flipud(Xplot);
        yplot = flipud(yplot);
        yerrp = flipud(yerrp);
    end

    % ----- main curve -----
    plot(ax, Xplot, yplot, 'o--', ...
        'LineWidth', lw_main, ...
        'MarkerSize', markerSz, ...
        'MarkerFaceColor', plotColor, ...
        'Color', plotColor);

    % ----- error bars -----
    if plot_std_as_errors_on_p2p
        errorbar(ax, Xplot, yplot, yerrp, ...
            'LineStyle','none', ...
            'Color', plotColor, ...
            'CapSize',8, ...
            'LineWidth', lw_err);
    end

    % ----- axes formatting -----
    if isCategorical
        xticks(ax, X);
        xticklabels(ax, X_labels);
    elseif log_scale
        set(ax,'XScale','log');
    end

    xlabel(ax, xlabelStr, 'FontSize', labelFS);
    ylabel(ax, yLabelStr, 'FontSize', labelFS);
    % ----- grid on both axes -----
    set(ax, ...
        'XGrid','on', ...
        'YGrid','on', ...
        'GridLineStyle','-', ...
        'GridAlpha',0.15);

    % ----- enforce LaTeX everywhere -----
    forceLatexFigure(fig);
end
end

% =================================================
% Helper: first existing channel
% =================================================
function chName = get_first_existing_channel(tableData)
for i = 1:4
    nm = sprintf('ch%d',i);
    if isfield(tableData,nm) && ~isempty(tableData.(nm))
        chName = nm;
        return;
    end
end
chName = 'ch1';
end
