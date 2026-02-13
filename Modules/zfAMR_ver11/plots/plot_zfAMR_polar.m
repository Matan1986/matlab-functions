function plot_zfAMR_polar( ...
    resistivity_deviation_percent_tables, angles, fields, ...
    temp_index, temp_val, Normalize_to, ...
    excluded_fields, plan_measured, fontsize, linewidth, plotChannels, zfc_fwAMR)

% -------- Resolve channel keys & labels (generic) -----------------
[ch_keys, ch_labels] = resolve_channels(plotChannels);

% Guard: nothing to plot
if isempty(ch_keys), return; end

% -------- Normalization label (for title) -------------------------
norm_idx = 1;
if isnumeric(Normalize_to)
    norm_idx = max(1, min(numel(ch_labels), round(Normalize_to)));
elseif ischar(Normalize_to) || (isstring(Normalize_to) && isscalar(Normalize_to))
    k = find(strcmp(ch_keys, char(Normalize_to)), 1);
    if ~isempty(k), norm_idx = k; end
end
devide_str = ch_labels{norm_idx};

% -------- AMR string (zfAMR / fwAMR) ------------------------------
AMR_string = 'zfAMR';
if zfc_fwAMR, AMR_string = 'fwAMR'; end

% -------- Colors ---------------------------------------------------
num_fields = numel(resistivity_deviation_percent_tables);

% NEW: Use MATLAB default colors when few fields
useDefaultColors = num_fields <= 3;

if ~useDefaultColors
    if num_fields > 5
        colors = parula(max(num_fields,64));
    else
        colors = jet(max(num_fields,64));
    end
    color_indices = round(linspace(1, size(colors,1), num_fields));
end

% -------- Plot per channel ----------------------------------------
for iComp = 1:numel(ch_keys)
    comp_name = ch_keys{iComp};
    comp_str  = ch_labels{iComp};

    fig = figure('Name', sprintf('%s %s %s Polar at %.2f[K]', ...
                 plan_measured, AMR_string, comp_str, temp_val), ...
                 'Position', [100,100,1000,600]);
    pax = polaraxes(fig);
    hold(pax, 'on');

    for f = 1:num_fields
        if any(abs(fields(f) - excluded_fields) <= eps)
            continue;
        end
        tbl = resistivity_deviation_percent_tables{f};

        if ~ismember(comp_name, tbl.Properties.VariableNames)
            continue;
        end

        theta = deg2rad(tbl.Angle);
        col   = tbl.(comp_name);

        if isvector(col)
            rho = abs(col(:));
        else
            if temp_index <= size(col,2)
                rho = abs(col(:, temp_index));
            else
                rho = abs(col(:, end));
            end
        end

        % UPDATED: Choose default color mode
        if useDefaultColors
            polarplot(pax, theta, rho, '-o', ...
                'DisplayName', sprintf('%.2f[T]', fields(f)), ...
                'LineWidth', linewidth);
        else
            polarplot(pax, theta, rho, '-o', ...
                'DisplayName', sprintf('%.2f[T]', fields(f)), ...
                'Color', colors(color_indices(f),:), ...
                'LineWidth', linewidth);
        end
    end

    hold(pax, 'off');

    pax.FontSize       = fontsize;
    pax.ThetaTick      = 0:45:315;
    pax.ThetaTickLabel = string(0:45:315);
    pax.RGrid          = 'on';

    title(pax, sprintf('%s %s \\Delta%s/<%s>[%%] at %.2f[K]', ...
        plan_measured, AMR_string, comp_str, devide_str, temp_val), ...
        'FontSize', fontsize);

    lg = legend(pax, 'show'); 
    lg.Location = 'eastoutside';
end
end
