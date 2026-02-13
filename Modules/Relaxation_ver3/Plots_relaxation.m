function [Time_table, Moment_table, T_all, F_all] = Plots_relaxation( ...
    Time_table, Moment_table, temps, fields_nominal, Field_table, ...
    color_scheme, normalizeByMass, sample_name, fontsize, Bohar_units, ...
    fileList, alignByDrop, Hthresh, debugMode, trimToFitWindow, ...
    compareMode, containsTRM_folder, containsIRM_folder, ...
    offsetDisplayMode, offsetValue)

%% Defaults (backward compatible)
if nargin < 20, offsetValue       = 0.2;   end
if nargin < 19, offsetDisplayMode = false; end
if nargin < 16, trimToFitWindow   = false; end   %#ok<NASGU>  % currently unused (fit controls trimming)
if nargin < 15, debugMode         = false; end   %#ok<NASGU>
if nargin < 14, Hthresh           = 20;    end
if nargin < 13, alignByDrop       = false; end

n = numel(Time_table);
if n == 0
    warning('No relaxation data found.');
    T_all = []; F_all = [];
    return;
end

%% -------------------------------------------------------
% Detect TRM / IRM
% -------------------------------------------------------
if containsTRM_folder && ~containsIRM_folder
    modeType = "TRM";  isComparison = false;
elseif containsIRM_folder && ~containsTRM_folder
    modeType = "IRM";  isComparison = false;
elseif containsTRM_folder && containsIRM_folder
    modeType = "TRM vs IRM";  isComparison = true;
else
    modeType = "relaxation";  isComparison = false;
end

%% -------------------------------------------------------
% Colors
% -------------------------------------------------------
if isComparison
    colors = lines(n);
else
    switch lower(color_scheme)
        case 'parula', colors = parula(n);
        case 'jet',    colors = jet(n);
        otherwise,     colors = lines(n);
    end
end
colors = flipud(colors);

%% -------------------------------------------------------
% Y-axis label
% -------------------------------------------------------
if Bohar_units
    unitStr = '[\mu_B/Co]';
elseif normalizeByMass
    unitStr = '[emu/g]';
else
    unitStr = '[emu]';
end

%% -------------------------------------------------------
% Extract temperatures
% -------------------------------------------------------
T_all = zeros(1,n);
for i = 1:n
    Tmatch = regexp(fileList{i}, '(\d+(\.\d+)?)K', 'tokens','once');
    if ~isempty(Tmatch)
        T_all(i) = str2double(Tmatch{1});
    else
        if iscell(temps)
            T_all(i) = mean(temps{i}, 'omitnan');
        else
            T_all(i) = temps(i);
        end
    end
end

%% -------------------------------------------------------
% Nominal field
% -------------------------------------------------------
if ~isempty(fields_nominal)
    H_nom_T = fields_nominal(1)/1e4;
else
    H_nom_T = NaN;
end

if isnan(H_nom_T)
    Hmatch = regexp(fileList{1}, '(\d+(\.\d+)?)T', 'tokens','once');
    if ~isempty(Hmatch)
        H_nom_T = str2double(Hmatch{1});
    else
        H_nom_T = 1;
    end
end

F_all = H_nom_T * ones(1,n);

%% -------------------------------------------------------
% Detect variation
% -------------------------------------------------------
uniqueT = unique(round(T_all,5));
uniqueH = unique(round(F_all,5));

tempVaries  = numel(uniqueT) > 1;
fieldVaries = numel(uniqueH) > 1;

%% -------------------------------------------------------
% Title
% -------------------------------------------------------
if isComparison
    baseTitle = sprintf('%s – TRM vs IRM relaxation', sample_name);
else
    baseTitle = sprintf('%s – Magnetic %s relaxation', sample_name, modeType);
end

suffix = "";
if ~tempVaries,  suffix = suffix + sprintf(' %g[K]', uniqueT); end
if ~fieldVaries, suffix = suffix + sprintf(' %g[T]', uniqueH); end
fullTitle = strtrim(baseTitle + " " + suffix);

figure('Name', fullTitle, 'Color','w'); hold on;
title(fullTitle,'FontSize',fontsize+2,'FontWeight','bold');

%% -------------------------------------------------------
% Optional alignment (drop point) — affects Time_table only
% -------------------------------------------------------
if alignByDrop
    for i = 1:n
        if isempty(Field_table{i}) || isempty(Time_table{i}), continue; end

        t  = Time_table{i};
        Hm = Field_table{i};

        m  = min(numel(t), numel(Hm));
        t  = t(1:m);
        Hm = Hm(1:m);

        absH    = abs(Hm);
        postMax = flipud(cummax(flipud(absH)));

        idx = find(postMax <= Hthresh, 1);
        if isempty(idx), idx = find(absH <= Hthresh,1); end
        if isempty(idx), [~,idx] = min(absH); end

        % Align so that field-drop point is t=0
        Time_table{i} = t - t(idx);
    end
end

%% -------------------------------------------------------
% Build legend labels
% -------------------------------------------------------
useLegend    = tempVaries || fieldVaries;
legendLabels = strings(1,n);

if isComparison
    for i = 1:n
        parts = {};
        if tempVaries,  parts{end+1} = sprintf('%g[K]', T_all(i)); end
        if fieldVaries, parts{end+1} = sprintf('%g[T]', F_all(i)); end

        if contains(lower(fileList{i}), "trm")
            prefix = "TRM";
        else
            prefix = "IRM";
        end

        if isempty(parts)
            legendLabels(i) = prefix;
        else
            legendLabels(i) = prefix + " – " + strjoin(parts,", ");
        end
    end
else
    for i = 1:n
        parts = {};
        if tempVaries,  parts{end+1} = sprintf('%g[K]', T_all(i)); end
        if fieldVaries, parts{end+1} = sprintf('%g[T]', F_all(i)); end
        if isempty(parts)
            legendLabels(i) = "";
        else
            legendLabels(i) = strjoin(parts,", ");
        end
    end
end

%% -------------------------------------------------------
% PLOT (with optional centering + offset, display-only masking)
% -------------------------------------------------------
for i = 1:n
    t = Time_table{i};
    M = Moment_table{i};
    if isempty(t), continue; end

    % --- Display only time >= 0 (after relaxation starts) ---
    mask_disp = t >= 0;
    if ~any(mask_disp)
        continue;   % no positive times, skip this curve
    end
    t_plot = t(mask_disp);

    % --- Build M_plot (offset is purely visual) ---
    if offsetDisplayMode
        M_ref       = M(end);                       % final-value centering
        M_plot_full = (M - M_ref) + (i-1)*offsetValue;
    else
        M_plot_full = M;                            % NO modification to data
    end

    M_plot = M_plot_full(mask_disp);

    plot(t_plot/60, M_plot, ...
        'Color',colors(i,:), 'LineWidth',2, ...
        'DisplayName',legendLabels(i));
end

xlabel('Time [minutes]', 'FontSize', fontsize);
ylabel(['M ' unitStr], 'FontSize', fontsize);

if useLegend
    legend(legendLabels(legendLabels~=""),'Location','eastoutside');
end

grid on; box on; set(gca,'FontSize',fontsize);

end
