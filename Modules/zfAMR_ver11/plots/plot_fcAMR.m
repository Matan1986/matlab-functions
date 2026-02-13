function plot_fcAMR( ...
    resistivity_deviation_percent_tables, angles, fields, ...
    temp_index, temp_val, Normalize_to, excluded_fields, ...
    plan_measured, fontsize, linewidth, plotChannels, zfc_fwAMR, ...
    channelKeys, channelLabels)

    % --- defaults / hygiene ---
    if nargin < 12
        error('plot_fcAMR:NotEnoughInputs','Missing required inputs.');
    end
    if nargin < 13 || isempty(channelKeys),   channelKeys   = {'ch1','ch2','ch3','ch4'}; end
    if nargin < 14,                            channelLabels = []; end

    if isempty(excluded_fields) || (isscalar(excluded_fields) && isnan(excluded_fields))
        excluded_fields = [];
    end
    AMR_string = ternary(zfc_fwAMR, 'zfcAMR', 'fcAMR');

    % --- enabled keys ---
    enabledKeys = {};
    for k = 1:numel(channelKeys)
        key = channelKeys{k};
        if isfield(plotChannels,key) && islogical(plotChannels.(key)) && plotChannels.(key)
            enabledKeys{end+1} = key;
        end
    end
    if isempty(enabledKeys)
        warning('plot_fcAMR:NoChannels','No channels enabled in plotChannels.');
        return;
    end

    % --- Normalize_to ---
    if isscalar(Normalize_to)
        Normalize_to = repmat(Normalize_to, 1, numel(enabledKeys));
    end
    if numel(Normalize_to) ~= numel(enabledKeys)
        warning('plot_fcAMR:NormalizeLen', ...
            'Normalize_to length (%d) != enabled channels (%d). Using self-normalization labels.', ...
            numel(Normalize_to), numel(enabledKeys));
        Normalize_to = 1:numel(enabledKeys);
    end
    normIdxEnabled = Normalize_to(:).';

    % --- schema ---
    tbl0 = firstNonEmptyTable(resistivity_deviation_percent_tables);
    if isempty(tbl0)
        warning('plot_fcAMR:EmptyTables','No tables to plot.');
        return;
    end
    existing   = tbl0.Properties.VariableNames;
    components = enabledKeys(ismember(enabledKeys, existing));
    if isempty(components)
        warning('plot_fcAMR:NoComponents', ...
            'Enabled channels not found among table vars: %s', strjoin(existing, ', '));
        return;
    end

    % --- labels ---
    comp_labels  = cell(1, numel(components));
    denom_labels = cell(1, numel(components));
    for i = 1:numel(components)
        key  = components{i};
        eIdx = find(strcmp(enabledKeys, key), 1, 'first');
        comp_labels{i} = resolveLabelForKey(key, channelLabels, plotChannels);
        if ~isempty(eIdx) && normIdxEnabled(eIdx) >= 1 && normIdxEnabled(eIdx) <= numel(enabledKeys)
            denomKey = enabledKeys{ normIdxEnabled(eIdx) };
            denom_labels{i} = resolveLabelForKey(denomKey, channelLabels, plotChannels);
        else
            denom_labels{i} = comp_labels{i};
        end
    end

    % =====================================================
    %     UPDATED SECTION — DEFAULT COLORS WHEN nF ≤ 3
    % =====================================================
    nF = numel(resistivity_deviation_percent_tables);

    % use MATLAB auto-colors for small #fields
    useDefaultColors = nF <= 3;

    if ~useDefaultColors
        if nF > 5
            cmap = parula(max(nF,64));
        else
            cmap = jet(max(nF,64));
        end
        cind = round(linspace(1, size(cmap,1), nF));
    end
    % =====================================================

    % --- plots ---
    for iComp = 1:numel(components)
        key        = components{iComp};
        numLabel   = comp_labels{iComp};
        denomLabel = denom_labels{iComp};

        figName = sprintf('%s %s %s at %.2f[K]', plan_measured, AMR_string, numLabel, temp_val);
        figure('Name', figName, 'Position', [100, 100, 1000, 600]); hold on;

        for f = 1:nF
    % ---- skip excluded fields ----
    if ~isempty(excluded_fields) && any(abs(fields(f) - excluded_fields) <= eps)
        continue;
    end

    tbl = resistivity_deviation_percent_tables{f};

    % ---- sanity checks ----
    if ~istable(tbl) || ~ismember('Angle', tbl.Properties.VariableNames)
        continue;
    end
    if ~ismember(key, tbl.Properties.VariableNames)
        continue;
    end

    angles_f = tbl.Angle;      % <-- CORRECT: angles per field/table
    Y = tbl.(key);

    % ---- bounds check ----
    if temp_index < 1 || temp_index > size(Y,2)
        continue;
    end

    % ---- plot ----
    if useDefaultColors
        plot(angles_f, Y(:,temp_index), '-o', ...
             'DisplayName', sprintf('%.2f[T]', fields(f)), ...
             'LineWidth', linewidth);
    else
        plot(angles_f, Y(:,temp_index), '-o', ...
             'DisplayName', sprintf('%.2f[T]', fields(f)), ...
             'Color', cmap(cind(f),:), ...
             'LineWidth', linewidth);
    end
end


        ax = gca; hold off; grid on;
        ax.FontSize = fontsize;
        ax.XTick = 0:45:360;
        ax.XTickLabel = string(0:45:360);
        ax.XLim = [0,360];

        title(sprintf('%s %s \\Delta%s/%s[%%] at %.2f[K]', ...
              plan_measured, AMR_string, numLabel, denomLabel, temp_val), ...
              'FontSize', fontsize);

        xlabel('Angle °', 'FontSize', fontsize);
        ylabel(sprintf('\\Delta%s/%s[%%]', numLabel, denomLabel), 'FontSize', fontsize);

        legend('show');
    end
end
