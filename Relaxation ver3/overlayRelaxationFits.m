function overlayRelaxationFits(allFits, Time_table, Moment_table, ...
    color_scheme, fileList, debugMode, trimToFitWindow, compareMode, ...
    sample_name, fields_nominal, containsTRM_folder, containsIRM_folder, ...
    offsetDisplayMode, offsetValue, plotLevel)

%% Handle plotLevel parameter (gating for plotting)
if nargin < 15 || isempty(plotLevel)
    plotLevel = 'summary';
end
if strcmpi(plotLevel, 'none')
    return;
end

%% Defaults
if nargin < 14, offsetValue       = 0.2;   end
if nargin < 13, offsetDisplayMode = false; end
if nargin < 12, containsIRM_folder = false; end
if nargin < 11, containsTRM_folder = false; end
if nargin < 10, sample_name        = "";    end
if nargin < 9,  compareMode        = false; end
if nargin < 7,  trimToFitWindow    = false; end
if nargin < 6,  debugMode          = false; end %#ok<NASGU>

n = numel(Time_table);

%% -------------------------------------------------------
% Detect TRM/IRM
% -------------------------------------------------------
if containsTRM_folder && ~containsIRM_folder
    modeType = "TRM";  isComparison = false;
elseif containsIRM_folder && ~containsTRM_folder
    modeType = "IRM";  isComparison = false;
elseif containsTRM_folder && containsIRM_folder
    modeType = "TRM vs IRM"; isComparison = true;
else
    modeType = "relaxation"; isComparison = false;
end

%% -------------------------------------------------------
% Extract T values
% -------------------------------------------------------
T_all = NaN(1,n);
for j = 1:height(allFits)
    idx = allFits.data_idx(j);
    if idx>=1 && idx<=n
        T_all(idx) = allFits.Temp_K(j);
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
    Hmatch = regexp(fileList{1}, '(\d+(\.\d+)?)T','tokens','once');
    if ~isempty(Hmatch)
        H_nom_T = str2double(Hmatch{1});
    else
        H_nom_T = 1;
    end
end

F_all = H_nom_T * ones(1,n);

%% -------------------------------------------------------
% Variation flags
% -------------------------------------------------------
uniqueT = unique(round(T_all,5));
uniqueH = unique(round(F_all,5));

tempVaries  = numel(uniqueT) > 1;
fieldVaries = numel(uniqueH) > 1;

%% -------------------------------------------------------
% Title
% -------------------------------------------------------
if isComparison
    baseTitle = sprintf('%s – TRM vs IRM relaxation fitted overlay', sample_name);
else
    baseTitle = sprintf('%s – Magnetic %s relaxation fitted overlay', ...
        sample_name, modeType);
end

suffix = "";
if ~tempVaries,  suffix = suffix + sprintf(' %g[K]', uniqueT); end
if ~fieldVaries, suffix = suffix + sprintf(' %g[T]', uniqueH); end
fullTitle = strtrim(baseTitle + " " + suffix);

figure('Name',fullTitle,'Color','w'); hold on;
title(fullTitle,'FontSize',16,'FontWeight','bold');

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
% Legend labels
% -------------------------------------------------------
legendLabels = strings(1,n);
useLegend = isComparison || tempVaries || fieldVaries;

for i = 1:n
    parts = {};
    if tempVaries,  parts{end+1} = sprintf('%g[K]',T_all(i)); end
    if fieldVaries, parts{end+1} = sprintf('%g[T]',F_all(i)); end

    if isComparison
        if contains(lower(fileList{i}),"trm"), prefix = "TRM";
        elseif contains(lower(fileList{i}),"irm"), prefix = "IRM";
        else, prefix = "";
        end

        if prefix ~= ""
            if isempty(parts)
                legendLabels(i) = prefix;
            else
                legendLabels(i) = prefix + " – " + strjoin(parts,", ");
            end
        else
            legendLabels(i) = strjoin(parts,", ");
        end
    else
        if isempty(parts)
            legendLabels(i) = "";
        else
            legendLabels(i) = strjoin(parts,", ");
        end
    end
end

%% -------------------------------------------------------
% Plot raw curves
% -------------------------------------------------------
for i = 1:n
    t = Time_table{i};
    M = Moment_table{i};
    if isempty(t), continue; end

    % Display mask: keep plotted time range consistent with Plots_relaxation
    mask_disp = t >= 0;

    % Optional fit-window display trimming (kept for backward compatibility)
    if trimToFitWindow
        idxFit = find(allFits.data_idx == i, 1, 'first');
        if ~isempty(idxFit)
            t0_disp = allFits.t_start(idxFit);
            t1_disp = allFits.t_end(idxFit);
            mask_disp = mask_disp & (t >= t0_disp) & (t <= t1_disp);
        end
    end

    if ~any(mask_disp), continue; end
    t = t(mask_disp);
    M = M(mask_disp);

    % Determine what to plot
    if offsetDisplayMode
        M_ref = M(end);
        M_plot = (M - M_ref) + (i-1)*offsetValue;
    else
        M_plot = M;    % absolutely no modification
    end

    plot(t/60, M_plot, ...
        'Color',colors(i,:), 'LineWidth',2, ...
        'DisplayName', legendLabels(i));
end

%% -------------------------------------------------------
% Fit legend
% -------------------------------------------------------
if useLegend
    plot(NaN,NaN,'--','Color',[0.7 0 0],'LineWidth',2,'DisplayName','Fit');
end

%% -------------------------------------------------------
% Plot fitted curves
% -------------------------------------------------------
for j = 1:height(allFits)

    idx = allFits.data_idx(j);
    if idx<1 || idx>n, continue; end

    tData = Time_table{idx};
    MData = Moment_table{idx};
    if isempty(tData), continue; end

    % Raw data reference for centering
    if offsetDisplayMode
        M_ref = MData(end);
    end

    % Fit parameters
    Minf = allFits.Minf(j);
    dM   = allFits.dM(j);
    tau  = allFits.tau(j);
    beta = allFits.n(j);
    t0   = allFits.t_start(j);
    t1   = allFits.t_end(j);
    if ismember('M0', allFits.Properties.VariableNames)
        M0 = allFits.M0(j);
    else
        M0 = NaN;
    end
    if ismember('S', allFits.Properties.VariableNames)
        S = allFits.S(j);
    else
        S = NaN;
    end
    if ismember('model_type', allFits.Properties.VariableNames)
        modelType = lower(string(allFits.model_type(j)));
    else
        modelType = "kww";
    end

    tfit = linspace(max(0,t0), t1, 400);
    switch modelType
        case "log"
            tLog = max(tfit, 1e-6);
            Mfit = M0 - S .* log(tLog);
        case "fallback"
            Mfit = mean(MData, 'omitnan') .* ones(size(tfit));
        otherwise
            z = max(0,(tfit - t0) / max(tau,1e-6));
            Mfit = Minf + dM .* exp(-(z.^beta));
    end

    % Offset & centering logic
    if offsetDisplayMode
        y_off = (idx-1) * offsetValue;
        Mfit_plot = (Mfit - M_ref) + y_off;
    else
        Mfit_plot = Mfit;     % unmodified
    end

    plot(tfit/60, Mfit_plot, ...
        '--','Color',[0.7 0 0],'LineWidth',2, ...
        'HandleVisibility','off');
end

xlabel('Time [minutes]');
ylabel('M [\mu_B/Co]');

if useLegend
    legend(gca,'Location','eastoutside');
end

grid on; box on; set(gca,'FontSize',13);

end
