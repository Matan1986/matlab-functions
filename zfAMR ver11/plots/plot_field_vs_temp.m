function plot_field_vs_temp( ...
    resistivity_deviation_percent_tables, angles, fields, specific_fields, ...
    temp_values, Normalize_to, excluded_fields, plan_measured, ...
    fontsize, linewidth, plotChannels, titleStr, polar_plots, ...
    channelKeys, channelLabels, reducedTemps, legendThreshold)

% reducedTemps:
%   - [] (omit) → plot ALL temps
%   - scalar N  → plot N evenly spaced temps from temp_values
%   - vector    → plot nearest temps to these values
% legendThreshold: max number of curves to still use a legend; above that → colorbar

if nargin < 13 || isempty(polar_plots), polar_plots = false; end
if nargin < 14 || isempty(channelKeys), channelKeys = {'ch1','ch2','ch3','ch4'}; end
if nargin < 15, channelLabels = []; end
if nargin < 16, reducedTemps = []; end
if nargin < 17 || isempty(legendThreshold), legendThreshold = 5; end

if isempty(excluded_fields) || (isscalar(excluded_fields) && isnan(excluded_fields))
    excluded_fields = [];
end

% Helpers
getLabel  = @(key) resolveLabelForKey(key, channelLabels, plotChannels);
isEnabled = @(key) isfield(plotChannels, key) && logical(plotChannels.(key));

% Probe schema
tblProbe = [];
if iscell(resistivity_deviation_percent_tables)
    for ii = 1:numel(resistivity_deviation_percent_tables)
        t = resistivity_deviation_percent_tables{ii};
        if istable(t) && ~isempty(t), tblProbe = t; break; end
    end
end
if isempty(tblProbe)
    warning('plot_field_vs_temp:EmptyInput','No data tables provided.');
    return;
end

% Components & labels
components = {};
component_labels = {};
for k = 1:numel(channelKeys)
    key = channelKeys{k};
    if isEnabled(key) && ismember(key, tblProbe.Properties.VariableNames)
        components{end+1} = key; %#ok<AGROW>
        lbl = getLabel(key); if isstring(lbl), lbl = char(lbl); end
        if isempty(lbl), lbl = key; end
        component_labels{end+1} = lbl; %#ok<AGROW>
    end
end
if isempty(components)
    warning('plot_field_vs_temp:NoComponentsEnabled','No enabled components match table variables.');
    return;
end

% ----- Iterate over requested fields -----
for sf = specific_fields(:)'
    [~, f_idx] = min(abs(fields - sf));
    if isempty(f_idx) || f_idx < 1 || f_idx > numel(resistivity_deviation_percent_tables)
        warning('Requested field %.4g[T] is out of range.', sf); continue;
    end
    matchedField = fields(f_idx);
    if any(abs(matchedField - excluded_fields) <= max(eps,1e-12)), continue; end

    tbl = resistivity_deviation_percent_tables{f_idx};

    % Normalization label
    norm_idx   = min(max(1, Normalize_to), numel(component_labels));
    norm_label = component_labels{norm_idx};
    if isstring(norm_label), norm_label = char(norm_label); end
    if isempty(norm_label), norm_label = 'ch1'; end

    % ----- For each enabled component -----
    for iComp = 1:numel(components)
        comp_key   = components{iComp};
        comp_label = component_labels{iComp};

        % Cartesian
        figName = sprintf('%s %s %s at %.3g[T]', plan_measured, titleStr, comp_label, matchedField);
        figure('Name', figName, 'Position', [100,100,1000,600]); hold on; ax = gca;

        if ~ismember(comp_key, tbl.Properties.VariableNames)
            warning('Table for field %.3g[T] has no column "%s". Skipping.', matchedField, comp_key);
            hold off; close(gcf); continue;
        end

        Y = tbl.(comp_key);   % [nAngles × nTemps]

% ---- require Angle column and use it ----
if ~ismember('Angle', tbl.Properties.VariableNames)
    warning('plot_field_vs_temp:NoAngleColumn', ...
        'Table for field %.3g[T] has no "Angle" column. Skipping.', matchedField);
    hold off; close(gcf); continue;
end

angles_f = tbl.Angle(:);   % <-- CORRECT angles for this table

% ---- defensive alignment (just in case) ----
nA = min(numel(angles_f), size(Y,1));
angles_f = angles_f(1:nA);
Y = Y(1:nA, :);

% ---------- Decide reduced temperature indices ----------
if ~isempty(reducedTemps)
    if isscalar(reducedTemps)
        sel_idx = unique(round(linspace(1, numel(temp_values), reducedTemps)));
    else
        sel_idx = arrayfun(@(v) ...
            find(abs(temp_values - v) == min(abs(temp_values - v)), 1, 'first'), ...
            reducedTemps);
        sel_idx = unique(sel_idx);
    end
else
    sel_idx = 1:numel(temp_values);
end

plot_temp_values = temp_values(sel_idx);
num_plotted = numel(plot_temp_values);

% ---------- Colormap based on reduced set ----------
if num_plotted > 5
    temp_colors = parula(max(num_plotted,64));
else
    temp_colors = jet(max(num_plotted,64));
end
temp_inds = round(linspace(1, size(temp_colors,1), num_plotted));

% ---------- Legend vs colorbar decision ----------
use_colorbar_instead_of_legend = (num_plotted > legendThreshold);

% ---------- Plot loop (only reduced temps) ----------
for kk = 1:num_plotted
    ti = sel_idx(kk);
    if ti > size(Y,2), break; end
    plot(angles_f, Y(:,ti), '-o', ...
        'Color', temp_colors(temp_inds(kk),:), ...
        'LineWidth', linewidth, ...
        'DisplayName', sprintf('%.1f[K]', plot_temp_values(kk)));
end


        % ---------- Legend vs colorbar ----------
        if use_colorbar_instead_of_legend && num_plotted > 1
            delete(findall(ax,'Type','Legend'));
            colormap(ax, temp_colors);
            caxis([min(plot_temp_values), max(plot_temp_values)]);
            cb = colorbar(ax);
            cb.Label.String = 'Temperature [K]';
            % up to 5 ticks, but keep them within range
            nt = min(num_plotted,5);
            if nt > 1
                cb.Ticks = linspace(min(plot_temp_values), max(plot_temp_values), nt);
                cb.TickLabels = arrayfun(@(v) sprintf('%.1f', v), cb.Ticks, 'UniformOutput', false);
            else
                % fallback: single label
                cb.Ticks = plot_temp_values;
                cb.TickLabels = {sprintf('%.1f', plot_temp_values)};
            end
        else
            legend(ax,'show','Location','eastoutside');
        end

        % Cosmetics
        ax.FontSize = fontsize;
        ax.XTick = 0:45:360;
        ax.XTickLabel = string(0:45:360);
        ax.XLim = [0 360];
        title(sprintf('%s %s \\Delta%s/%s[%%] at %.3g[T]', ...
            plan_measured, titleStr, comp_label, norm_label, matchedField), ...
            'FontSize', fontsize, 'Interpreter','tex');
        xlabel('Angle °', 'FontSize', fontsize, 'Interpreter','tex');
        ylabel(sprintf('\\Delta%s/%s[%%]', comp_label, norm_label), ...
            'FontSize', fontsize, 'Interpreter','tex');
        grid on; hold off;

        % ----- Polar (optional) -----
        if polar_plots
            % Figure name: only comp_label (no Δ, no normalization)
            % Figure name: <titleStr> Polar <plan_measured> <comp_label> at <field>[T]
            figP = figure('Name', ...
                sprintf('%s Polar %s %s at %.3g[T]', ...
                plan_measured, titleStr, comp_label, matchedField), ...
                'Position', [100,100,1000,600]);
            pax = polaraxes(figP); hold(pax,'on');

            theta = deg2rad(angles(:));
            for kk = 1:num_plotted
                ti = sel_idx(kk);
                if ti > size(Y,2), break; end
                rho = abs(Y(:,ti));
                polarplot(pax, theta, rho, '-o', ...
                    'Color', temp_colors(temp_inds(kk),:), ...
                    'LineWidth', linewidth, ...
                    'DisplayName', sprintf('%.1f[K]', plot_temp_values(kk)));
            end

            if use_colorbar_instead_of_legend && num_plotted > 1
                delete(findall(pax,'Type','Legend'));
                colormap(pax, temp_colors);
                caxis(pax, [min(plot_temp_values), max(plot_temp_values)]);
                cb = colorbar('peer', pax);
                cb.Label.String = 'Temperature [K]';
                nt = min(num_plotted,5);
                if nt > 1
                    cb.Ticks = linspace(min(plot_temp_values), max(plot_temp_values), nt);
                    cb.TickLabels = arrayfun(@(v) sprintf('%.1f', v), cb.Ticks, 'UniformOutput', false);
                else
                    cb.Ticks = plot_temp_values;
                    cb.TickLabels = {sprintf('%.1f', plot_temp_values)};
                end
            else
                lg = legend(pax,'show');
                lg.Location = 'eastoutside';
            end

            pax.FontSize = fontsize;
            pax.ThetaTick = 0:45:315;
            pax.ThetaTickLabel = string(0:45:315);

            % Title: keep Δ and normalization
            title(pax, sprintf('%s Polar %s Δ%s/%s[%%] at %.3g[T]', ...
                plan_measured, titleStr, comp_label, norm_label, matchedField), ...
                'FontSize', fontsize, 'Interpreter','tex');
            pax.RGrid = 'on'; hold(pax,'off');
        end



    end
end
end
