function plot_compAMR( ...
    resistivity_warming_tables, resistivity_cooling_tables, ...
    fields, temp_index, temp_val, Normalize_to, excluded_fields, ...
    plan_measured, fontsize, linewidth, plotChannels, zfc_fwAMR, ...
    channelKeys, channelLabels)

% plot_compAMR
% ---------------------------------------------------------
% Subplot(1): ZF (red) + FC (blue) for all fields
% Subplot(2): Difference Δ(ZF − FC), colored by field
% ---------------------------------------------------------

%% defaults
if nargin < 13 || isempty(channelKeys)
    channelKeys = {'ch1','ch2','ch3','ch4'};
end
if nargin < 14
    channelLabels = [];
end
if isempty(excluded_fields) || (isscalar(excluded_fields) && isnan(excluded_fields))
    excluded_fields = [];
end

%% enabled channels
enabledKeys = {};
for k = 1:numel(channelKeys)
    key = channelKeys{k};
    if isfield(plotChannels,key) && plotChannels.(key)
        enabledKeys{end+1} = key; %#ok<AGROW>
    end
end
if isempty(enabledKeys)
    return;
end

nF = numel(fields);

%% ---- color families ----
% ZF = red shades, FC = blue shades
if nF == 1
    redColors  = [0.85 0.10 0.10];
    blueColors = [0.10 0.25 0.85];
else
    redColors  = [linspace(0.4,0.9,nF)', zeros(nF,1), zeros(nF,1)];
    blueColors = [zeros(nF,1), zeros(nF,1), linspace(0.4,0.9,nF)'];
end

% Difference colors (per field)
if nF <= 7
    diffColors = lines(nF);
else
    diffColors = parula(nF);
end

%% per channel
for iComp = 1:numel(enabledKeys)
    key = enabledKeys{iComp};
    compLabel = resolveLabelForKey(key, channelLabels, plotChannels);

    figure('Name', sprintf('%s compAMR %s at %.2f[K]', ...
        plan_measured, compLabel, temp_val), ...
        'Position', [100 100 1000 800]);

    %% ---- subplot 1: ZF + FC ----
    ax1 = subplot(2,1,1); hold(ax1,'on'); grid(ax1,'on');

    %% ---- subplot 2: difference ----
    ax2 = subplot(2,1,2); hold(ax2,'on'); grid(ax2,'on');

    for f = 1:nF
        % skip excluded fields
        if ~isempty(excluded_fields) && any(abs(fields(f)-excluded_fields)<=eps)
            continue;
        end

        tbl_zf = resistivity_warming_tables{f};
        tbl_fc = resistivity_cooling_tables{f};

        if ~istable(tbl_zf) || ~istable(tbl_fc)
            continue;
        end
        if ~ismember('Angle',tbl_zf.Properties.VariableNames) || ...
           ~ismember('Angle',tbl_fc.Properties.VariableNames)
            continue;
        end
        if ~ismember(key,tbl_zf.Properties.VariableNames) || ...
           ~ismember(key,tbl_fc.Properties.VariableNames)
            continue;
        end

        A_zf = tbl_zf.Angle(:);
        A_fc = tbl_fc.Angle(:);
        Yzf  = tbl_zf.(key);
        Yfc  = tbl_fc.(key);

        if temp_index > size(Yzf,2) || temp_index > size(Yfc,2)
            continue;
        end

        y_zf = Yzf(:,temp_index);
        y_fc = Yfc(:,temp_index);

        %% ---- subplot 1 ----
        plot(ax1, A_zf, y_zf, '-', ...
            'Color', redColors(f,:), ...
            'LineWidth', linewidth, ...
            'Marker','o', ...
            'DisplayName', sprintf('%.2fT ZF', fields(f)));

        plot(ax1, A_fc, y_fc, '-', ...
            'Color', blueColors(f,:), ...
            'LineWidth', linewidth, ...
            'Marker','s', ...
            'DisplayName', sprintf('%.2fT FC', fields(f)));

        %% ---- subplot 2: Δ(ZF − FC) ----
        A_common = unique([A_zf; A_fc]);
        y_zf_i = interp1(A_zf, y_zf, A_common, 'linear', NaN);
        y_fc_i = interp1(A_fc, y_fc, A_common, 'linear', NaN);

        dy = y_zf_i - y_fc_i;

        plot(ax2, A_common, dy, '-', ...
            'Color', diffColors(f,:), ...
            'LineWidth', linewidth, ...
            'DisplayName', sprintf('%.2fT (ZF−FC)', fields(f)));
    end

    %% ---- cosmetics ----
    ax1.FontSize = fontsize;
    ax1.XLim = [0 360];
    ax1.XTick = 0:45:360;
    ylabel(ax1, sprintf('\\Delta%s [%%]', compLabel));
    title(ax1, sprintf('%s compAMR %s at %.2f[K]', ...
        plan_measured, compLabel, temp_val));

    ax2.FontSize = fontsize;
    ax2.XLim = [0 360];
    ax2.XTick = 0:45:360;
    xlabel(ax2,'Angle °');
    ylabel(ax2,'ZF − FC [%]');

    yline(ax2,0,'k:');   % zero reference

    legend(ax1,'show','Location','eastoutside');
    legend(ax2,'show','Location','eastoutside');
end
end
