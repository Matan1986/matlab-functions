function plot_zfAMR( ...
    resistivity_deviation_percent_tables, angles, fields, ...
    temp_index, temp_val, Normalize_to, excluded_fields, ...
    plan_measured, fontsize, linewidth, plotChannels, zfc_fwAMR, ...
    channelKeys, channelLabels)

% plot_zfAMR  Plot AMR deviation (zero-field / field-warming alias) for selected channels.
%
% REQUIRED
%   resistivity_deviation_percent_tables : cell array of tables (one per field)
%   angles, fields, temp_index, temp_val
%   Normalize_to : scalar or vector (per-enabled-channel) of indices into enabled channels
%   excluded_fields : [] or list, NaN allowed (treated as none)
%   plan_measured, fontsize, linewidth, LegendVar, plotChannels, zfc_fwAMR
%
% OPTIONAL
%   channelKeys   : cellstr of table column keys to consider (default {'ch1','ch2','ch3','ch4'})
%   channelLabels : struct or containers.Map mapping key -> pretty label

if nargin < 14 || isempty(channelKeys),   channelKeys   = {'ch1','ch2','ch3','ch4'}; end
if nargin < 15,                            channelLabels = []; end

if isempty(excluded_fields) || (isscalar(excluded_fields) && isnan(excluded_fields))
    excluded_fields = [];
end

AMR_string = ternary(zfc_fwAMR, 'fwAMR', 'zfAMR');

% ----- Build enabled list in order -----
enabledKeys = {};
for k = 1:numel(channelKeys)
    key = channelKeys{k};
    if isfield(plotChannels,key) && islogical(plotChannels.(key)) && plotChannels.(key)
        enabledKeys{end+1} = key;
    end
end
if isempty(enabledKeys)
    warning('plot_zfAMR:NoChannels','No channels enabled in plotChannels.');
    return;
end

% ----- Normalize_to expansion -----
if isscalar(Normalize_to)
    Normalize_to = repmat(Normalize_to, 1, numel(enabledKeys));
end
if numel(Normalize_to) ~= numel(enabledKeys)
    warning('plot_zfAMR:NormalizeLen', ...
        'Normalize_to length (%d) != enabled channels (%d). Using self-normalization.', ...
        numel(Normalize_to), numel(enabledKeys));
    Normalize_to = 1:numel(enabledKeys);
end
normIdxEnabled = Normalize_to(:).';

% ----- Probe table schema -----
tbl0 = firstNonEmptyTable(resistivity_deviation_percent_tables);
if isempty(tbl0)
    warning('plot_zfAMR:EmptyTables','No tables to plot.');
    return;
end

existing = tbl0.Properties.VariableNames;
components = enabledKeys(ismember(enabledKeys, existing));
if isempty(components)
    warning('plot_zfAMR:NoComponents', ...
        'Enabled channels not found among table vars: %s', strjoin(existing, ', '));
    return;
end

% ----- Build labels -----
comp_labels  = cell(1, numel(components));
denom_labels = cell(1, numel(components));
for i = 1:numel(components)
    key    = components{i};
    eIdx   = find(strcmp(enabledKeys, key), 1, 'first');
    comp_labels{i} = resolveLabelForKey(key, channelLabels, plotChannels);

    if ~isempty(eIdx) && normIdxEnabled(eIdx) >= 1 && normIdxEnabled(eIdx) <= numel(enabledKeys)
        denomKey = enabledKeys{ normIdxEnabled(eIdx) };
        denom_labels{i} = resolveLabelForKey(denomKey, channelLabels, plotChannels);
    else
        denom_labels{i} = comp_labels{i};
    end
end

% =====================================================
%            UPDATED SECTION — DEFAULT COLOR LOGIC
% =====================================================
nF = numel(resistivity_deviation_percent_tables);

% use MATLAB default auto colors when nF <= 3
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


% ----- Plot per component -----
for iComp = 1:numel(components)
    key        = components{iComp};
    numLabel   = comp_labels{iComp};
    denomLabel = denom_labels{iComp};

    figName = sprintf('%s %s %s at %.2f[K]', ...
        plan_measured, AMR_string, numLabel, temp_val);

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

        angles_f = tbl.Angle;      % <-- use angles from THIS table
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


% ========= helpers =========
function tbl = firstNonEmptyTable(tblCell)
tbl = [];
if ~iscell(tblCell), return; end
for i = 1:numel(tblCell)
    ti = tblCell{i};
    if istable(ti) && ~isempty(ti)
        tbl = ti; return;
    end
end
end

function out = ternary(c,a,b)
if c, out = a; else, out = b; end
end
